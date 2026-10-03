import type { VercelRequest, VercelResponse } from '@vercel/node';
import { authenticateRequest, supabaseClients } from '../../../lib/auth.js';
import { deleteObject, inspectObject } from '../../../lib/r2.js';
import { sendError, setCorsHeaders } from '../../../lib/http.js';

type EvidenceInput = {
  objectKey?: unknown;
  purpose?: unknown;
  contentType?: unknown;
  capturedAt?: unknown;
  fileName?: unknown;
};

function validFigures(value: unknown): value is {
  registeredVoters: number; accreditedVoters: number; partyVotes: Record<string, number>; rejectedVotes: number;
} {
  if (!value || typeof value !== 'object') return false;
  const figures = value as Record<string, unknown>;
  if (!Number.isSafeInteger(figures.registeredVoters) || !Number.isSafeInteger(figures.accreditedVoters) ||
      !Number.isSafeInteger(figures.rejectedVotes) || typeof figures.partyVotes !== 'object' || !figures.partyVotes || Array.isArray(figures.partyVotes)) return false;
  const registered = figures.registeredVoters as number;
  const accredited = figures.accreditedVoters as number;
  const rejected = figures.rejectedVotes as number;
  const votes = Object.values(figures.partyVotes as Record<string, unknown>);
  if (registered < 1 || accredited < 0 || accredited > registered || rejected < 0 || votes.length === 0 ||
      votes.some((vote) => !Number.isSafeInteger(vote) || (vote as number) < 0)) return false;
  return votes.reduce<number>((sum, vote) => sum + (vote as number), rejected) <= accredited;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === 'object' && !Array.isArray(value);
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
  const { profile, authUser } = principal;
  if (profile.role !== 'polling_unit_staff' || profile.must_change_password || !profile.state_code || !profile.lga_code || !profile.ward_code || !profile.polling_unit_code) {
    return sendError(res, 403, 'FORBIDDEN', 'An initialized Polling Unit Staff account is required.');
  }

  const body = req.body as { electionId?: unknown; figures?: unknown; evidence?: unknown; location?: unknown; deviceTimestamp?: unknown } | undefined;
  if (!body || !validFigures(body.figures) || !Array.isArray(body.evidence) || body.evidence.length !== 2 || !isRecord(body.location)) {
    return sendError(res, 400, 'VALIDATION_ERROR', 'Figures, location, result photo, and declaration video are required.');
  }
  const photo = body.evidence.find((item) => (item as EvidenceInput)?.purpose === 'result_photo') as EvidenceInput | undefined;
  const video = body.evidence.find((item) => (item as EvidenceInput)?.purpose === 'declaration_video') as EvidenceInput | undefined;
  if (!photo || !video || typeof photo.objectKey !== 'string' || typeof video.objectKey !== 'string' ||
      typeof photo.capturedAt !== 'string' || typeof video.capturedAt !== 'string' || typeof photo.fileName !== 'string' || typeof video.fileName !== 'string') {
    return sendError(res, 400, 'VALIDATION_ERROR', 'A result photo and declaration video with capture times are required.');
  }
  const location = body.location;
  const latitude = location.latitude;
  const longitude = location.longitude;
  const accuracy = location.accuracyMeters;
  if (typeof latitude !== 'number' || latitude < -90 || latitude > 90 || typeof longitude !== 'number' || longitude < -180 || longitude > 180 || typeof accuracy !== 'number' || accuracy < 0 || accuracy > 25 || location.isMock === true) {
    return sendError(res, 400, 'VALIDATION_ERROR', 'A real GPS capture with accuracy of 25 metres or better is required.');
  }

  const { adminClient } = supabaseClients();
  const { data: unit, error: unitError } = await adminClient.from('polling_units').select('code')
    .eq('state_code', profile.state_code).eq('lga_code', profile.lga_code).eq('ward_code', profile.ward_code)
    .eq('code', profile.polling_unit_code).eq('is_active', true).maybeSingle();
  if (unitError || !unit) {
    if (unitError) console.error('Submission polling-unit scope lookup failed', unitError.code);
    return sendError(res, 403, 'FORBIDDEN', 'The assigned polling unit is inactive or unavailable.');
  }
  const electionCodeOrId = typeof body.electionId === 'string' ? body.electionId.trim() : '';
  if (!electionCodeOrId) return sendError(res, 400, 'VALIDATION_ERROR', 'An election is required.');
  const electionQuery = /^[0-9a-f-]{36}$/i.test(electionCodeOrId)
    ? adminClient.from('elections').select('id,status,opens_at,closes_at').eq('id', electionCodeOrId)
    : adminClient.from('elections').select('id,status,opens_at,closes_at').eq('election_code', electionCodeOrId);
  const { data: election, error: electionError } = await electionQuery.maybeSingle();
  if (electionError) {
    console.error('Submission election lookup failed', electionError.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to validate the election.');
  }
  const now = Date.now();
  if (!election || election.status !== 'open' || (election.opens_at && Date.parse(election.opens_at) > now) || (election.closes_at && Date.parse(election.closes_at) < now)) {
    return sendError(res, 422, 'VALIDATION_ERROR', 'This election is not accepting submissions.');
  }

  const evidence = [photo, video];
  const objectKeys = evidence.map((item) => item.objectKey as string);
  if (new Set(objectKeys).size !== 2) return sendError(res, 400, 'VALIDATION_ERROR', 'Evidence object keys must be unique.');
  const { data: grants, error: grantError } = await adminClient.from('evidence_upload_grants')
    .update({ consumed_at: new Date().toISOString() })
    .eq('auth_user_id', authUser.id).eq('election_id', election.id).is('consumed_at', null)
    .gt('expires_at', new Date().toISOString()).in('object_key', objectKeys)
    .select('object_key,purpose,content_type,max_bytes,state_code,lga_code,ward_code,polling_unit_code');
  if (grantError || grants?.length !== 2) {
    await adminClient.from('evidence_upload_grants').update({ consumed_at: null })
      .eq('auth_user_id', authUser.id).in('object_key', objectKeys).is('election_id', election.id);
    console.error('Evidence grant validation failed', grantError?.code ?? 'grant missing or consumed');
    return sendError(res, 422, 'VALIDATION_ERROR', 'Evidence authorization has expired or does not match this account. Upload the evidence again.');
  }
  const releaseGrants = async () => {
    await adminClient.from('evidence_upload_grants').update({ consumed_at: null }).in('object_key', objectKeys).eq('auth_user_id', authUser.id);
  };
  const grantByKey = new Map(grants.map((grant) => [grant.object_key, grant]));
  for (const item of evidence) {
    const key = item.objectKey as string;
    const grant = grantByKey.get(key);
    if (!grant || grant.purpose !== item.purpose || grant.state_code !== profile.state_code || grant.lga_code !== profile.lga_code || grant.ward_code !== profile.ward_code || grant.polling_unit_code !== profile.polling_unit_code) {
      await releaseGrants();
      return sendError(res, 403, 'FORBIDDEN', 'Evidence does not belong to this polling unit and workflow.');
    }
    try {
      const object = await inspectObject(key);
      if (!object.ContentLength || object.ContentLength < 1 || object.ContentLength > Number(grant.max_bytes) || object.ContentType !== grant.content_type || item.contentType !== grant.content_type) {
        await releaseGrants();
        return sendError(res, 422, 'VALIDATION_ERROR', 'Uploaded evidence metadata is invalid. Upload the file again.');
      }
      (item as EvidenceInput & { verifiedBytes?: number }).verifiedBytes = object.ContentLength;
    } catch (error) {
      await releaseGrants();
      console.error('Uploaded R2 object could not be verified', error instanceof Error ? error.message : 'unknown error');
      return sendError(res, 422, 'VALIDATION_ERROR', 'Uploaded evidence was not found in secure storage. Upload it again.');
    }
  }

  const { data: prior, error: priorError } = await adminClient.from('result_submissions')
    .select('id,revision,status').eq('election_id', election.id).eq('state_code', profile.state_code)
    .eq('lga_code', profile.lga_code).eq('ward_code', profile.ward_code).eq('polling_unit_code', profile.polling_unit_code)
    .order('revision', { ascending: false }).limit(1).maybeSingle();
  if (priorError || (prior && prior.status !== 'returned')) {
    await releaseGrants();
    if (priorError) console.error('Prior submission lookup failed', priorError.code);
    return sendError(res, priorError ? 500 : 409, priorError ? 'INTERNAL_ERROR' : 'CONFLICT', priorError ? 'Unable to validate prior submissions.' : 'A result is already awaiting review for this polling unit.');
  }

  const revision = prior ? prior.revision + 1 : 1;
  const nowIso = new Date().toISOString();
  const { data: submission, error: insertError } = await adminClient.from('result_submissions').insert({
    election_id: election.id,
    state_code: profile.state_code,
    lga_code: profile.lga_code,
    ward_code: profile.ward_code,
    polling_unit_code: profile.polling_unit_code,
    submitted_by: authUser.id,
    status: 'submitted',
    revision,
    figures: body.figures,
    submitted_at: nowIso,
    updated_at: nowIso,
  }).select('id,status,revision,submitted_at').single();
  if (insertError || !submission) {
    await releaseGrants();
    console.error('Result submission insert failed', insertError?.code ?? 'no row returned');
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to save the result submission.');
  }

  const evidenceRows = evidence.map((item) => ({
    submission_id: submission.id,
    state_code: profile.state_code!,
    lga_code: profile.lga_code!,
    ward_code: profile.ward_code!,
    polling_unit_code: profile.polling_unit_code!,
    evidence_type: item.purpose,
    object_key: item.objectKey,
    file_name: (item.fileName as string).split(/[\\/]/).pop()?.slice(0, 160) ?? 'evidence',
    mime_type: item.contentType,
    file_size_bytes: (item as EvidenceInput & { verifiedBytes: number }).verifiedBytes,
    captured_at: item.capturedAt,
    latitude,
    longitude,
    accuracy_meters: accuracy,
    uploaded_by: authUser.id,
  }));
  const { error: evidenceError } = await adminClient.from('evidence_files').insert(evidenceRows);
  if (evidenceError) {
    await adminClient.from('result_submissions').delete().eq('id', submission.id);
    await Promise.all(objectKeys.map((key) => deleteObject(key).catch(() => undefined)));
    await releaseGrants();
    console.error('Submission evidence metadata insert failed', evidenceError.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to save evidence metadata.');
  }
  const { error: auditError } = await adminClient.from('audit_events').insert({
    actor_id: authUser.id,
    event_type: 'result.submitted',
    entity_type: 'result_submission',
    entity_id: submission.id,
    details: { electionId: election.id, revision, evidenceCount: evidenceRows.length },
  });
  if (auditError) {
    await adminClient.from('result_submissions').delete().eq('id', submission.id);
    await Promise.all(objectKeys.map((key) => deleteObject(key).catch(() => undefined)));
    await releaseGrants();
    console.error('Submission audit insert failed', auditError.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to audit this submission.');
  }
  res.status(201).json({ data: { submissionId: submission.id, confirmationCode: `ERS-${submission.id.slice(0, 8).toUpperCase()}`, status: submission.status, revision: submission.revision, submittedAt: submission.submitted_at } });
}
