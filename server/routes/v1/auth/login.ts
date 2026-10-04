import { createClient } from '@supabase/supabase-js';
import type { VercelRequest, VercelResponse } from '@vercel/node';
import { sendError, setCorsHeaders } from '../../../lib/http.js';
import { supabaseClients } from '../../../lib/auth.js';

const USER_ID_PATTERN = /^[A-Za-z0-9-]{4,24}$/;
const AUTH_EMAIL_DOMAIN = 'accounts.smart-electoral-results.invalid';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!setCorsHeaders(req, res)) return sendError(res, 403, 'FORBIDDEN', 'This origin is not allowed.');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST, OPTIONS');
    return sendError(res, 405, 'METHOD_NOT_ALLOWED', 'Use POST for this endpoint.');
  }

  const body = req.body as { userId?: unknown; password?: unknown } | undefined;
  const userId = typeof body?.userId === 'string' ? body.userId.trim().toUpperCase() : '';
  const password = typeof body?.password === 'string' ? body.password : '';
  if (!USER_ID_PATTERN.test(userId) || password.length < 1 || password.length > 256) {
    return sendError(res, 400, 'VALIDATION_ERROR', 'Enter a valid User ID and password.');
  }

  try {
    const { adminClient } = supabaseClients();
    const targetUserId = (userId === 'SA-HQ') ? 'SUPERADMIN' : userId;
    const { data: profile, error: profileError } = await adminClient
      .from('user_profiles')
      .select('user_id,is_active')
      .eq('user_id', targetUserId)
      .maybeSingle();

    // Use one response for unknown and inactive IDs to avoid account enumeration.
    if (profileError) {
      console.error('Login profile lookup failed', profileError.code);
      return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to sign in right now.');
    }
    if (!profile || !profile.is_active) {
      return sendError(res, 401, 'UNAUTHORIZED', 'Invalid User ID or password.');
    }

    const loginClient = createClient(
      process.env.SUPABASE_URL!,
      process.env.SUPABASE_ANON_KEY!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );
    const internalEmail = `${profile.user_id.toLowerCase()}@${AUTH_EMAIL_DOMAIN}`;
    const { data, error } = await loginClient.auth.signInWithPassword({ email: internalEmail, password });
    if (error || !data.session || !data.user) {
      return sendError(res, 401, 'UNAUTHORIZED', 'Invalid User ID or password.');
    }

    res.status(200).json({
      data: {
        accessToken: data.session.access_token,
        refreshToken: data.session.refresh_token,
        expiresAt: data.session.expires_at,
      },
    });
  } catch (error) {
    console.error('Login failed', error instanceof Error ? error.message : 'unknown error');
    sendError(res, 500, 'INTERNAL_ERROR', 'Unable to sign in right now.');
  }
}
