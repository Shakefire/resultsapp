import { randomBytes } from 'node:crypto';
import type { VercelRequest, VercelResponse } from '@vercel/node';
import { authenticateRequest, type AppRole, supabaseClients } from '../../_lib/auth.js';
import { sendError, setCorsHeaders } from '../../_lib/http.js';

const subordinateRoles = new Set<AppRole>(['state_admin', 'lga_admin', 'ward_admin', 'polling_unit_staff']);
const AUTH_EMAIL_DOMAIN = 'accounts.smart-electoral-results.invalid';
type Scope = { role?: unknown; stateCode?: unknown; lgaCode?: unknown; wardCode?: unknown; pollingUnitCode?: unknown };
const isText = (value: unknown): value is string => typeof value === 'string' && value.trim().length > 0;

function scopeValues(scope: Scope) {
  return {
    role: scope.role as AppRole,
    state_code: isText(scope.stateCode) ? scope.stateCode.trim().toUpperCase() : null,
    lga_code: isText(scope.lgaCode) ? scope.lgaCode.trim().toUpperCase() : null,
    ward_code: isText(scope.wardCode) ? scope.wardCode.trim().toUpperCase() : null,
    polling_unit_code: isText(scope.pollingUnitCode) ? scope.pollingUnitCode.trim().toUpperCase() : null,
  };
}

function validScope(scope: Scope): boolean {
  if (!isText(scope.role) || !subordinateRoles.has(scope.role as AppRole) || !isText(scope.stateCode)) return false;
  switch (scope.role) {
    case 'state_admin': return scope.lgaCode == null && scope.wardCode == null && scope.pollingUnitCode == null;
    case 'lga_admin': return isText(scope.lgaCode) && scope.wardCode == null && scope.pollingUnitCode == null;
    case 'ward_admin': return isText(scope.lgaCode) && isText(scope.wardCode) && scope.pollingUnitCode == null;
    case 'polling_unit_staff': return isText(scope.lgaCode) && isText(scope.wardCode) && isText(scope.pollingUnitCode);
    default: return false;
  }
}

async function scopeExists(admin: ReturnType<typeof supabaseClients>['adminClient'], scope: ReturnType<typeof scopeValues>) {
  if (scope.role === 'state_admin') return (await admin.from('states').select('code').eq('code', scope.state_code!).eq('is_active', true).maybeSingle()).data != null;
  if (scope.role === 'lga_admin') return (await admin.from('lgas').select('code').eq('state_code', scope.state_code!).eq('code', scope.lga_code!).eq('is_active', true).maybeSingle()).data != null;
  if (scope.role === 'ward_admin') return (await admin.from('wards').select('code').eq('state_code', scope.state_code!).eq('lga_code', scope.lga_code!).eq('code', scope.ward_code!).eq('is_active', true).maybeSingle()).data != null;
  return (await admin.from('polling_units').select('code').eq('state_code', scope.state_code!).eq('lga_code', scope.lga_code!).eq('ward_code', scope.ward_code!).eq('code', scope.polling_unit_code!).eq('is_active', true).maybeSingle()).data != null;
}

function temporaryPassword() { return `E!${randomBytes(18).toString('base64url')}9a`; }
function assignedUserId(scope: ReturnType<typeof scopeValues>) {
  const tags: Record<AppRole, string> = { super_admin: 'SA', state_admin: 'ST', lga_admin: 'LG', ward_admin: 'WD', polling_unit_staff: 'PU' };
  const parts = [scope.state_code, scope.lga_code, scope.ward_code, scope.polling_unit_code].filter((value): value is string => !!value).map((value) => value.replace(/[^A-Z0-9]/g, '').slice(0, 3));
  return `${parts.join('-')}-${tags[scope.role]}-${randomBytes(3).toString('hex').slice(0, 5).toUpperCase()}`;
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!setCorsHeaders(req, res)) return sendError(res, 403, 'FORBIDDEN', 'This origin is not allowed.');
  if (req.method === 'OPTIONS') return res.status(204).end();
  const principal = await authenticateRequest(req, res);
  if (!principal) return;
  if (principal.profile.role !== 'super_admin' || principal.profile.must_change_password) return sendError(res, 403, 'FORBIDDEN', 'Only an initialized Super Admin can manage accounts.');
  const { adminClient } = supabaseClients();

  if (req.method === 'GET') {
    const { data, error } = await adminClient.from('user_profiles')
      .select('auth_user_id,user_id,full_name,role,state_code,lga_code,ward_code,polling_unit_code,is_active,must_change_password,created_at')
      .neq('role', 'super_admin').order('created_at', { ascending: false }).limit(500);
    if (error) {
      console.error('Account directory lookup failed', error.code);
      return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to load accounts.');
    }
    return res.status(200).json({ data: data ?? [] });
  }
  if (req.method !== 'PATCH') {
    res.setHeader('Allow', 'GET, PATCH, OPTIONS');
    return sendError(res, 405, 'METHOD_NOT_ALLOWED', 'Use GET or PATCH.');
  }

  const body = req.body as (Scope & { accountId?: unknown; action?: unknown }) | undefined;
  const accountId = isText(body?.accountId) ? body.accountId.trim() : '';
  const action = body?.action;
  if (!accountId || !['deactivate', 'reactivate', 'reset_password', 'assign'].includes(String(action))) return sendError(res, 400, 'VALIDATION_ERROR', 'A target account and supported action are required.');
  const { data: target, error: targetError } = await adminClient.from('user_profiles')
    .select('auth_user_id,user_id,full_name,role,state_code,lga_code,ward_code,polling_unit_code,is_active,must_change_password')
    .eq('auth_user_id', accountId).maybeSingle();
  if (targetError || !target) return sendError(res, targetError ? 500 : 404, targetError ? 'INTERNAL_ERROR' : 'NOT_FOUND', 'Account was not found.');
  if (target.role === 'super_admin' || target.auth_user_id === principal.authUser.id) return sendError(res, 403, 'FORBIDDEN', 'Super Admin accounts and your own account cannot be managed here.');
  if (action === 'reset_password' && !target.is_active) return sendError(res, 409, 'CONFLICT', 'Reactivate the account before issuing a temporary password.');

  if (action === 'assign') {
    if (!validScope(body ?? {})) return sendError(res, 400, 'VALIDATION_ERROR', 'The role and geographic assignment are invalid.');
    const next = scopeValues(body!);
    if (!(await scopeExists(adminClient, next))) return sendError(res, 422, 'VALIDATION_ERROR', 'The assigned location is inactive or does not exist.');
    const newUserId = assignedUserId(next);
    const { error: authError } = await adminClient.auth.admin.updateUserById(accountId, { email: `${newUserId.toLowerCase()}@${AUTH_EMAIL_DOMAIN}`, email_confirm: true });
    if (authError) {
      console.error('Account login identifier update failed', authError.code);
      return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to update the account login identifier.');
    }
    const { error } = await adminClient.from('user_profiles').update({ ...next, user_id: newUserId, must_change_password: true, updated_at: new Date().toISOString() }).eq('auth_user_id', accountId);
    if (error) {
      await adminClient.auth.admin.updateUserById(accountId, { email: `${target.user_id.toLowerCase()}@${AUTH_EMAIL_DOMAIN}`, email_confirm: true });
      console.error('Account assignment update failed', error.code);
      return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to update the account assignment.');
    }
    const { error: auditError } = await adminClient.from('audit_events').insert({ actor_id: principal.authUser.id, event_type: 'account.assignment_changed', entity_type: 'user_profile', entity_id: accountId, details: { previousUserId: target.user_id, userId: newUserId, before: { role: target.role, stateCode: target.state_code, lgaCode: target.lga_code, wardCode: target.ward_code, pollingUnitCode: target.polling_unit_code }, after: next } });
    if (auditError) {
      await adminClient.from('user_profiles').update({ user_id: target.user_id, role: target.role, state_code: target.state_code, lga_code: target.lga_code, ward_code: target.ward_code, polling_unit_code: target.polling_unit_code, must_change_password: target.must_change_password }).eq('auth_user_id', accountId);
      await adminClient.auth.admin.updateUserById(accountId, { email: `${target.user_id.toLowerCase()}@${AUTH_EMAIL_DOMAIN}`, email_confirm: true });
      console.error('Account assignment audit failed', auditError.code);
      return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to audit the assignment change; the previous assignment was restored.');
    }
    return res.status(200).json({ data: { userId: newUserId, role: next.role, mustChangePassword: true } });
  }

  if (action === 'reset_password') {
    const password = temporaryPassword();
    const { error: authError } = await adminClient.auth.admin.updateUserById(accountId, { password });
    if (authError) {
      console.error('Managed password reset failed', authError.code);
      return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to reset the account password.');
    }
    const { error: profileError } = await adminClient.from('user_profiles').update({ must_change_password: true, updated_at: new Date().toISOString() }).eq('auth_user_id', accountId);
    if (profileError) {
      console.error('Managed password reset profile update failed', profileError.code);
      return sendError(res, 500, 'INTERNAL_ERROR', 'Password was reset but the first-login flag could not be set. Retry the reset.');
    }
    const { error: auditError } = await adminClient.from('audit_events').insert({ actor_id: principal.authUser.id, event_type: 'account.password_reset', entity_type: 'user_profile', entity_id: accountId, details: { userId: target.user_id } });
    if (auditError) {
      console.error('Managed password reset audit failed', auditError.code);
      return res.status(200).json({ data: { userId: target.user_id, temporaryPassword: password, mustChangePassword: true, auditWarning: true } });
    }
    return res.status(200).json({ data: { userId: target.user_id, temporaryPassword: password, mustChangePassword: true } });
  }

  const isActive = action === 'reactivate';
  const { error: auditError } = await adminClient.from('audit_events').insert({ actor_id: principal.authUser.id, event_type: isActive ? 'account.reactivated' : 'account.deactivated', entity_type: 'user_profile', entity_id: accountId, details: { userId: target.user_id } });
  if (auditError) {
    console.error('Account status audit failed', auditError.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to audit the account status change.');
  }
  const { error: updateError } = await adminClient.from('user_profiles').update({ is_active: isActive, updated_at: new Date().toISOString() }).eq('auth_user_id', accountId);
  if (updateError) {
    console.error('Account status update failed', updateError.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to update the account status.');
  }
  return res.status(200).json({ data: { userId: target.user_id, isActive } });
}
