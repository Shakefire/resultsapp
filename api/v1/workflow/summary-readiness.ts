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
  if (principal.profile.must_change_password || !['lga_admin', 'state_admin'].includes(principal.profile.role)) {
    return sendError(res, 403, 'FORBIDDEN', 'An initialized LGA or State Admin account is required.');
  }

  const { adminClient } = supabaseClients();
  const { data, error } = await adminClient.rpc('get_admin_summary_readiness', {
    p_actor: principal.authUser.id,
  });
  if (error) {
    console.error('Summary readiness RPC failed', error.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to load approval completeness.');
  }
  return res.status(200).json({ data });
}
