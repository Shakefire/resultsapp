-- Scoped, current-election metrics for operational review dashboards.
-- All calculations run in Postgres so the API does not fetch unbounded result rows.
create index if not exists result_submissions_dashboard_latest_idx
  on public.result_submissions (election_id, state_code, lga_code, ward_code, polling_unit_code, revision desc);

create or replace function public.get_admin_summary_readiness(p_actor uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor public.user_profiles%rowtype;
  election_row record;
  expected_count integer;
  verified_count integer;
  returned_count integer;
  approved_count integer;
  summary_exists boolean;
  summary_approved_at timestamptz;
  entries jsonb := '[]'::jsonb;
begin
  select * into actor from public.user_profiles where auth_user_id = p_actor and is_active;
  if actor.auth_user_id is null or actor.must_change_password or actor.role not in ('lga_admin', 'state_admin') then
    raise exception 'An initialized LGA or State Admin account is required';
  end if;

  for election_row in
    select e.id, e.election_code, e.name from public.elections e order by e.created_at desc
  loop
    if actor.role = 'lga_admin' then
      select count(*) into expected_count from public.polling_units p
        where p.state_code = actor.state_code and p.lga_code = actor.lga_code and p.is_active;
      select exists (
        select 1 from public.result_summaries s where s.election_id = election_row.id
          and s.level = 'lga' and s.state_code = actor.state_code and s.lga_code = actor.lga_code
      ), (select s.approved_at from public.result_summaries s where s.election_id = election_row.id
        and s.level = 'lga' and s.state_code = actor.state_code and s.lga_code = actor.lga_code)
        into summary_exists, summary_approved_at;
      select count(*) filter (where latest.status in ('ward_verified', 'lga_approved', 'state_approved')),
             count(*) filter (where latest.status = 'returned')
        into verified_count, returned_count
        from (
          select distinct on (s.state_code, s.lga_code, s.ward_code, s.polling_unit_code)
            s.status
          from public.result_submissions s
          join public.polling_units p on p.state_code = s.state_code and p.lga_code = s.lga_code
            and p.ward_code = s.ward_code and p.code = s.polling_unit_code and p.is_active
          where s.election_id = election_row.id and s.state_code = actor.state_code and s.lga_code = actor.lga_code
          order by s.state_code, s.lga_code, s.ward_code, s.polling_unit_code, s.revision desc
        ) latest;
      if summary_exists then verified_count := expected_count; end if;
      entries := entries || jsonb_build_array(jsonb_build_object(
        'electionId', election_row.id, 'electionCode', election_row.election_code, 'electionName', election_row.name,
        'expected', expected_count, 'verified', verified_count, 'returned', returned_count,
        'missing', greatest(expected_count - verified_count, 0),
        'ready', expected_count > 0 and verified_count = expected_count and returned_count = 0 and not summary_exists,
        'approved', summary_exists, 'isApproved', summary_exists, 'approvedAt', summary_approved_at
      ));
    else
      select count(*) into expected_count from public.lgas l
        where l.state_code = actor.state_code and l.is_active;
      select count(*) into approved_count from public.result_summaries s
        join public.lgas l on l.state_code = s.state_code and l.code = s.lga_code and l.is_active
        where s.election_id = election_row.id and s.state_code = actor.state_code and s.level = 'lga' and s.status = 'approved';
      select exists (
        select 1 from public.result_summaries s where s.election_id = election_row.id
          and s.level = 'state' and s.state_code = actor.state_code
      ), (select s.approved_at from public.result_summaries s where s.election_id = election_row.id
        and s.level = 'state' and s.state_code = actor.state_code)
        into summary_exists, summary_approved_at;
      entries := entries || jsonb_build_array(jsonb_build_object(
        'electionId', election_row.id, 'electionCode', election_row.election_code, 'electionName', election_row.name,
        'expected', expected_count, 'approved', approved_count,
        'missing', greatest(expected_count - approved_count, 0),
        'ready', expected_count > 0 and approved_count = expected_count and not summary_exists,
        'stateApproved', summary_exists, 'isApproved', summary_exists, 'approvedAt', summary_approved_at
      ));
    end if;
  end loop;

  return jsonb_build_object('level', actor.role, 'entries', entries);
end;
$$;

create or replace function public.get_review_dashboard_overview(p_actor uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor public.user_profiles%rowtype;
  active_election public.elections%rowtype;
  lga_summary public.result_summaries%rowtype;
  state_summary public.result_summaries%rowtype;
  has_election boolean := false;
  expected_units integer := 0;
  expected_lgas integer := 0;
  recorded_count integer := 0;
  submitted_count integer := 0;
  returned_count integer := 0;
  ward_verified_count integer := 0;
  lga_approved_units integer := 0;
  state_approved_units integer := 0;
  approved_locations integer := 0;
  expected_locations integer := 0;
  awaiting_count integer := 0;
  missing_count integer := 0;
  approved_complete boolean := false;
  approved_at_value timestamptz;
  party_votes jsonb := '{}'::jsonb;
  party_source text := 'No approved results yet';
begin
  select * into actor from public.user_profiles where auth_user_id = p_actor and is_active;
  if actor.auth_user_id is null or actor.must_change_password or actor.role not in ('ward_admin', 'lga_admin', 'state_admin') then
    raise exception 'An initialized Ward, LGA, or State Admin account is required';
  end if;

  select * into active_election from public.elections e
    where e.status = 'open' and (e.opens_at is null or e.opens_at <= now()) and (e.closes_at is null or e.closes_at >= now())
    order by e.created_at desc limit 1;
  has_election := found;

  select count(*) into expected_units from public.polling_units p
    where p.state_code = actor.state_code and p.is_active
      and (actor.role = 'state_admin' or p.lga_code = actor.lga_code)
      and (actor.role <> 'ward_admin' or p.ward_code = actor.ward_code);
  select count(*) into expected_lgas from public.lgas l
    where l.state_code = actor.state_code and l.is_active;

  if has_election then
    select count(*),
      count(*) filter (where latest.status = 'submitted'),
      count(*) filter (where latest.status = 'returned'),
      count(*) filter (where latest.status = 'ward_verified'),
      count(*) filter (where latest.status = 'lga_approved'),
      count(*) filter (where latest.status = 'state_approved')
      into recorded_count, submitted_count, returned_count, ward_verified_count, lga_approved_units, state_approved_units
      from (
        select distinct on (s.state_code, s.lga_code, s.ward_code, s.polling_unit_code) s.status
        from public.result_submissions s
        join public.polling_units p on p.state_code = s.state_code and p.lga_code = s.lga_code
          and p.ward_code = s.ward_code and p.code = s.polling_unit_code and p.is_active
        where s.election_id = active_election.id and s.state_code = actor.state_code
          and (actor.role = 'state_admin' or s.lga_code = actor.lga_code)
          and (actor.role <> 'ward_admin' or s.ward_code = actor.ward_code)
        order by s.state_code, s.lga_code, s.ward_code, s.polling_unit_code, s.revision desc
      ) latest;
  end if;

  if actor.role = 'ward_admin' then
    expected_locations := expected_units;
    approved_locations := ward_verified_count + lga_approved_units + state_approved_units;
    awaiting_count := submitted_count;
    missing_count := greatest(expected_units - recorded_count, 0);
    approved_complete := expected_units > 0 and approved_locations = expected_units;
    party_source := 'Ward-verified results';
    if has_election then
      with latest as (
        select distinct on (s.state_code, s.lga_code, s.ward_code, s.polling_unit_code) s.status, s.figures
        from public.result_submissions s
        join public.polling_units p on p.state_code = s.state_code and p.lga_code = s.lga_code
          and p.ward_code = s.ward_code and p.code = s.polling_unit_code and p.is_active
        where s.election_id = active_election.id and s.state_code = actor.state_code
          and s.lga_code = actor.lga_code and s.ward_code = actor.ward_code
        order by s.state_code, s.lga_code, s.ward_code, s.polling_unit_code, s.revision desc
      ), totals as (
        select p.key as party, sum(p.value::bigint) as votes from latest r
        cross join lateral jsonb_each_text(coalesce(r.figures->'partyVotes', '{}'::jsonb)) p
        where r.status in ('ward_verified', 'lga_approved', 'state_approved') group by p.key
      ) select coalesce(jsonb_object_agg(party, votes), '{}'::jsonb) into party_votes from totals;
    end if;
  elsif actor.role = 'lga_admin' then
    expected_locations := expected_units;
    select * into lga_summary from public.result_summaries s
      where s.election_id = active_election.id and s.level = 'lga'
        and s.state_code = actor.state_code and s.lga_code = actor.lga_code;
    if found then
      approved_locations := expected_units;
      approved_complete := true;
      approved_at_value := lga_summary.approved_at;
      party_votes := coalesce(lga_summary.figures->'partyVotes', '{}'::jsonb);
      party_source := 'Approved LGA total';
    else
      approved_locations := lga_approved_units + state_approved_units;
      awaiting_count := ward_verified_count;
      missing_count := greatest(expected_units - recorded_count, 0);
      party_source := 'Ward-verified live figures';
      if has_election then
        with latest as (
          select distinct on (s.state_code, s.lga_code, s.ward_code, s.polling_unit_code) s.status, s.figures
          from public.result_submissions s
          join public.polling_units p on p.state_code = s.state_code and p.lga_code = s.lga_code
            and p.ward_code = s.ward_code and p.code = s.polling_unit_code and p.is_active
          where s.election_id = active_election.id and s.state_code = actor.state_code and s.lga_code = actor.lga_code
          order by s.state_code, s.lga_code, s.ward_code, s.polling_unit_code, s.revision desc
        ), totals as (
          select p.key as party, sum(p.value::bigint) as votes from latest r
          cross join lateral jsonb_each_text(coalesce(r.figures->'partyVotes', '{}'::jsonb)) p
          where r.status in ('ward_verified', 'lga_approved', 'state_approved') group by p.key
        ) select coalesce(jsonb_object_agg(party, votes), '{}'::jsonb) into party_votes from totals;
      end if;
    end if;
  else
    expected_locations := expected_lgas;
    select count(*) into approved_locations from public.result_summaries s
      join public.lgas l on l.state_code = s.state_code and l.code = s.lga_code and l.is_active
      where s.election_id = active_election.id and s.level = 'lga' and s.state_code = actor.state_code;
    awaiting_count := greatest(expected_lgas - approved_locations, 0);
    missing_count := awaiting_count;
    select * into state_summary from public.result_summaries s
      where s.election_id = active_election.id and s.level = 'state' and s.state_code = actor.state_code;
    if found then
      approved_complete := true;
      approved_at_value := state_summary.approved_at;
      party_votes := coalesce(state_summary.figures->'partyVotes', '{}'::jsonb);
      party_source := 'Approved State summary';
    else
      party_source := 'LGA-approved live totals';
      if has_election then
        with totals as (
          select p.key as party, sum(p.value::bigint) as votes
          from public.result_summaries s
          join public.lgas l on l.state_code = s.state_code and l.code = s.lga_code and l.is_active
          cross join lateral jsonb_each_text(coalesce(s.figures->'partyVotes', '{}'::jsonb)) p
          where s.election_id = active_election.id and s.level = 'lga'
            and s.state_code = actor.state_code group by p.key
        ) select coalesce(jsonb_object_agg(party, votes), '{}'::jsonb) into party_votes from totals;
      end if;
    end if;
  end if;

  if not has_election then
    expected_locations := 0;
    approved_locations := 0;
    awaiting_count := 0;
    missing_count := 0;
    party_votes := '{}'::jsonb;
    party_source := 'No ongoing election';
  end if;

  return jsonb_build_object(
    'role', actor.role,
    'ongoingElectionCount', case when has_election then 1 else 0 end,
    'election', case when has_election then jsonb_build_object(
      'id', active_election.id, 'electionCode', active_election.election_code,
      'name', active_election.name, 'opensAt', active_election.opens_at, 'closesAt', active_election.closes_at
    ) else null end,
    'metrics', jsonb_build_object(
      'expected', expected_locations, 'approved', approved_locations,
      'awaiting', awaiting_count, 'returned', returned_count,
      'missing', missing_count, 'approvalComplete', approved_complete,
      'approvedAt', approved_at_value,
      'submittedUnits', submitted_count, 'wardVerifiedUnits', ward_verified_count,
      'lgaApprovedUnits', lga_approved_units, 'stateApprovedUnits', state_approved_units
    ),
    'partyVotes', party_votes,
    'partyCount', jsonb_object_length(party_votes),
    'partySource', party_source
  );
end;
$$;

create or replace function public.approve_state_summary(p_actor uuid, p_election uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor public.user_profiles%rowtype;
  expected_count integer;
  approved_count integer;
  lga_summary_ids uuid[];
  source_ids uuid[];
  totals jsonb;
  summary_id uuid;
  approved_at_value timestamptz := now();
begin
  select * into actor from public.user_profiles where auth_user_id = p_actor and is_active;
  if actor.auth_user_id is null or actor.role <> 'state_admin' or actor.must_change_password or actor.state_code is null then
    raise exception 'Only an initialized State Admin can approve a state summary';
  end if;
  select count(*) into expected_count from public.lgas l where l.state_code = actor.state_code and l.is_active;
  select count(*) into approved_count from public.result_summaries s
    join public.lgas l on l.state_code = s.state_code and l.code = s.lga_code and l.is_active
    where s.election_id = p_election and s.state_code = actor.state_code and s.level = 'lga' and s.status = 'approved';
  if expected_count = 0 or approved_count <> expected_count then
    return jsonb_build_object('ready', false, 'reason', 'Every active LGA in the state must have an approved total; missing LGA summaries block state approval.', 'expected', expected_count, 'approved', approved_count, 'missing', greatest(expected_count - approved_count, 0));
  end if;

  select array_agg(s.id order by s.lga_code) into lga_summary_ids from public.result_summaries s
    join public.lgas l on l.state_code = s.state_code and l.code = s.lga_code and l.is_active
    where s.election_id = p_election and s.state_code = actor.state_code and s.level = 'lga' and s.status = 'approved';
  select array_agg(distinct source.submission_id) into source_ids
    from public.result_summaries s cross join lateral unnest(s.source_submission_ids) as source(submission_id)
    where s.id = any(lga_summary_ids);
  select jsonb_build_object(
    'registeredVoters', coalesce(sum((s.figures->>'registeredVoters')::bigint), 0),
    'accreditedVoters', coalesce(sum((s.figures->>'accreditedVoters')::bigint), 0),
    'rejectedVotes', coalesce(sum((s.figures->>'rejectedVotes')::bigint), 0),
    'partyVotes', coalesce((select jsonb_object_agg(party, votes) from (
      select p.key as party, sum(p.value::bigint) as votes
      from public.result_summaries x cross join lateral jsonb_each_text(x.figures->'partyVotes') p
      where x.id = any(lga_summary_ids) group by p.key
    ) totals_by_party), '{}'::jsonb)
  ) into totals from public.result_summaries s where s.id = any(lga_summary_ids);
  totals := totals || jsonb_build_object(
    'totalValidVotes', (select coalesce(sum(value::bigint), 0) from jsonb_each_text(totals->'partyVotes')),
    'totalVotesCast', (totals->>'rejectedVotes')::bigint + (select coalesce(sum(value::bigint), 0) from jsonb_each_text(totals->'partyVotes'))
  );
  insert into public.result_summaries(election_id, level, state_code, lga_code, figures, source_submission_ids, source_summary_ids, approved_by, approved_at)
    values (p_election, 'state', actor.state_code, null, totals, source_ids, lga_summary_ids, p_actor, approved_at_value)
    returning id into summary_id;
  update public.result_submissions set status = 'state_approved', updated_at = approved_at_value where id = any(source_ids) and status = 'lga_approved';
  insert into public.review_decisions(submission_id, actor_id, action, prior_status, new_status)
    select unnest(source_ids), p_actor, 'state_approved', 'lga_approved', 'state_approved';
  insert into public.audit_events(actor_id, event_type, entity_type, entity_id, details)
    values (p_actor, 'summary.state_approved', 'result_summary', summary_id::text,
      jsonb_build_object('electionId', p_election, 'stateCode', actor.state_code, 'lgaCount', cardinality(lga_summary_ids), 'sourceCount', cardinality(source_ids), 'figures', totals));
  return jsonb_build_object('ready', true, 'summaryId', summary_id, 'figures', totals, 'lgaCount', cardinality(lga_summary_ids), 'sourceCount', cardinality(source_ids), 'approvedAt', approved_at_value);
end;
$$;

revoke all on function public.get_admin_summary_readiness(uuid) from public, anon, authenticated;
revoke all on function public.get_review_dashboard_overview(uuid) from public, anon, authenticated;
revoke all on function public.approve_state_summary(uuid, uuid) from public, anon, authenticated;
grant execute on function public.get_admin_summary_readiness(uuid) to service_role;
grant execute on function public.get_review_dashboard_overview(uuid) to service_role;
grant execute on function public.approve_state_summary(uuid, uuid) to service_role;
