import type { VercelRequest, VercelResponse } from '@vercel/node';
import { authenticateRequest, supabaseClients } from '../../../lib/auth.js';
import { createDownloadUrl } from '../../../lib/r2.js';
import { sendError, setCorsHeaders } from '../../../lib/http.js';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!setCorsHeaders(req, res)) return sendError(res, 403, 'FORBIDDEN', 'This origin is not allowed.');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET, OPTIONS');
    return sendError(res, 405, 'METHOD_NOT_ALLOWED', 'Use GET for this endpoint.');
  }
  const principal = await authenticateRequest(req, res);
  if (!principal) return;
  const objectKey = typeof req.query.objectKey === 'string' ? req.query.objectKey : '';
  if (!objectKey) return sendError(res, 400, 'VALIDATION_ERROR', 'An evidence object key is required.');
  const { adminClient } = supabaseClients();
  const { data: evidence, error } = await adminClient.from('evidence_files')
    .select('id,object_key,state_code,lga_code,ward_code,polling_unit_code,evidence_type')
    .eq('object_key', objectKey).maybeSingle();
  if (error) {
    console.error('Evidence lookup failed', error.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to retrieve evidence.');
  }
  if (!evidence) return sendError(res, 404, 'NOT_FOUND', 'Evidence was not found.');
  const profile = principal.profile;
  if (profile.must_change_password) return sendError(res, 403, 'FORBIDDEN', 'Change the temporary password before accessing evidence.');
  const allowed = profile.is_active && (
    (profile.role === 'polling_unit_staff' && profile.state_code === evidence.state_code && profile.lga_code === evidence.lga_code && profile.ward_code === evidence.ward_code && profile.polling_unit_code === evidence.polling_unit_code) ||
    (profile.role === 'ward_admin' && profile.state_code === evidence.state_code && profile.lga_code === evidence.lga_code && profile.ward_code === evidence.ward_code) ||
    (profile.role === 'lga_admin' && profile.state_code === evidence.state_code && profile.lga_code === evidence.lga_code) ||
    (profile.role === 'state_admin' && profile.state_code === evidence.state_code)
  );
  if (!allowed) return sendError(res, 403, 'FORBIDDEN', 'This evidence is outside your assigned geography.');
  try {
    const url = await createDownloadUrl(evidence.object_key);
    return res.status(200).json({ data: { url, expiresInSeconds: 300, evidenceType: evidence.evidence_type } });
  } catch (failure) {
    console.error('R2 download authorization failed', failure instanceof Error ? failure.message : 'unknown error');
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to authorize evidence access.');
  }
}
