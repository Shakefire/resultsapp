import type { VercelRequest, VercelResponse } from '@vercel/node';
import { authenticateRequest, supabaseClients } from '../../_lib/auth.js';
import { sendError, setCorsHeaders } from '../../_lib/http.js';

type DecisionAction = 'ward_verified' | 'returned' | 'lga_approved' | 'state_approved';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!setCorsHeaders(req, res)) return sendError(res, 403, 'FORBIDDEN', 'This origin is not allowed.');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST, OPTIONS');
    return sendError(res, 405, 'METHOD_NOT_ALLOWED', 'Use POST for this endpoint.');
  }
  const principal = await authenticateRequest(req, res);
  if (!principal) return;
  const { profile, authUser } = principal;
  if (profile.must_change_password) return sendError(res, 403, 'FORBIDDEN', 'Change the temporary password before reviewing results.');

  const body = req.body as { submissionId?: unknown; action?: unknown; reason?: unknown } | undefined;
  const submissionId = typeof body?.submissionId === 'string' ? body.submissionId.trim() : '';
  const action = body?.action;
  const reason = typeof body?.reason === 'string' ? body.reason.trim() : '';
  const allowed: Record<string, DecisionAction[]> = { ward_admin: ['ward_verified', 'returned'] };
  if (!submissionId || typeof action !== 'string' || !allowed[profile.role]?.includes(action as DecisionAction)) {
    return sendError(res, 400, 'VALIDATION_ERROR', 'The requested review action is invalid for this account.');
  }
  if (action === 'returned' && reason.length < 3) {
    return sendError(res, 400, 'VALIDATION_ERROR', 'Enter a return reason of at least three characters.');
  }

  const expectedStatus = action === 'ward_verified' || action === 'returned'
    ? 'submitted'
    : action === 'lga_approved' ? 'ward_verified' : 'lga_approved';
  const { adminClient } = supabaseClients();
  const { data: submission, error: lookupError } = await adminClient.from('result_submissions')
    .select('id,election_id,state_code,lga_code,ward_code,polling_unit_code,status,revision')
    .eq('id', submissionId).maybeSingle();
  if (lookupError) {
    console.error('Review submission lookup failed', lookupError.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to load the result submission.');
  }
  if (!submission) return sendError(res, 404, 'NOT_FOUND', 'The result submission was not found.');

  const inScope = profile.role === 'ward_admin'
    ? submission.state_code === profile.state_code && submission.lga_code === profile.lga_code && submission.ward_code === profile.ward_code
    : profile.role === 'lga_admin'
      ? submission.state_code === profile.state_code && submission.lga_code === profile.lga_code
      : profile.role === 'state_admin' && submission.state_code === profile.state_code;
  if (!inScope) return sendError(res, 403, 'FORBIDDEN', 'This result is outside your assigned geography.');
  if (submission.status !== expectedStatus) {
    return sendError(res, 409, 'CONFLICT', `This result is now ${submission.status} and cannot take that action.`);
  }

  const newStatus = action as DecisionAction;
  const { data: updated, error: updateError } = await adminClient.from('result_submissions')
    .update({ status: newStatus, updated_at: new Date().toISOString() })
    .eq('id', submissionId).eq('status', expectedStatus)
    .select('id,status,updated_at').maybeSingle();
  if (updateError || !updated) {
    if (updateError) console.error('Review state transition failed', updateError.code);
    return sendError(res, updateError ? 500 : 409, updateError ? 'INTERNAL_ERROR' : 'CONFLICT', updateError ? 'Unable to save the review decision.' : 'Another reviewer changed this result. Refresh the queue.');
  }

  const { data: decision, error: decisionError } = await adminClient.from('review_decisions').insert({
    submission_id: submissionId,
    actor_id: authUser.id,
    action,
    reason: reason || null,
    prior_status: expectedStatus,
    new_status: newStatus,
  }).select('id').maybeSingle();
  const { error: auditError } = decisionError ? { error: decisionError } : await adminClient.from('audit_events').insert({
    actor_id: authUser.id,
    event_type: `result.${action}`,
    entity_type: 'result_submission',
    entity_id: submissionId,
    details: { priorStatus: expectedStatus, newStatus, reason: reason || null, revision: submission.revision },
  });
  if (decisionError || auditError) {
    if (decision?.id) await adminClient.from('review_decisions').delete().eq('id', decision.id);
    await adminClient.from('result_submissions').update({ status: expectedStatus, updated_at: new Date().toISOString() })
      .eq('id', submissionId).eq('status', newStatus);
    if (decisionError) console.error('Review history write failed', decisionError.code);
    if (auditError) console.error('Review audit write failed', auditError.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'The decision could not be fully recorded. Refresh and try again.');
  }
  res.status(200).json({ data: { submissionId, status: newStatus, updatedAt: updated.updated_at } });
}
