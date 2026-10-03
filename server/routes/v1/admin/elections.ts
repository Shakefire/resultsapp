import type { VercelRequest, VercelResponse } from '@vercel/node';
import { authenticateRequest, supabaseClients } from '../../../lib/auth.js';
import { sendError, setCorsHeaders } from '../../../lib/http.js';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!setCorsHeaders(req, res)) return sendError(res, 403, 'FORBIDDEN', 'This origin is not allowed.');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'GET' && req.method !== 'POST' && req.method !== 'PATCH') {
    res.setHeader('Allow', 'GET, POST, PATCH, OPTIONS');
    return sendError(res, 405, 'METHOD_NOT_ALLOWED', 'Use GET or POST for this endpoint.');
  }
  const principal = await authenticateRequest(req, res);
  if (!principal) return;
  if (principal.profile.role !== 'super_admin' || principal.profile.must_change_password) {
    return sendError(res, 403, 'FORBIDDEN', 'Only an initialized Super Admin can manage elections.');
  }
  const { adminClient } = supabaseClients();
  if (req.method === 'GET') {
    const { data, error } = await adminClient.from('elections').select('id,election_code,name,status,opens_at,closes_at,created_at').order('created_at', { ascending: false });
    if (error) {
      console.error('Election listing failed', error.code);
      return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to load elections.');
    }
    return res.status(200).json({ data: data ?? [] });
  }

  if (req.method === 'PATCH') {
    const body = req.body as { electionId?: unknown; status?: unknown } | undefined;
    if (typeof body?.electionId !== 'string' || body.status !== 'closed') return sendError(res, 400, 'VALIDATION_ERROR', 'A valid election and closed status are required.');
    const { data: election, error } = await adminClient.from('elections').update({ status: 'closed' }).eq('id', body.electionId)
      .eq('status', 'open').select('id,election_code,name,status').maybeSingle();
    if (error || !election) {
      if (error) console.error('Election close failed', error.code);
      return sendError(res, error ? 500 : 404, error ? 'INTERNAL_ERROR' : 'NOT_FOUND', error ? 'Unable to close the election.' : 'Open election not found.');
    }
    const { error: auditError } = await adminClient.from('audit_events').insert({ actor_id: principal.authUser.id, event_type: 'election.closed', entity_type: 'election', entity_id: election.id, details: { electionCode: election.election_code } });
    if (auditError) {
      await adminClient.from('elections').update({ status: 'open' }).eq('id', election.id).eq('status', 'closed');
      console.error('Election close audit failed', auditError.code);
      return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to audit election closure; the election was reopened.');
    }
    return res.status(200).json({ data: election });
  }

  const body = req.body as { electionCode?: unknown; name?: unknown; opensAt?: unknown; closesAt?: unknown } | undefined;
  const electionCode = typeof body?.electionCode === 'string' ? body.electionCode.trim().toUpperCase() : '';
  const name = typeof body?.name === 'string' ? body.name.trim() : '';
  const opensAt = typeof body?.opensAt === 'string' ? body.opensAt : null;
  const closesAt = typeof body?.closesAt === 'string' ? body.closesAt : null;
  if (!/^[A-Z0-9][A-Z0-9_-]{2,39}$/.test(electionCode) || !name || name.length > 160 || (opensAt && !Number.isFinite(Date.parse(opensAt))) || (closesAt && !Number.isFinite(Date.parse(closesAt))) || (opensAt && closesAt && Date.parse(opensAt) >= Date.parse(closesAt))) {
    return sendError(res, 400, 'VALIDATION_ERROR', 'Enter a valid election code, name, and optional date range.');
  }
  const { data: currentlyOpen, error: openError } = await adminClient.from('elections').select('id').eq('status', 'open').limit(1);
  if (openError) {
    console.error('Active election lookup failed', openError.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to validate active elections.');
  }
  if (currentlyOpen?.length) return sendError(res, 409, 'CONFLICT', 'Close the current election before creating another open election.');
  const { data: election, error } = await adminClient.from('elections').insert({ election_code: electionCode, name, opens_at: opensAt, closes_at: closesAt, status: 'open' }).select('id,election_code,name,status,opens_at,closes_at').single();
  if (error || !election) {
    console.error('Election creation failed', error?.code ?? 'no row returned');
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to create the election.');
  }
  const { error: auditError } = await adminClient.from('audit_events').insert({ actor_id: principal.authUser.id, event_type: 'election.created', entity_type: 'election', entity_id: election.id, details: { electionCode, name } });
  if (auditError) {
    await adminClient.from('elections').delete().eq('id', election.id);
    console.error('Election creation audit failed', auditError.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to audit election creation.');
  }
  return res.status(201).json({ data: election });
}
