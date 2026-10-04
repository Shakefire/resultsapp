import { createClient } from '@supabase/supabase-js';
import type { VercelRequest, VercelResponse } from '@vercel/node';
import { sendError, setCorsHeaders } from '../../_lib/http.js';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!setCorsHeaders(req, res)) return sendError(res, 403, 'FORBIDDEN', 'This origin is not allowed.');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST, OPTIONS');
    return sendError(res, 405, 'METHOD_NOT_ALLOWED', 'Use POST for this endpoint.');
  }

  const refreshToken = (req.body as { refreshToken?: unknown } | undefined)?.refreshToken;
  if (typeof refreshToken !== 'string' || refreshToken.length < 1 || refreshToken.length > 4096) {
    return sendError(res, 400, 'VALIDATION_ERROR', 'A valid refresh token is required.');
  }

  const url = process.env.SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY;
  if (!url || !anonKey) return sendError(res, 500, 'CONFIGURATION_ERROR', 'The API is not configured.');

  const client = createClient(url, anonKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const { data, error } = await client.auth.refreshSession({ refresh_token: refreshToken });
  if (error || !data.session) return sendError(res, 401, 'UNAUTHORIZED', 'Your session expired. Sign in again.');

  res.status(200).json({ data: {
    accessToken: data.session.access_token,
    refreshToken: data.session.refresh_token,
    expiresAt: data.session.expires_at,
  } });
}
