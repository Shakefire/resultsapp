import type { VercelRequest, VercelResponse } from '@vercel/node';
import { authenticateRequest, type AppRole, supabaseClients } from '../../../lib/auth.js';
import { sendError, setCorsHeaders } from '../../../lib/http.js';
import { makeTemporaryPassword } from '../../../lib/credentials.js';
import { generateUserId } from '../../../lib/identifiers.js';

const AUTH_EMAIL_DOMAIN = 'accounts.smart-electoral-results.invalid';
const allRoles = new Set<AppRole>([
  'state_admin', 'lga_admin', 'ward_admin', 'polling_unit_staff',
]);
type ProvisionInput = {
  fullName?: unknown;
  role?: unknown;
  stateCode?: unknown;
  lgaCode?: unknown;
  wardCode?: unknown;
  pollingUnitCode?: unknown;
  canProvisionUsers?: unknown;
};

function isText(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

function locationMatchesRole(input: ProvisionInput): input is ProvisionInput & {
  fullName: string; role: AppRole; stateCode: string;
} {
  if (!isText(input.fullName) || input.fullName.trim().length > 120 ||
      !isText(input.role) || !allRoles.has(input.role as AppRole) || !isText(input.stateCode)) return false;
  switch (input.role) {
    case 'state_admin':
      return input.lgaCode == null && input.wardCode == null && input.pollingUnitCode == null;
    case 'lga_admin':
      return isText(input.lgaCode) && input.wardCode == null && input.pollingUnitCode == null;
    case 'ward_admin':
      return isText(input.lgaCode) && isText(input.wardCode) && input.pollingUnitCode == null;
    case 'polling_unit_staff':
      return isText(input.lgaCode) && isText(input.wardCode) && isText(input.pollingUnitCode);
    default:
      return false;
  }
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!setCorsHeaders(req, res)) return sendError(res, 403, 'FORBIDDEN', 'This origin is not allowed.');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST, OPTIONS');
    return sendError(res, 405, 'METHOD_NOT_ALLOWED', 'Use POST for this endpoint.');
  }

  const principal = await authenticateRequest(req, res);
  if (!principal) return;

  const isSuperAdmin = principal.profile.role === 'super_admin';
  const isDelegated = principal.profile.can_provision_users === true && !isSuperAdmin;

  if (!isSuperAdmin && !isDelegated) {
    return sendError(res, 403, 'FORBIDDEN', 'Only Super Admin or a delegated provisioner can create accounts.');
  }
  if (principal.profile.must_change_password) {
    return sendError(res, 403, 'FORBIDDEN', 'Change the temporary password before using administration features.');
  }

  const input = req.body as ProvisionInput | undefined;
  if (!input || !locationMatchesRole(input)) {
    return sendError(res, 400, 'VALIDATION_ERROR', 'Account details or role location scope are invalid.');
  }

  const { adminClient } = supabaseClients();
  const stateCode = input.stateCode.trim().toUpperCase();
  const lgaCode = isText(input.lgaCode) ? input.lgaCode.trim().toUpperCase() : null;
  const wardCode = isText(input.wardCode) ? input.wardCode.trim().toUpperCase() : null;
  const pollingUnitCode = isText(input.pollingUnitCode) ? input.pollingUnitCode.trim().toUpperCase() : null;
  const targetRole = input.role as AppRole;

  // Enforce geographic scope for delegated admins.
  if (isDelegated) {
    const actorRole = principal.profile.role;
    const actorState = principal.profile.state_code;
    const actorLga = principal.profile.lga_code;
    const actorWard = principal.profile.ward_code;
    if (stateCode !== actorState) {
      return sendError(res, 403, 'FORBIDDEN', 'You can only provision accounts within your assigned state.');
    }
    if (actorRole === 'lga_admin') {
      if (lgaCode !== actorLga) {
        return sendError(res, 403, 'FORBIDDEN', 'You can only provision accounts within your assigned LGA.');
      }
      if (targetRole === 'state_admin' || targetRole === 'lga_admin') {
        return sendError(res, 403, 'FORBIDDEN', 'LGA Admin can only create ward-level or polling-unit accounts.');
      }
    }
    if (actorRole === 'ward_admin') {
      if (lgaCode !== actorLga || wardCode !== actorWard) {
        return sendError(res, 403, 'FORBIDDEN', 'You can only provision accounts within your assigned Ward.');
      }
      if (targetRole !== 'polling_unit_staff') {
        return sendError(res, 403, 'FORBIDDEN', 'Ward Admin can only create polling unit accounts.');
      }
    }
    if (actorRole === 'state_admin' && targetRole === 'state_admin') {
      return sendError(res, 403, 'FORBIDDEN', 'State Admin cannot create other State Admin accounts.');
    }
  }

  // Granting provision power down the chain:
  // Super Admin can grant to state_admin, lga_admin, ward_admin
  // State Admin can grant to lga_admin, ward_admin
  // LGA Admin can grant to ward_admin
  const requestedProvisionPower = input.canProvisionUsers === true;
  const canGrant = isSuperAdmin ||
    (isDelegated && principal.profile.role === 'state_admin' && (targetRole === 'lga_admin' || targetRole === 'ward_admin')) ||
    (isDelegated && principal.profile.role === 'lga_admin' && targetRole === 'ward_admin');
  const provisionPower = requestedProvisionPower && canGrant;

  // Verify the complete hierarchy exists before creating an Auth account.
  const { data: location, error: locationError } = targetRole === 'polling_unit_staff'
    ? await adminClient.from('polling_units').select('code')
        .eq('state_code', stateCode).eq('lga_code', lgaCode ?? '').eq('ward_code', wardCode ?? '')
        .eq('code', pollingUnitCode ?? '').eq('is_active', true).maybeSingle()
    : targetRole === 'ward_admin'
      ? await adminClient.from('wards').select('code')
          .eq('state_code', stateCode).eq('lga_code', lgaCode!).eq('code', wardCode!).eq('is_active', true).maybeSingle()
      : targetRole === 'lga_admin'
        ? await adminClient.from('lgas').select('code')
            .eq('state_code', stateCode).eq('code', lgaCode!).eq('is_active', true).maybeSingle()
        : await adminClient.from('states').select('code')
            .eq('code', stateCode).eq('is_active', true).maybeSingle();

  if (locationError || !location) {
    return sendError(res, 422, 'VALIDATION_ERROR', 'The assigned geographic location does not exist.');
  }

  // Fetch LGA name for deterministic ID generation.
  let lgaName: string | null = null;
  if (lgaCode) {
    const { data: lgaRow } = await adminClient.from('lgas').select('name')
      .eq('state_code', stateCode).eq('code', lgaCode).maybeSingle();
    lgaName = lgaRow?.name ?? null;
  }

  const userId = generateUserId({ role: targetRole, stateCode, lgaCode, lgaName, wardCode, pollingUnitCode });
  const password = makeTemporaryPassword();
  const internalEmail = `${userId.toLowerCase()}@${AUTH_EMAIL_DOMAIN}`;
  const { data: created, error: createError } = await adminClient.auth.admin.createUser({
    email: internalEmail,
    password,
    email_confirm: true,
    user_metadata: { user_id: userId },
  });
  if (createError || !created.user) {
    console.error('Auth account provisioning failed', createError?.code ?? 'unknown');
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to provision the account.');
  }

  const profileData: Record<string, unknown> = {
    auth_user_id: created.user.id,
    user_id: userId,
    full_name: input.fullName.trim(),
    role: targetRole,
    state_code: stateCode,
    lga_code: lgaCode,
    ward_code: wardCode,
    polling_unit_code: pollingUnitCode,
    must_change_password: true,
    can_provision_users: provisionPower,
    provisioned_by: principal.authUser.id,
  };
  let { error: profileError } = await adminClient.from('user_profiles').insert(profileData);
  if (profileError && profileError.code === '42703' && 'can_provision_users' in profileData) {
    delete profileData.can_provision_users;
    profileError = (await adminClient.from('user_profiles').insert(profileData)).error;
  }

  if (profileError) {
    await adminClient.auth.admin.deleteUser(created.user.id);
    console.error('Account profile provisioning failed', profileError.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to complete account provisioning.');
  }

  const { error: auditError } = await adminClient.from('audit_events').insert({
    actor_id: principal.authUser.id,
    event_type: 'account.provisioned',
    entity_type: 'user_profile',
    entity_id: created.user.id,
    details: { userId, role: targetRole, stateCode, lgaCode, wardCode, pollingUnitCode, canProvisionUsers: provisionPower },
  });
  if (auditError) {
    await adminClient.auth.admin.deleteUser(created.user.id);
    console.error('Account provisioning audit write failed', auditError.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to record the account provisioning event.');
  }

  res.status(201).json({ data: { userId, temporaryPassword: password, mustChangePassword: true, canProvisionUsers: provisionPower } });
}
