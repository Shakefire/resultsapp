create table public.result_summaries (
  id uuid primary key default gen_random_uuid(),
  election_id uuid not null references public.elections(id),
  level text not null check (level in ('lga', 'state')),
  state_code text not null references public.states(code),
  lga_code text,
  figures jsonb not null,
  source_submission_ids uuid[] not null default '{}',
  source_summary_ids uuid[] not null default '{}',
  status text not null default 'approved' check (status = 'approved'),
  approved_by uuid not null references public.user_profiles(auth_user_id),
  approved_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  foreign key (state_code, lga_code) references public.lgas(state_code, code),
  check ((level = 'lga' and lga_code is not null) or (level = 'state' and lga_code is null))
);
create unique index one_open_election_at_a_time on public.elections ((status)) where status = 'open';
create unique index one_lga_summary_per_election on public.result_summaries(election_id, state_code, lga_code) where level = 'lga';
create unique index one_state_summary_per_election on public.result_summaries(election_id, state_code) where level = 'state';
create index result_summaries_state_status_idx on public.result_summaries(state_code, election_id, level, status);

alter table public.result_summaries enable row level security;
grant select on public.result_summaries to authenticated;
grant all on public.result_summaries to service_role;
revoke insert, update, delete on public.result_summaries from anon, authenticated;
create policy "read approved summaries in assigned geography" on public.result_summaries
  for select to authenticated using (
    (level = 'lga' and public.can_access_location(state_code, lga_code, null, null))
    or (level = 'state' and public.can_access_location(state_code, null, null, null))
  );

create or replace function public.approve_lga_summary(p_actor uuid, p_election uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor public.user_profiles%rowtype;
  expected_count integer;
  verified_count integer;
  returned_count integer;
  submission_ids uuid[];
  totals jsonb;
  summary_id uuid;
  approved_at_value timestamptz := now();
begin
  select * into actor from public.user_profiles where auth_user_id = p_actor and is_active;
  if actor.auth_user_id is null or actor.role <> 'lga_admin' or actor.must_change_password or actor.state_code is null or actor.lga_code is null then
    raise exception 'Only an initialized LGA Admin can approve an LGA summary';
  end if;
  select count(*) into expected_count from public.polling_units p
    where p.state_code = actor.state_code and p.lga_code = actor.lga_code and p.is_active;
  select count(*) into verified_count from public.result_submissions s
    join public.polling_units p on p.state_code = s.state_code and p.lga_code = s.lga_code and p.ward_code = s.ward_code and p.code = s.polling_unit_code and p.is_active
    where s.election_id = p_election and s.state_code = actor.state_code and s.lga_code = actor.lga_code and s.status = 'ward_verified'
      and not exists (select 1 from public.result_submissions newer where newer.election_id = s.election_id and newer.state_code = s.state_code and newer.lga_code = s.lga_code and newer.ward_code = s.ward_code and newer.polling_unit_code = s.polling_unit_code and newer.revision > s.revision);
  select count(*) into returned_count from public.result_submissions s
    join public.polling_units p on p.state_code = s.state_code and p.lga_code = s.lga_code and p.ward_code = s.ward_code and p.code = s.polling_unit_code and p.is_active
    where s.election_id = p_election and s.state_code = actor.state_code and s.lga_code = actor.lga_code and s.status = 'returned'
      and not exists (select 1 from public.result_submissions newer where newer.election_id = s.election_id and newer.state_code = s.state_code and newer.lga_code = s.lga_code and newer.ward_code = s.ward_code and newer.polling_unit_code = s.polling_unit_code and newer.revision > s.revision);
  if expected_count = 0 then
    return jsonb_build_object('ready', false, 'reason', 'No active polling units are loaded for this LGA.', 'expected', 0, 'verified', 0, 'returned', returned_count, 'missing', 0);
  end if;
  if verified_count <> expected_count or returned_count > 0 then
    return jsonb_build_object('ready', false, 'reason', 'Every active polling unit must have a Ward-verified result; missing and returned results block approval.', 'expected', expected_count, 'verified', verified_count, 'returned', returned_count, 'missing', greatest(expected_count - verified_count, 0));
  end if;

  select array_agg(s.id order by s.ward_code, s.polling_unit_code) into submission_ids
    from public.result_submissions s join public.polling_units p on p.state_code = s.state_code and p.lga_code = s.lga_code and p.ward_code = s.ward_code and p.code = s.polling_unit_code and p.is_active
      where s.election_id = p_election and s.state_code = actor.state_code
      and s.lga_code = actor.lga_code and s.status = 'ward_verified'
      and not exists (select 1 from public.result_submissions newer where newer.election_id = s.election_id and newer.state_code = s.state_code and newer.lga_code = s.lga_code and newer.ward_code = s.ward_code and newer.polling_unit_code = s.polling_unit_code and newer.revision > s.revision);
  select jsonb_build_object(
    'registeredVoters', (select coalesce(sum((s.figures->>'registeredVoters')::bigint), 0) from public.result_submissions s where s.id = any(submission_ids)),
    'accreditedVoters', (select coalesce(sum((s.figures->>'accreditedVoters')::bigint), 0) from public.result_submissions s where s.id = any(submission_ids)),
    'rejectedVotes', (select coalesce(sum((s.figures->>'rejectedVotes')::bigint), 0) from public.result_submissions s where s.id = any(submission_ids)),
    'partyVotes', coalesce((select jsonb_object_agg(party, votes) from (
      select p.key as party, sum(p.value::bigint) as votes
      from public.result_submissions s cross join lateral jsonb_each_text(s.figures->'partyVotes') p
      where s.id = any(submission_ids) group by p.key
    ) totals_by_party), '{}'::jsonb)
  ) into totals;
  totals := totals || jsonb_build_object(
    'totalValidVotes', (select coalesce(sum(value::bigint), 0) from jsonb_each_text(totals->'partyVotes')),
    'totalVotesCast', (totals->>'rejectedVotes')::bigint + (select coalesce(sum(value::bigint), 0) from jsonb_each_text(totals->'partyVotes'))
  );
  insert into public.result_summaries(election_id, level, state_code, lga_code, figures, source_submission_ids, approved_by, approved_at)
    values (p_election, 'lga', actor.state_code, actor.lga_code, totals, submission_ids, p_actor, approved_at_value)
    returning id into summary_id;
  update public.result_submissions set status = 'lga_approved', updated_at = approved_at_value where id = any(submission_ids) and status = 'ward_verified';
  insert into public.review_decisions(submission_id, actor_id, action, prior_status, new_status)
    select unnest(submission_ids), p_actor, 'lga_approved', 'ward_verified', 'lga_approved';
  insert into public.audit_events(actor_id, event_type, entity_type, entity_id, details)
    values (p_actor, 'summary.lga_approved', 'result_summary', summary_id::text,
      jsonb_build_object('electionId', p_election, 'stateCode', actor.state_code, 'lgaCode', actor.lga_code, 'sourceCount', cardinality(submission_ids), 'figures', totals));
  return jsonb_build_object('ready', true, 'summaryId', summary_id, 'figures', totals, 'sourceCount', cardinality(submission_ids), 'approvedAt', approved_at_value);
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
  select count(*) into expected_count from public.lgas l where l.state_code = actor.state_code;
  select count(*) into approved_count from public.result_summaries s where s.election_id = p_election and s.state_code = actor.state_code and s.level = 'lga' and s.status = 'approved';
  if expected_count = 0 or approved_count <> expected_count then
    return jsonb_build_object('ready', false, 'reason', 'Every LGA in the state must have an approved total; missing LGA summaries block state approval.', 'expected', expected_count, 'approved', approved_count, 'missing', greatest(expected_count - approved_count, 0));
  end if;
  select array_agg(s.id order by s.lga_code) into lga_summary_ids from public.result_summaries s
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

revoke all on function public.approve_lga_summary(uuid, uuid) from public, anon, authenticated;
revoke all on function public.approve_state_summary(uuid, uuid) from public, anon, authenticated;
grant execute on function public.approve_lga_summary(uuid, uuid) to service_role;
grant execute on function public.approve_state_summary(uuid, uuid) to service_role;
