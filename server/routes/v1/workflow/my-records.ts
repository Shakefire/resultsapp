import type { VercelRequest, VercelResponse } from '@vercel/node';
import { authenticateRequest, supabaseClients } from '../../../lib/auth.js';
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
  const { profile } = principal;
  if (profile.role !== 'polling_unit_staff' || profile.must_change_password || !profile.state_code || !profile.lga_code || !profile.ward_code || !profile.polling_unit_code) {
    return sendError(res, 403, 'FORBIDDEN', 'Only Polling Unit Staff can access these records.');
  }
  const { adminClient } = supabaseClients();
  const { data: submissions, error } = await adminClient.from('result_submissions')
    .select('id,election_id,state_code,lga_code,ward_code,polling_unit_code,status,revision,figures,submitted_at')
    .eq('state_code', profile.state_code).eq('lga_code', profile.lga_code)
    .eq('ward_code', profile.ward_code).eq('polling_unit_code', profile.polling_unit_code)
    .order('revision', { ascending: false }).limit(20);
  if (error) {
    console.error('Polling-unit submission lookup failed', error.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to load your submissions.');
  }
  const submissionIds = (submissions ?? []).map((submission) => submission.id);
  const [evidenceResult, decisionsResult, stateResult, lgaResult, wardResult, puResult] = await Promise.all([
    adminClient.from('evidence_files').select('id,submission_id,evidence_type,object_key,file_name,mime_type,file_size_bytes,captured_at,created_at')
      .eq('state_code', profile.state_code).eq('lga_code', profile.lga_code).eq('ward_code', profile.ward_code).eq('polling_unit_code', profile.polling_unit_code).order('created_at', { ascending: false }).limit(100),
    submissionIds.length ? adminClient.from('review_decisions').select('submission_id,action,reason,created_at').in('submission_id', submissionIds).order('created_at', { ascending: true }) : Promise.resolve({ data: [], error: null }),
    adminClient.from('states').select('name').eq('code', profile.state_code).single(),
    adminClient.from('lgas').select('name').eq('state_code', profile.state_code).eq('code', profile.lga_code).single(),
    adminClient.from('wards').select('name').eq('state_code', profile.state_code).eq('lga_code', profile.lga_code).eq('code', profile.ward_code).single(),
    adminClient.from('polling_units').select('name,delimitation_code').eq('state_code', profile.state_code).eq('lga_code', profile.lga_code).eq('ward_code', profile.ward_code).eq('code', profile.polling_unit_code).single(),
  ]);
  const failures = [evidenceResult.error, decisionsResult.error, stateResult.error, lgaResult.error, wardResult.error, puResult.error].filter(Boolean);
  if (failures.length) {
    console.error('Polling-unit dashboard lookup failed');
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to load polling-unit details.');
  }
  if (!stateResult.data || !lgaResult.data || !wardResult.data || !puResult.data) return sendError(res, 404, 'NOT_FOUND', 'The assigned polling-unit directory record is unavailable.');
  const decisionMap = new Map<string, unknown[]>();
  for (const decision of decisionsResult.data ?? []) decisionMap.set(decision.submission_id, [...(decisionMap.get(decision.submission_id) ?? []), decision]);
  const relatedEvidence = evidenceResult.data ?? [];
  res.status(200).json({ data: {
    assignment: {
      pollingUnitId: profile.polling_unit_code,
      pollingUnitName: puResult.data.name,
      delimitationCode: puResult.data.delimitation_code,
      ward: wardResult.data.name,
      lga: lgaResult.data.name,
      state: stateResult.data.name,
    },
    submissions: (submissions ?? []).map((submission) => ({ ...submission, decisions: decisionMap.get(submission.id) ?? [], evidence: relatedEvidence.filter((file) => file.submission_id === submission.id) })),
    voterRegister: relatedEvidence.find((file) => file.evidence_type === 'voter_register' && file.submission_id === null) ?? null,
  } });
}
