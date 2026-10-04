import type { VercelRequest, VercelResponse } from '@vercel/node';
import { authenticateRequest, type AppRole, supabaseClients } from '../../../lib/auth.js';
import { sendError, setCorsHeaders } from '../../../lib/http.js';
import { makeTemporaryPassword } from '../../../lib/credentials.js';
import { generateUserId } from '../../../lib/identifiers.js';

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

async function fetchLgaName(admin: ReturnType<typeof supabaseClients>['adminClient'], stateCode: string | null, lgaCode: string | null): Promise<string | null> {
  if (!stateCode || !lgaCode) return null;
  const { data } = await admin.from('lgas').select('name').eq('state_code', stateCode).eq('code', lgaCode).maybeSingle();
  return (data as { name: string } | null)?.name ?? null;
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!setCorsHeaders(req, res)) return sendError(res, 403, 'FORBIDDEN', 'This origin is not allowed.');
  if (req.method === 'OPTIONS') return res.status(204).end();
  const principal = await authenticateRequest(req, res);
  if (!principal) return;

  const isSuperAdmin = principal.profile.role === 'super_admin';
  const isDelegated = principal.profile.can_provision_users === true && !isSuperAdmin;

  if (!isSuperAdmin && !isDelegated) return sendError(res, 403, 'FORBIDDEN', 'Only an initialized Super Admin or delegated provisioner can manage accounts.');
  if (principal.profile.must_change_password) return sendError(res, 403, 'FORBIDDEN', 'Change the temporary password before using administration features.');

  const { adminClient } = supabaseClients();

  if (req.method === 'GET') {
    let query = adminClient.from('user_profiles')
      .select('auth_user_id,user_id,full_name,role,state_code,lga_code,ward_code,polling_unit_code,is_active,must_change_password,can_provision_users,created_at')
      .neq('role', 'super_admin').order('created_at', { ascending: false }).limit(500);
    // Delegated provisioners see only accounts in their scope
    if (isDelegated) {
      query = (query as any).eq('state_code', principal.profile.state_code ?? '');
      if (principal.profile.role === 'lga_admin') {
        query = (query as any).eq('lga_code', principal.profile.lga_code ?? '');
      }
    }
    let { data, error } = await query;
    if (error && error.code === '42703') {
      let fallbackQuery = adminClient.from('user_profiles')
        .select('auth_user_id,user_id,full_name,role,state_code,lga_code,ward_code,polling_unit_code,is_active,must_change_password,created_at')
        .neq('role', 'super_admin').order('created_at', { ascending: false }).limit(500);
      if (isDelegated) {
        fallbackQuery = (fallbackQuery as any).eq('state_code', principal.profile.state_code ?? '');
        if (principal.profile.role === 'lga_admin') {
          fallbackQuery = (fallbackQuery as any).eq('lga_code', principal.profile.lga_code ?? '');
        }
      }
      const fallbackResult = await fallbackQuery;
      data = fallbackResult.data ? fallbackResult.data.map((r: any) => ({ ...r, can_provision_users: false })) : null;
      error = fallbackResult.error;
    }
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
  if (!accountId || !['deactivate', 'reactivate', 'reset_password', 'assign', 'toggle_provision_power'].includes(String(action))) return sendError(res, 400, 'VALIDATION_ERROR', 'A target account and supported action are required.');
  let { data: target, error: targetError } = await adminClient.from('user_profiles')
    .select('auth_user_id,user_id,full_name,role,state_code,lga_code,ward_code,polling_unit_code,is_active,must_change_password,can_provision_users')
    .eq('auth_user_id', accountId).maybeSingle();
  if (targetError && targetError.code === '42703') {
    const fallbackTarget = await adminClient.from('user_profiles')
      .select('auth_user_id,user_id,full_name,role,state_code,lga_code,ward_code,polling_unit_code,is_active,must_change_password')
      .eq('auth_user_id', accountId).maybeSingle();
    target = fallbackTarget.data ? { ...fallbackTarget.data, can_provision_users: false } as any : null;
    targetError = fallbackTarget.error;
  }
  if (targetError || !target) return sendError(res, targetError ? 500 : 404, targetError ? 'INTERNAL_ERROR' : 'NOT_FOUND', 'Account was not found.');
  if ((target as any).role === 'super_admin' || (target as any).auth_user_id === principal.authUser.id) return sendError(res, 403, 'FORBIDDEN', 'Super Admin accounts and your own account cannot be managed here.');
  if (action === 'reset_password' && !(target as any).is_active) return sendError(res, 409, 'CONFLICT', 'Reactivate the account before issuing a temporary password.');

  if (action === 'toggle_provision_power') {
    const targetRole = (target as any).role as string;
    const actorCanToggle = isSuperAdmin ||
      (isDelegated && principal.profile.role === 'state_admin' && (targetRole === 'lga_admin' || targetRole === 'ward_admin')) ||
      (isDelegated && principal.profile.role === 'lga_admin' && targetRole === 'ward_admin');
    if (!actorCanToggle) {
      return sendError(res, 403, 'FORBIDDEN', 'You do not have permission to grant or revoke provisioning power for this role.');
    }
    if (targetRole !== 'state_admin' && targetRole !== 'lga_admin' && targetRole !== 'ward_admin') {
      return sendError(res, 400, 'VALIDATION_ERROR', 'Provisioning power can only be granted to State Admin, LGA Admin, or Ward Admin.');
    }
    const newValue = !(target as any).can_provision_users;
    const { error: updateError } = await adminClient.from('user_profiles')
      .update({ can_provision_users: newValue, updated_at: new Date().toISOString() })
      .eq('auth_user_id', accountId);
    if (updateError) {
      console.error('Toggle provision power failed', updateError.code);
      return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to update provisioning power.');
    }
    const { error: auditError } = await adminClient.from('audit_events').insert({
      actor_id: principal.authUser.id,
      event_type: newValue ? 'account.provision_power_granted' : 'account.provision_power_revoked',
      entity_type: 'user_profile',
      entity_id: accountId,
      details: { userId: (target as any).user_id, canProvisionUsers: newValue },
    });
    if (auditError) console.error('Toggle provision power audit failed', auditError.code);
    return res.status(200).json({ data: { userId: (target as any).user_id, canProvisionUsers: newValue } });
  }

  if (action === 'assign') {
    if (!isSuperAdmin) return sendError(res, 403, 'FORBIDDEN', 'Only Super Admin can reassign accounts.');
    if (!validScope(body ?? {})) return sendError(res, 400, 'VALIDATION_ERROR', 'The role and geographic assignment are invalid.');
    const next = scopeValues(body!);
    if (!(await scopeExists(adminClient, next))) return sendError(res, 422, 'VALIDATION_ERROR', 'The assigned location is inactive or does not exist.');
    const lgaName = await fetchLgaName(adminClient, next.state_code, next.lga_code);
    const newUserId = generateUserId({
      role: next.role,
      stateCode: next.state_code ?? undefined,
      lgaCode: next.lga_code ?? undefined,
      lgaName: lgaName ?? undefined,
      wardCode: next.ward_code ?? undefined,
      pollingUnitCode: next.polling_unit_code ?? undefined,
    });
    const { error: authError } = await adminClient.auth.admin.updateUserById(accountId, { email: `${newUserId.toLowerCase()}@${AUTH_EMAIL_DOMAIN}`, email_confirm: true });
    if (authError) {
      console.error('Account login identifier update failed', authError.code);
      return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to update the account login identifier.');
    }
    const { error } = await adminClient.from('user_profiles').update({ ...next, user_id: newUserId, must_change_password: true, updated_at: new Date().toISOString() }).eq('auth_user_id', accountId);
    if (error) {
      await adminClient.auth.admin.updateUserById(accountId, { email: `${(target as any).user_id.toLowerCase()}@${AUTH_EMAIL_DOMAIN}`, email_confirm: true });
      console.error('Account assignment update failed', error.code);
      return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to update the account assignment.');
    }
    const { error: auditError } = await adminClient.from('audit_events').insert({ actor_id: principal.authUser.id, event_type: 'account.assignment_changed', entity_type: 'user_profile', entity_id: accountId, details: { previousUserId: (target as any).user_id, userId: newUserId, before: { role: (target as any).role, stateCode: (target as any).state_code, lgaCode: (target as any).lga_code, wardCode: (target as any).ward_code, pollingUnitCode: (target as any).polling_unit_code }, after: next } });
    if (auditError) {
      await adminClient.from('user_profiles').update({ user_id: (target as any).user_id, role: (target as any).role, state_code: (target as any).state_code, lga_code: (target as any).lga_code, ward_code: (target as any).ward_code, polling_unit_code: (target as any).polling_unit_code, must_change_password: (target as any).must_change_password }).eq('auth_user_id', accountId);
      await adminClient.auth.admin.updateUserById(accountId, { email: `${(target as any).user_id.toLowerCase()}@${AUTH_EMAIL_DOMAIN}`, email_confirm: true });
      console.error('Account assignment audit failed', auditError.code);
      return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to audit the assignment change; the previous assignment was restored.');
    }
    return res.status(200).json({ data: { userId: newUserId, role: next.role, mustChangePassword: true } });
  }

  if (action === 'reset_password') {
    const password = makeTemporaryPassword();
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
    const { error: auditError } = await adminClient.from('audit_events').insert({ actor_id: principal.authUser.id, event_type: 'account.password_reset', entity_type: 'user_profile', entity_id: accountId, details: { userId: (target as any).user_id } });
    if (auditError) {
      console.error('Managed password reset audit failed', auditError.code);
      return res.status(200).json({ data: { userId: (target as any).user_id, temporaryPassword: password, mustChangePassword: true, auditWarning: true } });
    }
    return res.status(200).json({ data: { userId: (target as any).user_id, temporaryPassword: password, mustChangePassword: true } });
  }

  const isActive = action === 'reactivate';
  const { error: auditError } = await adminClient.from('audit_events').insert({ actor_id: principal.authUser.id, event_type: isActive ? 'account.reactivated' : 'account.deactivated', entity_type: 'user_profile', entity_id: accountId, details: { userId: (target as any).user_id } });
  if (auditError) {
    console.error('Account status audit failed', auditError.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to audit the account status change.');
  }
  const { error: updateError } = await adminClient.from('user_profiles').update({ is_active: isActive, updated_at: new Date().toISOString() }).eq('auth_user_id', accountId);
  if (updateError) {
    console.error('Account status update failed', updateError.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to update the account status.');
  }
  return res.status(200).json({ data: { userId: (target as any).user_id, isActive } });
}
