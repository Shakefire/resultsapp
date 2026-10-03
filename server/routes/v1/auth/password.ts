import type { VercelRequest, VercelResponse } from '@vercel/node';
import { authenticateRequest, supabaseClients } from '../../../lib/auth.js';
import { sendError, setCorsHeaders } from '../../../lib/http.js';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!setCorsHeaders(req, res)) return sendError(res, 403, 'FORBIDDEN', 'This origin is not allowed.');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'PATCH') {
    res.setHeader('Allow', 'PATCH, OPTIONS');
    return sendError(res, 405, 'METHOD_NOT_ALLOWED', 'Use PATCH for this endpoint.');
  }

  const principal = await authenticateRequest(req, res);
  if (!principal) return;
  const body = req.body as { newPassword?: unknown; currentPassword?: unknown } | undefined;
  const newPassword = body?.newPassword;
  const currentPassword = body?.currentPassword;
  if (typeof newPassword !== 'string' || newPassword.length < 8 || newPassword.length > 256) {
    return sendError(res, 400, 'VALIDATION_ERROR', 'Password must be at least 8 characters.');
  }
  if (typeof currentPassword !== 'string' || currentPassword.length < 1 || currentPassword.length > 256) {
    return sendError(res, 400, 'VALIDATION_ERROR', 'Enter the temporary password issued by your administrator.');
  }

  const { adminClient, authClient } = supabaseClients();
  const internalEmail = `${principal.profile.user_id.toLowerCase()}@accounts.smart-electoral-results.invalid`;
  const { data: verified, error: verifyError } = await authClient.auth.signInWithPassword({ email: internalEmail, password: currentPassword });
  if (verifyError || verified.user?.id !== principal.authUser.id) return sendError(res, 401, 'UNAUTHORIZED', 'The temporary password is incorrect. Sign in again and retry.');
  await authClient.auth.signOut({ scope: 'local' });
  const { error: passwordError } = await adminClient.auth.admin.updateUserById(
    principal.authUser.id,
    { password: newPassword },
  );
  if (passwordError) {
    console.error('Password update failed', passwordError.code);
    return sendError(res, 400, 'VALIDATION_ERROR', 'The password could not be updated.');
  }

  const { error: profileError } = await adminClient
    .from('user_profiles')
    .update({ must_change_password: false, updated_at: new Date().toISOString() })
    .eq('auth_user_id', principal.authUser.id);
  if (profileError) {
    console.error('Password policy state update failed', profileError.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Password changed, but account setup could not be completed.');
  }

  await adminClient.from('audit_events').insert({
    actor_id: principal.authUser.id,
    event_type: 'account.password_changed',
    entity_type: 'user_profile',
    entity_id: principal.authUser.id,
    details: {},
  });
  res.status(200).json({ data: { changed: true } });
}
