import type { VercelRequest, VercelResponse } from '@vercel/node';
import { authenticateRequest, supabaseClients } from '../../../lib/auth.js';
import { sendError, setCorsHeaders } from '../../../lib/http.js';

type Level = 'states' | 'lgas' | 'wards' | 'polling_units';
const levels = new Set<Level>(['states', 'lgas', 'wards', 'polling_units']);
const isText = (value: unknown): value is string => typeof value === 'string' && value.trim().length > 0;
const codeOf = (value: unknown) => isText(value) ? value.trim().toUpperCase() : '';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!setCorsHeaders(req, res)) return sendError(res, 403, 'FORBIDDEN', 'This origin is not allowed.');
  if (req.method === 'OPTIONS') return res.status(204).end();
  const principal = await authenticateRequest(req, res);
  if (!principal) return;
  if (principal.profile.role !== 'super_admin' || principal.profile.must_change_password) return sendError(res, 403, 'FORBIDDEN', 'Only an initialized Super Admin can manage geography.');
  const { adminClient } = supabaseClients();

  if (req.method === 'GET') {
    const level = req.query.level;
    if (typeof level !== 'string' || !levels.has(level as Level)) return sendError(res, 400, 'VALIDATION_ERROR', 'Choose a valid geography level.');
    const stateCode = codeOf(req.query.stateCode);
    const lgaCode = codeOf(req.query.lgaCode);
    const wardCode = codeOf(req.query.wardCode);
    let query: any;
    switch (level as Level) {
      case 'states': query = adminClient.from('states').select('code,name,is_active,is_fct').order('name'); break;
      case 'lgas':
        if (!stateCode) return sendError(res, 400, 'VALIDATION_ERROR', 'stateCode is required.');
        query = adminClient.from('lgas').select('code,name,state_code,is_active,source_code').eq('state_code', stateCode).order('name'); break;
      case 'wards':
        if (!stateCode || !lgaCode) return sendError(res, 400, 'VALIDATION_ERROR', 'stateCode and lgaCode are required.');
        query = adminClient.from('wards').select('code,name,state_code,lga_code,is_active,source_code').eq('state_code', stateCode).eq('lga_code', lgaCode).order('name'); break;
      case 'polling_units':
        if (!stateCode || !lgaCode || !wardCode) return sendError(res, 400, 'VALIDATION_ERROR', 'stateCode, lgaCode, and wardCode are required.');
        query = adminClient.from('polling_units').select('code,name,state_code,lga_code,ward_code,is_active,delimitation_code').eq('state_code', stateCode).eq('lga_code', lgaCode).eq('ward_code', wardCode).order('name'); break;
    }
    const { data, error } = await query;
    if (error) {
      console.error('Managed geography lookup failed', error.code);
      return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to load geography.');
    }
    return res.status(200).json({ data: data ?? [] });
  }

  if (req.method !== 'POST' && req.method !== 'PATCH') {
    res.setHeader('Allow', 'GET, POST, PATCH, OPTIONS');
    return sendError(res, 405, 'METHOD_NOT_ALLOWED', 'Use GET, POST, or PATCH.');
  }
  const body = req.body as { level?: unknown; code?: unknown; name?: unknown; stateCode?: unknown; lgaCode?: unknown; wardCode?: unknown; sourceCode?: unknown; delimitationCode?: unknown; isActive?: unknown } | undefined;
  if (!body || typeof body.level !== 'string' || !levels.has(body.level as Level)) return sendError(res, 400, 'VALIDATION_ERROR', 'A valid geography level is required.');
  const level = body.level as Level;
  const code = codeOf(body.code);
  const stateCode = codeOf(body.stateCode);
  const lgaCode = codeOf(body.lgaCode);
  const wardCode = codeOf(body.wardCode);
  const name = typeof body.name === 'string' ? body.name.trim() : '';
  const validCode = level === 'states' ? /^[A-Z0-9]{2,3}$/.test(code) : /^[A-Z0-9][A-Z0-9_-]{0,31}$/.test(code);
  if (!validCode) return sendError(res, 400, 'VALIDATION_ERROR', 'Use a valid code for the selected location type.');

  const table = level === 'states' ? 'states' : level;
  const scope: Record<string, string> = {};
  if (level !== 'states') {
    if (!stateCode) return sendError(res, 400, 'VALIDATION_ERROR', 'stateCode is required.');
    scope.state_code = stateCode;
  }
  if (level === 'wards' || level === 'polling_units') {
    if (!lgaCode) return sendError(res, 400, 'VALIDATION_ERROR', 'lgaCode is required.');
    scope.lga_code = lgaCode;
  }
  if (level === 'polling_units') {
    if (!wardCode) return sendError(res, 400, 'VALIDATION_ERROR', 'wardCode is required.');
    scope.ward_code = wardCode;
  }

  if (req.method === 'POST') {
    if (!name || name.length > 160) return sendError(res, 400, 'VALIDATION_ERROR', 'A name between 1 and 160 characters is required.');
    if (level !== 'states') {
      const parent = level === 'lgas' ? await adminClient.from('states').select('code').eq('code', stateCode).eq('is_active', true).maybeSingle()
        : level === 'wards' ? await adminClient.from('lgas').select('code').eq('state_code', stateCode).eq('code', lgaCode).eq('is_active', true).maybeSingle()
        : await adminClient.from('wards').select('code').eq('state_code', stateCode).eq('lga_code', lgaCode).eq('code', wardCode).eq('is_active', true).maybeSingle();
      if (parent.error || !parent.data) return sendError(res, 422, 'VALIDATION_ERROR', 'The parent geography does not exist or is inactive.');
    }
    const row: Record<string, unknown> = { ...scope, code, name, is_active: true };
    if (level === 'lgas' || level === 'wards') row.source_code = codeOf(body.sourceCode) || code;
    if (level === 'polling_units') row.delimitation_code = isText(body.delimitationCode) ? body.delimitationCode.trim().slice(0, 80) : null;
    const { data, error } = await adminClient.from(table).insert(row).select('*').single();
    if (error || !data) {
      console.error('Geography creation failed', error?.code ?? 'no row returned');
      return sendError(res, error?.code === '23505' ? 409 : 500, error?.code === '23505' ? 'CONFLICT' : 'INTERNAL_ERROR', error?.code === '23505' ? 'That code or name already exists in this location.' : 'Unable to create the geography record.');
    }
    const { error: auditError } = await adminClient.from('audit_events').insert({ actor_id: principal.authUser.id, event_type: 'geography.created', entity_type: level, entity_id: code, details: { ...scope, name } });
    if (auditError) {
      await adminClient.from(table).delete().match({ ...scope, code });
      console.error('Geography creation audit failed', auditError.code);
      return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to audit geography creation; the record was removed.');
    }
    return res.status(201).json({ data });
  }

  if (body.isActive !== undefined && typeof body.isActive !== 'boolean') return sendError(res, 400, 'VALIDATION_ERROR', 'isActive must be a boolean.');
  if (body.name !== undefined && (!name || name.length > 160)) return sendError(res, 400, 'VALIDATION_ERROR', 'Name must be between 1 and 160 characters.');
  if (body.isActive === true && level !== 'states') {
    const parent = level === 'lgas' ? await adminClient.from('states').select('code').eq('code', stateCode).eq('is_active', true).maybeSingle()
      : level === 'wards' ? await adminClient.from('lgas').select('code').eq('state_code', stateCode).eq('code', lgaCode).eq('is_active', true).maybeSingle()
      : await adminClient.from('wards').select('code').eq('state_code', stateCode).eq('lga_code', lgaCode).eq('code', wardCode).eq('is_active', true).maybeSingle();
    if (parent.error || !parent.data) return sendError(res, 409, 'CONFLICT', 'Reactivate the parent location first.');
  }
  if (body.isActive === false) {
    const dependencies = level === 'states'
      ? await Promise.all([adminClient.from('lgas').select('code', { count: 'exact', head: true }).eq('state_code', code).eq('is_active', true), adminClient.from('user_profiles').select('auth_user_id', { count: 'exact', head: true }).eq('state_code', code).eq('is_active', true)])
      : level === 'lgas'
        ? await Promise.all([adminClient.from('wards').select('code', { count: 'exact', head: true }).eq('state_code', stateCode).eq('lga_code', code).eq('is_active', true), adminClient.from('user_profiles').select('auth_user_id', { count: 'exact', head: true }).eq('state_code', stateCode).eq('lga_code', code).eq('is_active', true)])
        : level === 'wards'
          ? await Promise.all([adminClient.from('polling_units').select('code', { count: 'exact', head: true }).eq('state_code', stateCode).eq('lga_code', lgaCode).eq('ward_code', code).eq('is_active', true), adminClient.from('user_profiles').select('auth_user_id', { count: 'exact', head: true }).eq('state_code', stateCode).eq('lga_code', lgaCode).eq('ward_code', code).eq('is_active', true)])
          : [null, await adminClient.from('user_profiles').select('auth_user_id', { count: 'exact', head: true }).eq('state_code', stateCode).eq('lga_code', lgaCode).eq('ward_code', wardCode).eq('polling_unit_code', code).eq('is_active', true)];
    if (dependencies.some((dependency) => dependency?.error)) return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to check assigned accounts or child locations.');
    if (dependencies.some((dependency) => (dependency?.count ?? 0) > 0)) return sendError(res, 409, 'CONFLICT', 'Deactivate or move active accounts and child locations before deactivating this record.');
  }

  const patch: Record<string, unknown> = {};
  if (body.name !== undefined) patch.name = name;
  if (body.isActive !== undefined) patch.is_active = body.isActive;
  if (!Object.keys(patch).length) return sendError(res, 400, 'VALIDATION_ERROR', 'Provide a name or isActive change.');
  const { data: prior, error: priorError } = await adminClient.from(table).select('*').match({ ...scope, code }).maybeSingle();
  if (priorError || !prior) return sendError(res, priorError ? 500 : 404, priorError ? 'INTERNAL_ERROR' : 'NOT_FOUND', 'Geography record was not found.');
  const { data, error } = await adminClient.from(table).update(patch).match({ ...scope, code }).select('*').maybeSingle();
  if (error || !data) return sendError(res, error ? 500 : 404, error ? 'INTERNAL_ERROR' : 'NOT_FOUND', 'Unable to update the geography record.');
  const { error: auditError } = await adminClient.from('audit_events').insert({ actor_id: principal.authUser.id, event_type: body.isActive === undefined ? 'geography.renamed' : body.isActive ? 'geography.activated' : 'geography.deactivated', entity_type: level, entity_id: code, details: { ...scope, changes: patch } });
  if (auditError) {
    if (prior) await adminClient.from(table).update({ name: prior.name, is_active: prior.is_active }).match({ ...scope, code });
    console.error('Geography change audit failed', auditError.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to audit the change; the previous geography record was restored.');
  }
  return res.status(200).json({ data });
}
