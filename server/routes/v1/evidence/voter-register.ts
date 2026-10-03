import type { VercelRequest, VercelResponse } from '@vercel/node';
import { authenticateRequest, supabaseClients } from '../../../lib/auth.js';
import { deleteObject, inspectObject } from '../../../lib/r2.js';
import { sendError, setCorsHeaders } from '../../../lib/http.js';

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
  const requestBody = req.body as { objectKey?: unknown; fileName?: unknown } | undefined;
  const objectKey = typeof requestBody?.objectKey === 'string' ? requestBody.objectKey.trim() : '';
  const fileName = typeof requestBody?.fileName === 'string' ? requestBody.fileName.trim().split(/[\\/]/).pop()?.slice(0, 160) : '';
  if (!objectKey || !fileName) return sendError(res, 400, 'VALIDATION_ERROR', 'A voter-register upload key and file name are required.');
  const { adminClient } = supabaseClients();
  const { data: grants, error: grantError } = await adminClient.from('evidence_upload_grants')
    .update({ consumed_at: new Date().toISOString() }).eq('object_key', objectKey)
    .eq('auth_user_id', authUser.id).eq('purpose', 'voter_register').is('election_id', null)
    .is('consumed_at', null).gt('expires_at', new Date().toISOString())
    .eq('state_code', profile.state_code).eq('lga_code', profile.lga_code)
    .eq('ward_code', profile.ward_code).eq('polling_unit_code', profile.polling_unit_code)
    .select('object_key,content_type,max_bytes').maybeSingle();
  if (grantError || !grants) return sendError(res, 422, 'VALIDATION_ERROR', 'Upload authorization expired or does not match your polling unit.');
  try {
    const object = await inspectObject(objectKey);
    if (!object.ContentLength || object.ContentLength > Number(grants.max_bytes) || object.ContentType !== grants.content_type || object.ContentType !== 'application/pdf') {
      await adminClient.from('evidence_upload_grants').update({ consumed_at: null }).eq('object_key', objectKey);
      return sendError(res, 422, 'VALIDATION_ERROR', 'The voter register file is not a valid PDF or exceeds 25 MB.');
    }
    const { data: row, error: insertError } = await adminClient.from('evidence_files').insert({
      state_code: profile.state_code,
      lga_code: profile.lga_code,
      ward_code: profile.ward_code,
      polling_unit_code: profile.polling_unit_code,
      evidence_type: 'voter_register',
      object_key: objectKey,
      file_name: fileName,
      mime_type: object.ContentType,
      file_size_bytes: object.ContentLength,
      uploaded_by: authUser.id,
    }).select('id,created_at,file_size_bytes').single();
    if (insertError || !row) {
      await adminClient.from('evidence_upload_grants').update({ consumed_at: null }).eq('object_key', objectKey);
      console.error('Voter register metadata insert failed', insertError?.code);
      return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to save voter-register metadata.');
    }
    const { error: auditError } = await adminClient.from('audit_events').insert({
      actor_id: authUser.id,
      event_type: 'voter_register.uploaded',
      entity_type: 'evidence_file',
      entity_id: row.id,
      details: { stateCode: profile.state_code, lgaCode: profile.lga_code, wardCode: profile.ward_code, pollingUnitCode: profile.polling_unit_code, fileSizeBytes: row.file_size_bytes },
    });
    if (auditError) {
      await adminClient.from('evidence_files').delete().eq('id', row.id);
      await deleteObject(objectKey).catch(() => undefined);
      await adminClient.from('evidence_upload_grants').update({ consumed_at: null }).eq('object_key', objectKey);
      console.error('Voter register audit insert failed', auditError.code);
      return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to audit the voter register upload.');
    }
    return res.status(201).json({ data: { evidenceId: row.id, uploadedAt: row.created_at, fileSizeBytes: row.file_size_bytes } });
  } catch (failure) {
    await adminClient.from('evidence_upload_grants').update({ consumed_at: null }).eq('object_key', objectKey);
    console.error('Voter register R2 verification failed', failure instanceof Error ? failure.message : 'unknown error');
    return sendError(res, 422, 'VALIDATION_ERROR', 'The PDF is not present in secure storage. Upload it again.');
  }
}
