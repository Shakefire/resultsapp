import { randomBytes } from 'node:crypto';
import type { VercelRequest, VercelResponse } from '@vercel/node';
import { authenticateRequest, type AppRole } from '../../../lib/auth.js';
import { sendError, setCorsHeaders } from '../../../lib/http.js';
import { supabaseClients } from '../../../lib/auth.js';

const AUTH_EMAIL_DOMAIN = 'accounts.smart-electoral-results.invalid';
const roles = new Set<AppRole>([
  'state_admin', 'lga_admin', 'ward_admin', 'polling_unit_staff',
]);
type ProvisionInput = {
  fullName?: unknown;
  role?: unknown;
  stateCode?: unknown;
  lgaCode?: unknown;
  wardCode?: unknown;
  pollingUnitCode?: unknown;
};

function isText(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

function locationMatchesRole(input: ProvisionInput): input is ProvisionInput & {
  fullName: string; role: AppRole; stateCode: string;
} {
  if (!isText(input.fullName) || input.fullName.trim().length > 120 ||
      !isText(input.role) || !roles.has(input.role as AppRole) || !isText(input.stateCode)) return false;
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

function makeUserId(input: ProvisionInput): string {
  // Geographic codes are identifiers only; authorization always uses the stored role/scope.
  const scope = [input.stateCode, input.lgaCode, input.wardCode, input.pollingUnitCode]
    .filter((part): part is string => isText(part))
    .map((part) => part.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 3));
  const roleTag: Record<AppRole, string> = {
    super_admin: 'SA', state_admin: 'ST', lga_admin: 'LG', ward_admin: 'WD', polling_unit_staff: 'PU',
  };
  return `${scope.join('-')}-${roleTag[input.role as AppRole]}-${randomBytes(4).toString('hex').slice(0, 5).toUpperCase()}`;
}

function temporaryPassword(): string {
  return `E!${randomBytes(18).toString('base64url')}9a`;
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
  if (principal.profile.role !== 'super_admin') {
    return sendError(res, 403, 'FORBIDDEN', 'Only Super Admin can provision accounts.');
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

  // Verify the complete hierarchy exists before creating an Auth account.
  const locationQuery = adminClient.from('polling_units').select('code')
    .eq('state_code', stateCode).eq('lga_code', lgaCode ?? '').eq('ward_code', wardCode ?? '').eq('code', pollingUnitCode ?? '').eq('is_active', true);
  const { data: location, error: locationError } = input.role === 'polling_unit_staff'
    ? await locationQuery.maybeSingle()
    : input.role === 'ward_admin'
      ? await adminClient.from('wards').select('code').eq('state_code', stateCode).eq('lga_code', lgaCode!).eq('code', wardCode!).eq('is_active', true).maybeSingle()
      : input.role === 'lga_admin'
        ? await adminClient.from('lgas').select('code').eq('state_code', stateCode).eq('code', lgaCode!).eq('is_active', true).maybeSingle()
        : await adminClient.from('states').select('code').eq('code', stateCode).eq('is_active', true).maybeSingle();
  if (locationError || !location) {
    return sendError(res, 422, 'VALIDATION_ERROR', 'The assigned geographic location does not exist.');
  }

  const userId = makeUserId({ ...input, stateCode, lgaCode, wardCode, pollingUnitCode });
  const password = temporaryPassword();
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

  const { error: profileError } = await adminClient.from('user_profiles').insert({
    auth_user_id: created.user.id,
    user_id: userId,
    full_name: input.fullName.trim(),
    role: input.role,
    state_code: stateCode,
    lga_code: lgaCode,
    ward_code: wardCode,
    polling_unit_code: pollingUnitCode,
    must_change_password: true,
    provisioned_by: principal.authUser.id,
  });

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
    details: { userId, role: input.role, stateCode, lgaCode, wardCode, pollingUnitCode },
  });
  if (auditError) {
    await adminClient.auth.admin.deleteUser(created.user.id);
    console.error('Account provisioning audit write failed', auditError.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to record the account provisioning event.');
  }

  res.status(201).json({ data: { userId, temporaryPassword: password, mustChangePassword: true } });
}
