import type { VercelRequest, VercelResponse } from '@vercel/node';
import { authenticateRequest, supabaseClients } from '../../../lib/auth.js';
import { sendError, setCorsHeaders } from '../../../lib/http.js';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!setCorsHeaders(req, res)) return sendError(res, 403, 'FORBIDDEN', 'This origin is not allowed.');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST, OPTIONS');
    return sendError(res, 405, 'METHOD_NOT_ALLOWED', 'Use POST for this endpoint.');
  }
  const principal = await authenticateRequest(req, res);
  if (!principal) return;
  const { profile } = principal;
  if (profile.must_change_password || !['lga_admin', 'state_admin'].includes(profile.role)) return sendError(res, 403, 'FORBIDDEN', 'An initialized LGA or State Admin account is required.');
  const electionId = (req.body as { electionId?: unknown } | undefined)?.electionId;
  if (typeof electionId !== 'string' || !/^[0-9a-f-]{36}$/i.test(electionId)) return sendError(res, 400, 'VALIDATION_ERROR', 'A valid election is required.');
  const { adminClient } = supabaseClients();
  const functionName = profile.role === 'lga_admin' ? 'approve_lga_summary' : 'approve_state_summary';
  const { data, error } = await adminClient.rpc(functionName, { p_actor: principal.authUser.id, p_election: electionId });
  if (error) {
    console.error('Summary approval RPC failed', error.code, error.message);
    return sendError(res, 400, 'WORKFLOW_ERROR', error.message.includes('Only an initialized') ? error.message : 'Unable to approve this summary.');
  }
  if (!data?.ready) return sendError(res, 409, 'INCOMPLETE_SUMMARY', data?.reason ?? 'The summary is incomplete.');
  return res.status(200).json({ data });
}
