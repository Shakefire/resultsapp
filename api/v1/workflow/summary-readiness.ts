import type { VercelRequest, VercelResponse } from '@vercel/node';
import { authenticateRequest, supabaseClients } from '../../_lib/auth.js';
import { sendError, setCorsHeaders } from '../../_lib/http.js';

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
  if (profile.must_change_password || !['lga_admin', 'state_admin'].includes(profile.role)) return sendError(res, 403, 'FORBIDDEN', 'An initialized LGA or State Admin account is required.');
  const { adminClient } = supabaseClients();
  const { data: elections, error: electionError } = await adminClient.from('elections').select('id,election_code,name,status').order('created_at', { ascending: false });
  if (electionError) {
    console.error('Summary election lookup failed', electionError.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to load summary readiness.');
  }

  if (profile.role === 'lga_admin') {
    const [{ count: expected, data: activeUnits, error: puError }, { data: summaries, error: summaryError }] = await Promise.all([
      adminClient.from('polling_units').select('code', { count: 'exact' }).eq('state_code', profile.state_code!).eq('lga_code', profile.lga_code!).eq('is_active', true),
      adminClient.from('result_summaries').select('election_id,id,approved_at').eq('level', 'lga').eq('state_code', profile.state_code!).eq('lga_code', profile.lga_code!),
    ]);
    if (puError || summaryError) {
      console.error('LGA readiness lookup failed', puError?.code ?? summaryError?.code);
      return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to load LGA completeness.');
    }
    const activeUnitCodes = new Set((activeUnits ?? []).map((unit) => unit.code));
    const summaryMap = new Map((summaries ?? []).map((item) => [item.election_id, item]));
    const entries = await Promise.all((elections ?? []).map(async (election) => {
      const { data: rows, error } = await adminClient.from('result_submissions')
        .select('id,ward_code,polling_unit_code,revision,status').eq('election_id', election.id)
        .eq('state_code', profile.state_code!).eq('lga_code', profile.lga_code!).order('revision', { ascending: false });
      if (error) throw error;
      const latest = new Map<string, { ward_code: string; polling_unit_code: string; status: string }>();
      for (const row of rows ?? []) {
        const key = `${row.ward_code}/${row.polling_unit_code}`;
        if (!latest.has(key)) latest.set(key, row);
      }
      const values = [...latest.values()].filter((row) => activeUnitCodes.has(row.polling_unit_code));
      const verified = values.filter((row) => row.status === 'ward_verified').length;
      const returned = values.filter((row) => row.status === 'returned').length;
      const summary = summaryMap.get(election.id);
      const expectedCount = expected ?? 0;
      return { electionId: election.id, electionCode: election.election_code, electionName: election.name, expected: expectedCount, verified, returned, missing: Math.max(expectedCount - verified, 0), ready: expectedCount > 0 && verified === expectedCount && returned === 0 && !summary, approved: !!summary, approvedAt: summary?.approved_at ?? null };
    }));
    return res.status(200).json({ data: { level: 'lga', entries } });
  }

  const [{ count: expected, error: lgaError }, { data: summaries, error: summaryError }, { data: stateSummaries, error: stateError }] = await Promise.all([
    adminClient.from('lgas').select('code', { count: 'exact', head: true }).eq('state_code', profile.state_code!),
    adminClient.from('result_summaries').select('election_id,id,approved_at').eq('level', 'lga').eq('state_code', profile.state_code!),
    adminClient.from('result_summaries').select('election_id,id').eq('level', 'state').eq('state_code', profile.state_code!),
  ]);
  if (lgaError || summaryError || stateError) {
    console.error('State readiness lookup failed', lgaError?.code ?? summaryError?.code ?? stateError?.code);
    return sendError(res, 500, 'INTERNAL_ERROR', 'Unable to load state completeness.');
  }
  const approvedByElection = new Map<string, number>();
  for (const summary of summaries ?? []) approvedByElection.set(summary.election_id, (approvedByElection.get(summary.election_id) ?? 0) + 1);
  const stateSummaryMap = new Map((stateSummaries ?? []).map((item) => [item.election_id, item]));
  const entries = (elections ?? []).map((election) => {
    const approved = approvedByElection.get(election.id) ?? 0;
    const summary = stateSummaryMap.get(election.id);
    const expectedCount = expected ?? 0;
    return { electionId: election.id, electionCode: election.election_code, electionName: election.name, expected: expectedCount, approved, missing: Math.max(expectedCount - approved, 0), ready: expectedCount > 0 && approved === expectedCount && !summary, stateApproved: !!summary };
  });
  return res.status(200).json({ data: { level: 'state', entries } });
}
