import type { VercelRequest, VercelResponse } from '@vercel/node';
import { authenticateRequest, supabaseClients } from '../../_lib/auth.js';
import { sendError, setCorsHeaders } from '../../_lib/http.js';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!setCorsHeaders(req, res)) return sendError(res, 403, 'FORBIDDEN', 'This origin is not allowed.');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET, OPTIONS');
    return sendError(res, 405, 'METHOD_NOT_ALLOWED', 'Use GET for this endpoint.');
  }

  const principal = await authenticateRequest(req, res);
  if (!principal) return;
  const { profile } = principal;
  if (profile.must_change_password) return sendError(res, 403, 'FORBIDDEN', 'Change the temporary password before reviewing results.');
  const { adminClient } = supabaseClients();

  let query = adminClient.from('result_submissions')
    .select('id,election_id,state_code,lga_code,ward_code,polling_unit_code,status,revision,figures,submitted_at,updated_at');

  if (profile.role === 'ward_admin') {
    query = query.eq('state_code', profile.state_code!).eq('lga_code', profile.lga_code!)
      .eq('ward_code', profile.ward_code!).eq('status', 'submitted');
  } else if (profile.role === 'lga_admin') {
    query = query.eq('state_code', profile.state_code!).eq('lga_code', profile.lga_code!)
      .eq('status', 'ward_verified');
  } else if (profile.role === 'state_admin') {
    query = query.eq('state_code', profile.state_code!).eq('status', 'lga_approved');
  } else {
    return sendError(res, 403, 'FORBIDDEN', 'Only Ward, LGA, or State Admins can access the review queue.');
  }

  const { data, error } = await query.order('submitted_at', { ascending: true }).limit(500);
  if (error) {
    console.error('Review queue lookup failed', error.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to load the review queue.');
  }

  const submissionIds = (data ?? []).map((row) => row.id);
  const decisionMap = new Map<string, unknown[]>();
  const evidenceMap = new Map<string, unknown[]>();
  if (submissionIds.length > 0) {
    const [decisionResult, evidenceResult] = await Promise.all([
      adminClient.from('review_decisions').select('submission_id,action,reason,created_at')
        .in('submission_id', submissionIds).order('created_at', { ascending: true }),
      adminClient.from('evidence_files').select('id,submission_id,evidence_type,object_key,mime_type,file_size_bytes')
        .in('submission_id', submissionIds),
    ]);
    if (decisionResult.error || evidenceResult.error) {
      console.error('Review history/evidence lookup failed', decisionResult.error?.code ?? evidenceResult.error?.code);
      return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to load review history and evidence.');
    }
    for (const decision of decisionResult.data ?? []) {
      decisionMap.set(decision.submission_id, [...(decisionMap.get(decision.submission_id) ?? []), decision]);
    }
    for (const evidence of evidenceResult.data ?? []) {
      if (evidence.submission_id) evidenceMap.set(evidence.submission_id, [...(evidenceMap.get(evidence.submission_id) ?? []), evidence]);
    }
  }
  res.status(200).json({ data: (data ?? []).map((row) => ({ ...row, decisions: decisionMap.get(row.id) ?? [], evidence: evidenceMap.get(row.id) ?? [] })) });
}
