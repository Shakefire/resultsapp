import { randomUUID } from 'node:crypto';
import type { VercelRequest, VercelResponse } from '@vercel/node';
import { authenticateRequest, supabaseClients } from '../../../lib/auth.js';
import { createUploadUrl, withEvidencePrefix } from '../../../lib/r2.js';
import { sendError, setCorsHeaders } from '../../../lib/http.js';

const rules = {
  result_photo: { contentType: 'image/jpeg', maxBytes: 15 * 1024 * 1024, extension: 'jpg' },
  declaration_video: { contentType: 'video/mp4', maxBytes: 150 * 1024 * 1024, extension: 'mp4' },
  voter_register: { contentType: 'application/pdf', maxBytes: 25 * 1024 * 1024, extension: 'pdf' },
} as const;

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!setCorsHeaders(req, res)) return sendError(res, 403, 'FORBIDDEN', 'This origin is not allowed.');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST, OPTIONS');
    return sendError(res, 405, 'METHOD_NOT_ALLOWED', 'Use POST for this endpoint.');
  }
  const principal = await authenticateRequest(req, res);
  if (!principal) return;
  const { profile, authUser } = principal;
  if (profile.role !== 'polling_unit_staff' || profile.must_change_password || !profile.polling_unit_code || !profile.state_code || !profile.lga_code || !profile.ward_code) {
    return sendError(res, 403, 'FORBIDDEN', 'An initialized Polling Unit Staff account is required.');
  }

  const body = req.body as { purpose?: unknown; electionId?: unknown } | undefined;
  if (typeof body?.purpose !== 'string' || !(body.purpose in rules)) {
    return sendError(res, 400, 'VALIDATION_ERROR', 'Choose a supported evidence type.');
  }
  const purpose = body.purpose as keyof typeof rules;
  const rule = rules[purpose];
  const { adminClient } = supabaseClients();
  const { data: unit, error: unitError } = await adminClient.from('polling_units').select('code')
    .eq('state_code', profile.state_code).eq('lga_code', profile.lga_code).eq('ward_code', profile.ward_code)
    .eq('code', profile.polling_unit_code).eq('is_active', true).maybeSingle();
  if (unitError || !unit) {
    if (unitError) console.error('Polling-unit upload scope lookup failed', unitError.code);
    return sendError(res, 403, 'FORBIDDEN', 'The assigned polling unit is inactive or unavailable.');
  }
  let electionId: string | null = null;
  if (purpose !== 'voter_register') {
    if (typeof body.electionId !== 'string' || !body.electionId.trim()) return sendError(res, 400, 'VALIDATION_ERROR', 'An election is required for result evidence.');
    const requestedElection = body.electionId.trim();
    const electionQuery = /^[0-9a-f-]{36}$/i.test(requestedElection)
      ? adminClient.from('elections').select('id,status,opens_at,closes_at').eq('id', requestedElection)
      : adminClient.from('elections').select('id,status,opens_at,closes_at').eq('election_code', requestedElection);
    const { data: election, error } = await electionQuery.maybeSingle();
    if (error) {
      console.error('Evidence election lookup failed', error.code);
      return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to validate the election.');
    }
    const now = Date.now();
    if (!election || election.status !== 'open' || (election.opens_at && Date.parse(election.opens_at) > now) || (election.closes_at && Date.parse(election.closes_at) < now)) {
      return sendError(res, 422, 'VALIDATION_ERROR', 'This election is not accepting submissions.');
    }
    electionId = election.id;
  }

  const extension = rule.extension;
  const key = withEvidencePrefix(`${purpose === 'voter_register' ? 'registers' : 'elections'}/${electionId ?? 'unassigned'}/${profile.state_code}/${profile.lga_code}/${profile.ward_code}/${profile.polling_unit_code}/${authUser.id}/${randomUUID()}.${extension}`);
  try {
    const uploadUrl = await createUploadUrl(key, rule.contentType);
    const { error: grantError } = await adminClient.from('evidence_upload_grants').insert({
      object_key: key,
      auth_user_id: authUser.id,
      purpose,
      content_type: rule.contentType,
      max_bytes: rule.maxBytes,
      state_code: profile.state_code,
      lga_code: profile.lga_code,
      ward_code: profile.ward_code,
      polling_unit_code: profile.polling_unit_code,
      election_id: electionId,
      expires_at: new Date(Date.now() + 5 * 60 * 1000).toISOString(),
    });
    if (grantError) {
      console.error('Evidence upload grant creation failed', grantError.code);
      return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to authorize this evidence upload.');
    }
    return res.status(200).json({ data: { objectKey: key, uploadUrl, contentType: rule.contentType, maxBytes: rule.maxBytes, expiresInSeconds: 300 } });
  } catch (error) {
    console.error('R2 upload authorization failed', error instanceof Error ? error.message : 'unknown error');
    return sendError(res, 500, 'INTERNAL_ERROR', 'Evidence storage is not configured.');
  }
}
