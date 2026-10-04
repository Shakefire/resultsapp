import type { VercelRequest, VercelResponse } from '@vercel/node';
import { authenticateRequest } from '../../lib/auth.js';
import { sendError, setCorsHeaders } from '../../lib/http.js';
import { supabaseClients } from '../../lib/auth.js';

type GeographyLevel = 'states' | 'lgas' | 'wards' | 'polling_units';

function queryValue(value: string | string[] | undefined): string | null {
  if (Array.isArray(value)) return null;
  const normalized = value?.trim().toUpperCase();
  return normalized || null;
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!setCorsHeaders(req, res)) return sendError(res, 403, 'FORBIDDEN', 'This origin is not allowed.');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET, OPTIONS');
    return sendError(res, 405, 'METHOD_NOT_ALLOWED', 'Use GET for this endpoint.');
  }

  const principal = await authenticateRequest(req, res);
  if (!principal) return;
  const isSuperAdmin = principal.profile.role === 'super_admin';
  const isDelegated = principal.profile.can_provision_users === true;
  if ((!isSuperAdmin && !isDelegated) || principal.profile.must_change_password) {
    return sendError(res, 403, 'FORBIDDEN', 'Only an initialized Super Admin or delegated provisioner can access account geography.');
  }

  const level = req.query.level;
  if (typeof level !== 'string' || !['states', 'lgas', 'wards', 'polling_units'].includes(level)) {
    return sendError(res, 400, 'VALIDATION_ERROR', 'Choose a valid geography level.');
  }

  const stateCode = queryValue(req.query.stateCode);
  const lgaCode = queryValue(req.query.lgaCode);
  const wardCode = queryValue(req.query.wardCode);
  const { adminClient } = supabaseClients();

  try {
    let result;
    switch (level as GeographyLevel) {
      case 'states':
        result = await adminClient.from('states').select('code,name,is_active').eq('is_active', true).order('name');
        break;
      case 'lgas':
        if (!stateCode) return sendError(res, 400, 'VALIDATION_ERROR', 'stateCode is required for LGA lookup.');
        result = await adminClient.from('lgas').select('code,name,state_code,is_active').eq('state_code', stateCode).eq('is_active', true).order('name');
        break;
      case 'wards':
        if (!stateCode || !lgaCode) return sendError(res, 400, 'VALIDATION_ERROR', 'stateCode and lgaCode are required for ward lookup.');
        result = await adminClient.from('wards').select('code,name,state_code,lga_code,is_active').eq('state_code', stateCode).eq('lga_code', lgaCode).eq('is_active', true).order('name');
        break;
      case 'polling_units':
        if (!stateCode || !lgaCode || !wardCode) return sendError(res, 400, 'VALIDATION_ERROR', 'stateCode, lgaCode, and wardCode are required for polling-unit lookup.');
        result = await adminClient.from('polling_units').select('code,name,state_code,lga_code,ward_code').eq('state_code', stateCode).eq('lga_code', lgaCode).eq('ward_code', wardCode).eq('is_active', true).order('name');
        break;
    }
    if (result.error) {
      console.error('Geography lookup failed', result.error.code);
      return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to load geographic assignments.');
    }
    res.status(200).json({ data: result.data ?? [] });
  } catch (error) {
    console.error('Geography lookup failed', error instanceof Error ? error.message : 'unknown error');
    sendError(res, 500, 'INTERNAL_ERROR', 'Unable to load geographic assignments.');
  }
}
