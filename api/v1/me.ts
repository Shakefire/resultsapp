import type { VercelRequest, VercelResponse } from '@vercel/node';
import { authenticateRequest } from '../_lib/auth.js';
import { sendError, setCorsHeaders } from '../_lib/http.js';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!setCorsHeaders(req, res)) {
    sendError(res, 403, 'FORBIDDEN', 'This origin is not allowed.');
    return;
  }
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET, OPTIONS');
    sendError(res, 405, 'METHOD_NOT_ALLOWED', 'Use GET for this endpoint.');
    return;
  }

  const principal = await authenticateRequest(req, res);
  if (!principal) return;

  res.status(200).json({
    data: {
      userId: principal.profile.user_id,
      fullName: principal.profile.full_name,
      role: principal.profile.role,
      scope: {
        stateCode: principal.profile.state_code,
        lgaCode: principal.profile.lga_code,
        wardCode: principal.profile.ward_code,
        pollingUnitCode: principal.profile.polling_unit_code,
      },
      mustChangePassword: principal.profile.must_change_password,
    },
  });
}
