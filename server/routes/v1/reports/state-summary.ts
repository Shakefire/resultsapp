import { createHash } from 'node:crypto';
import type { VercelRequest, VercelResponse } from '@vercel/node';
import { authenticateRequest, supabaseClients } from '../../../lib/auth.js';
import { sendError, setCorsHeaders } from '../../../lib/http.js';

function csvCell(value: unknown): string {
  const text = typeof value === 'string' ? value : JSON.stringify(value ?? '') ?? '';
  return `"${text.replaceAll('"', '""')}"`;
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!setCorsHeaders(req, res)) return sendError(res, 403, 'FORBIDDEN', 'This origin is not allowed.');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET, OPTIONS');
    return sendError(res, 405, 'METHOD_NOT_ALLOWED', 'Use GET for this endpoint.');
  }
  const principal = await authenticateRequest(req, res);
  if (!principal) return;
  if (principal.profile.role !== 'state_admin' || principal.profile.must_change_password) {
    return sendError(res, 403, 'FORBIDDEN', 'Only an initialized State Admin can export state reports.');
  }
  const electionId = typeof req.query.electionId === 'string' ? req.query.electionId.trim() : '';
  const { adminClient } = supabaseClients();
  if (!electionId) {
    const { data: approved, error: approvedError } = await adminClient.from('result_summaries')
      .select('election_id').eq('state_code', principal.profile.state_code!).eq('level', 'state').eq('status', 'approved');
    if (approvedError) {
      console.error('Report election lookup failed', approvedError.code);
      return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to load reportable elections.');
    }
    const ids = [...new Set((approved ?? []).map((row) => row.election_id))];
    if (!ids.length) return res.status(200).json({ data: { elections: [] } });
    const { data: elections, error: electionsError } = await adminClient.from('elections')
      .select('id,election_code,name').in('id', ids).order('name');
    if (electionsError) {
      console.error('Report election lookup failed', electionsError.code);
      return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to load reportable elections.');
    }
    return res.status(200).json({ data: { elections: elections ?? [] } });
  }
  const { data: summary, error: summaryError } = await adminClient.from('result_summaries')
    .select('id,election_id,state_code,figures,source_submission_ids,source_summary_ids,approved_by,approved_at')
    .eq('level', 'state').eq('status', 'approved').eq('state_code', principal.profile.state_code!).eq('election_id', electionId).maybeSingle();
  if (summaryError) {
    console.error('State summary lookup failed', summaryError.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to load the approved state summary.');
  }
  if (!summary) return sendError(res, 404, 'NOT_FOUND', 'There is no State-approved summary for this election.');
  const { data: rows, error } = await adminClient.from('result_submissions')
    .select('id,election_id,state_code,lga_code,ward_code,polling_unit_code,revision,figures,submitted_at')
    .eq('state_code', principal.profile.state_code!).in('id', summary.source_submission_ids)
    .eq('status', 'state_approved').order('lga_code').order('ward_code').order('polling_unit_code');
  if (error) {
    console.error('State report lookup failed', error.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to generate the state report.');
  }
  if (!rows?.length) return sendError(res, 409, 'CONFLICT', 'The approved summary has no available source rows.');

  const { data: approver, error: approverError } = await adminClient.from('user_profiles').select('user_id').eq('auth_user_id', summary.approved_by).single();
  if (approverError) {
    console.error('Report approver lookup failed', approverError.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to identify the summary approver.');
  }

  const columns = ['record_type', 'summary_id', 'submission_id', 'election_id', 'state_code', 'lga_code', 'ward_code', 'polling_unit_code', 'revision', 'figures', 'approved_at', 'approved_by_user_id', 'report_generated_at', 'generated_by_user_id'];
  const generatedAt = new Date().toISOString();
  const summaryRow = ['state_summary', summary.id, '', summary.election_id, summary.state_code, '', '', '', '', summary.figures, summary.approved_at, approver.user_id, generatedAt, principal.profile.user_id];
  const csv = [columns.join(','), summaryRow.map(csvCell).join(','), ...rows.map((row) => [
    'polling_unit_result', summary.id, row.id, row.election_id, row.state_code, row.lga_code, row.ward_code, row.polling_unit_code,
    row.revision, row.figures, summary.approved_at, approver.user_id, generatedAt, principal.profile.user_id,
  ].map(csvCell).join(','))].join('\r\n');
  const sourceIdsHash = createHash('sha256').update([...summary.source_submission_ids].sort().join('\n')).digest('hex');
  const { error: auditError } = await adminClient.from('audit_events').insert({
    actor_id: principal.authUser.id,
    event_type: 'report.state_exported',
    entity_type: 'result_summary',
    entity_id: summary.id,
    details: { electionId, stateCode: principal.profile.state_code, rowCount: rows.length, generatedAt, format: 'csv', sourceIdsHash },
  });
  if (auditError) {
    console.error('State report audit write failed', auditError.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'The report could not be audited and was not exported.');
  }
  res.status(200).json({ data: { filename: `state-results-${principal.profile.state_code}-${electionId}.csv`, generatedAt, rowCount: rows.length, summaryId: summary.id, sourceIdsHash, csv } });
}
