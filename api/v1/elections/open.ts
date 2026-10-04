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
  if (principal.profile.role !== 'polling_unit_staff' || principal.profile.must_change_password) return sendError(res, 403, 'FORBIDDEN', 'An initialized Polling Unit Staff account is required.');
  const { adminClient } = supabaseClients();
  const { data, error } = await adminClient.from('elections').select('id,election_code,name,opens_at,closes_at')
    .eq('status', 'open').limit(10);
  if (error) {
    console.error('Open election lookup failed', error.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to load active elections.');
  }
  const now = Date.now();
  const active = (data ?? []).filter((election) => (!election.opens_at || Date.parse(election.opens_at) <= now) && (!election.closes_at || Date.parse(election.closes_at) >= now));
  if (active.length > 1) return sendError(res, 409, 'CONFLICT', 'More than one election is open. Contact the Super Admin.');
  return res.status(200).json({ data: { election: active[0] ?? null } });
}
