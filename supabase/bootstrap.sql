-- ONE-TIME fresh-project bootstrap for Supabase SQL Editor.
-- Combines the current checked-in schema/workflow migrations in order.
-- Do not run on a project where these migrations have already been applied.
-- Does not load LGAs, wards, polling units, or create the first Super Admin.
-- Never put passwords or service credentials in this file.

begin;

-- >>> 202610020001_initial_election_schema.sql >>>
-- Initial schema for provisioned accounts and geographically scoped election data.
-- All workflow mutations are intended to pass through the Vercel backend.

create extension if not exists pgcrypto;

create type public.app_role as enum (
  'super_admin',
  'state_admin',
  'lga_admin',
  'ward_admin',
  'polling_unit_staff'
);

create type public.submission_status as enum (
  'draft',
  'submitted',
  'ward_verified',
  'returned',
  'lga_approved',
  'state_approved'
);

create type public.review_action as enum (
  'ward_verified',
  'returned',
  'lga_approved',
  'state_approved'
);

create table public.states (
  code text primary key check (code ~ '^[A-Z0-9]{2,3}$'),
  name text not null unique,
  is_fct boolean not null default false,
  source_version text not null default 'INEC-2023',
  created_at timestamptz not null default now()
);

insert into public.states (code, name, is_fct, source_version) values
  ('AB', 'Abia', false, 'NGA-INEC-2023'),
  ('AD', 'Adamawa', false, 'NGA-INEC-2023'),
  ('AK', 'Akwa Ibom', false, 'NGA-INEC-2023'),
  ('AN', 'Anambra', false, 'NGA-INEC-2023'),
  ('BA', 'Bauchi', false, 'NGA-INEC-2023'),
  ('BY', 'Bayelsa', false, 'NGA-INEC-2023'),
  ('BE', 'Benue', false, 'NGA-INEC-2023'),
  ('BO', 'Borno', false, 'NGA-INEC-2023'),
  ('CR', 'Cross River', false, 'NGA-INEC-2023'),
  ('DE', 'Delta', false, 'NGA-INEC-2023'),
  ('EB', 'Ebonyi', false, 'NGA-INEC-2023'),
  ('ED', 'Edo', false, 'NGA-INEC-2023'),
  ('EK', 'Ekiti', false, 'NGA-INEC-2023'),
  ('EN', 'Enugu', false, 'NGA-INEC-2023'),
  ('GO', 'Gombe', false, 'NGA-INEC-2023'),
  ('IM', 'Imo', false, 'NGA-INEC-2023'),
  ('JI', 'Jigawa', false, 'NGA-INEC-2023'),
  ('KD', 'Kaduna', false, 'NGA-INEC-2023'),
  ('KN', 'Kano', false, 'NGA-INEC-2023'),
  ('KT', 'Katsina', false, 'NGA-INEC-2023'),
  ('KE', 'Kebbi', false, 'NGA-INEC-2023'),
  ('KO', 'Kogi', false, 'NGA-INEC-2023'),
  ('KW', 'Kwara', false, 'NGA-INEC-2023'),
  ('LA', 'Lagos', false, 'NGA-INEC-2023'),
  ('NA', 'Nasarawa', false, 'NGA-INEC-2023'),
  ('NI', 'Niger', false, 'NGA-INEC-2023'),
  ('OG', 'Ogun', false, 'NGA-INEC-2023'),
  ('ON', 'Ondo', false, 'NGA-INEC-2023'),
  ('OS', 'Osun', false, 'NGA-INEC-2023'),
  ('OY', 'Oyo', false, 'NGA-INEC-2023'),
  ('PL', 'Plateau', false, 'NGA-INEC-2023'),
  ('RI', 'Rivers', false, 'NGA-INEC-2023'),
  ('SO', 'Sokoto', false, 'NGA-INEC-2023'),
  ('TA', 'Taraba', false, 'NGA-INEC-2023'),
  ('YO', 'Yobe', false, 'NGA-INEC-2023'),
  ('ZA', 'Zamfara', false, 'NGA-INEC-2023'),
  ('FC', 'Federal Capital Territory', true, 'NGA-INEC-2023')
on conflict (code) do update
set name = excluded.name,
    is_fct = excluded.is_fct,
    source_version = excluded.source_version;

create table public.lgas (
  code text not null,
  source_code text not null,
  state_code text not null references public.states(code),
  name text not null,
  is_fct_area_council boolean not null default false,
  source_version text not null default 'INEC-2023',
  created_at timestamptz not null default now(),
  primary key (state_code, code),
  unique (state_code, name)
);

create table public.wards (
  code text not null,
  source_code text not null,
  state_code text not null,
  lga_code text not null,
  name text not null,
  source_version text not null default 'INEC-2023',
  created_at timestamptz not null default now(),
  primary key (state_code, lga_code, code),
  unique (state_code, lga_code, name),
  foreign key (state_code, lga_code)
    references public.lgas(state_code, code)
);

create table public.polling_units (
  code text not null,
  state_code text not null,
  lga_code text not null,
  ward_code text not null,
  name text not null,
  location text,
  delimitation_code text,
  is_active boolean not null default true,
  source_version text not null default 'INEC-2023',
  created_at timestamptz not null default now(),
  primary key (state_code, lga_code, ward_code, code),
  foreign key (state_code, lga_code, ward_code)
    references public.wards(state_code, lga_code, code)
);

create table public.user_profiles (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  user_id text not null unique check (char_length(user_id) between 4 and 24),
  full_name text not null,
  role public.app_role not null,
  state_code text references public.states(code),
  lga_code text,
  ward_code text,
  polling_unit_code text,
  is_active boolean not null default true,
  must_change_password boolean not null default true,
  provisioned_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (state_code, lga_code)
    references public.lgas(state_code, code),
  foreign key (state_code, lga_code, ward_code)
    references public.wards(state_code, lga_code, code),
  foreign key (state_code, lga_code, ward_code, polling_unit_code)
    references public.polling_units(state_code, lga_code, ward_code, code),
  constraint user_profiles_scope_matches_role check (
    (role = 'super_admin' and state_code is null and lga_code is null and ward_code is null and polling_unit_code is null)
    or (role = 'state_admin' and state_code is not null and lga_code is null and ward_code is null and polling_unit_code is null)
    or (role = 'lga_admin' and state_code is not null and lga_code is not null and ward_code is null and polling_unit_code is null)
    or (role = 'ward_admin' and state_code is not null and lga_code is not null and ward_code is not null and polling_unit_code is null)
    or (role = 'polling_unit_staff' and state_code is not null and lga_code is not null and ward_code is not null and polling_unit_code is not null)
  )
);

create table public.elections (
  id uuid primary key default gen_random_uuid(),
  election_code text not null unique,
  name text not null,
  status text not null default 'draft' check (status in ('draft', 'open', 'closed', 'archived')),
  opens_at timestamptz,
  closes_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.result_submissions (
  id uuid primary key default gen_random_uuid(),
  election_id uuid not null references public.elections(id),
  state_code text not null,
  lga_code text not null,
  ward_code text not null,
  polling_unit_code text not null,
  submitted_by uuid not null references public.user_profiles(auth_user_id),
  status public.submission_status not null default 'draft',
  revision integer not null default 1 check (revision > 0),
  figures jsonb not null default '{}'::jsonb,
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (state_code, lga_code, ward_code, polling_unit_code)
    references public.polling_units(state_code, lga_code, ward_code, code),
  unique (election_id, state_code, lga_code, ward_code, polling_unit_code, revision)
);

create index result_submissions_scope_status_idx
  on public.result_submissions (state_code, lga_code, ward_code, polling_unit_code, status);
create index result_submissions_election_status_idx
  on public.result_submissions (election_id, status);
create unique index one_active_result_per_polling_unit_election
  on public.result_submissions (election_id, state_code, lga_code, ward_code, polling_unit_code)
  where status <> 'returned';

create table public.evidence_files (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid references public.result_submissions(id) on delete cascade,
  state_code text not null,
  lga_code text not null,
  ward_code text not null,
  polling_unit_code text not null,
  evidence_type text not null check (evidence_type in ('result_photo', 'declaration_video', 'voter_register')),
  object_key text not null unique,
  mime_type text not null,
  file_size_bytes bigint not null check (file_size_bytes > 0),
  sha256 text,
  captured_at timestamptz,
  latitude double precision,
  longitude double precision,
  accuracy_meters double precision,
  uploaded_by uuid not null references public.user_profiles(auth_user_id),
  created_at timestamptz not null default now(),
  foreign key (state_code, lga_code, ward_code, polling_unit_code)
    references public.polling_units(state_code, lga_code, ward_code, code),
  check (latitude is null or latitude between -90 and 90),
  check (longitude is null or longitude between -180 and 180),
  check (accuracy_meters is null or accuracy_meters >= 0)
);

create table public.review_decisions (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.result_submissions(id),
  actor_id uuid not null references public.user_profiles(auth_user_id),
  action public.review_action not null,
  reason text,
  prior_status public.submission_status not null,
  new_status public.submission_status not null,
  created_at timestamptz not null default now(),
  check (action <> 'returned' or length(trim(coalesce(reason, ''))) > 0)
);

create table public.audit_events (
  id bigint generated always as identity primary key,
  actor_id uuid references public.user_profiles(auth_user_id),
  event_type text not null,
  entity_type text not null,
  entity_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.can_access_location(
  target_state text,
  target_lga text default null,
  target_ward text default null,
  target_polling_unit text default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.user_profiles p
    where p.auth_user_id = (select auth.uid())
      and p.is_active
      and (
        p.role = 'super_admin'
        or (p.role = 'state_admin' and p.state_code = target_state)
        or (p.role = 'lga_admin' and p.state_code = target_state and p.lga_code = target_lga)
        or (p.role = 'ward_admin' and p.state_code = target_state and p.lga_code = target_lga and p.ward_code = target_ward)
        or (p.role = 'polling_unit_staff' and p.state_code = target_state and p.lga_code = target_lga and p.ward_code = target_ward and p.polling_unit_code = target_polling_unit)
      )
  )
$$;

create or replace function public.is_active_super_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.user_profiles p
    where p.auth_user_id = (select auth.uid())
      and p.is_active
      and p.role = 'super_admin'
  )
$$;

alter table public.states enable row level security;
alter table public.lgas enable row level security;
alter table public.wards enable row level security;
alter table public.polling_units enable row level security;
alter table public.user_profiles enable row level security;
alter table public.elections enable row level security;
alter table public.result_submissions enable row level security;
alter table public.evidence_files enable row level security;
alter table public.review_decisions enable row level security;
alter table public.audit_events enable row level security;

grant select on public.states, public.lgas, public.wards, public.polling_units to authenticated;
grant select on public.user_profiles, public.elections, public.result_submissions, public.evidence_files, public.review_decisions to authenticated;

create policy "authenticated users read geography" on public.states for select to authenticated using (true);
create policy "authenticated users read LGAs" on public.lgas for select to authenticated using (true);
create policy "authenticated users read wards" on public.wards for select to authenticated using (true);
create policy "authenticated users read polling units" on public.polling_units for select to authenticated using (true);

create policy "users read own profile; super admins read all" on public.user_profiles
  for select to authenticated using (
    auth_user_id = (select auth.uid())
    or public.is_active_super_admin()
  );
create policy "authenticated users read elections" on public.elections for select to authenticated using (true);
create policy "read submissions in assigned scope" on public.result_submissions
  for select to authenticated using (public.can_access_location(state_code, lga_code, ward_code, polling_unit_code));
create policy "read evidence in assigned scope" on public.evidence_files
  for select to authenticated using (public.can_access_location(state_code, lga_code, ward_code, polling_unit_code));
create policy "read decisions for accessible submissions" on public.review_decisions
  for select to authenticated using (
    exists (
      select 1 from public.result_submissions s
      where s.id = submission_id
        and public.can_access_location(s.state_code, s.lga_code, s.ward_code, s.polling_unit_code)
    )
  );

-- Clients have no write grants on workflow or identity tables. Vercel performs
-- authorized mutations with its server-only service key and writes audit events.
revoke insert, update, delete on public.states, public.lgas, public.wards, public.polling_units,
  public.user_profiles, public.elections, public.result_submissions, public.evidence_files,
  public.review_decisions, public.audit_events from anon, authenticated;
revoke all on function public.can_access_location(text, text, text, text) from public, anon;
grant execute on function public.can_access_location(text, text, text, text) to authenticated;
revoke all on function public.is_active_super_admin() from public, anon;
grant execute on function public.is_active_super_admin() to authenticated;


-- <<< 202610020001_initial_election_schema.sql <<<

-- >>> 202610020002_workflow_storage.sql >>>
-- Short-lived grants bind every R2 upload to the authenticated account,
-- assigned polling unit, content type, size limit, and intended workflow.
create table public.evidence_upload_grants (
  object_key text primary key,
  auth_user_id uuid not null references public.user_profiles(auth_user_id) on delete cascade,
  purpose text not null check (purpose in ('result_photo', 'declaration_video', 'voter_register')),
  content_type text not null,
  max_bytes bigint not null check (max_bytes > 0),
  state_code text not null,
  lga_code text not null,
  ward_code text not null,
  polling_unit_code text not null,
  election_id uuid references public.elections(id),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  foreign key (state_code, lga_code, ward_code, polling_unit_code)
    references public.polling_units(state_code, lga_code, ward_code, code)
);

create index evidence_upload_grants_expiry_idx on public.evidence_upload_grants(expires_at);
alter table public.evidence_upload_grants enable row level security;
revoke all on public.evidence_upload_grants from anon, authenticated;
grant all on public.evidence_upload_grants to service_role;

alter table public.evidence_files add column file_name text;

-- A submission is visible to its assigned staff member, as well as the
-- geographically scoped reviewers protected by can_access_location().
create policy "staff read own polling unit submissions" on public.result_submissions
  for select to authenticated using (
    exists (
      select 1 from public.user_profiles p
      where p.auth_user_id = (select auth.uid())
        and p.is_active
        and p.role = 'polling_unit_staff'
        and p.state_code = result_submissions.state_code
        and p.lga_code = result_submissions.lga_code
        and p.ward_code = result_submissions.ward_code
        and p.polling_unit_code = result_submissions.polling_unit_code
    )
  );

create policy "staff read own polling unit evidence" on public.evidence_files
  for select to authenticated using (
    exists (
      select 1 from public.user_profiles p
      where p.auth_user_id = (select auth.uid())
        and p.is_active
        and p.role = 'polling_unit_staff'
        and p.state_code = evidence_files.state_code
        and p.lga_code = evidence_files.lga_code
        and p.ward_code = evidence_files.ward_code
        and p.polling_unit_code = evidence_files.polling_unit_code
    )
  );

-- <<< 202610020002_workflow_storage.sql <<<

-- >>> 202610020003_approval_summaries.sql >>>
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

-- <<< 202610020003_approval_summaries.sql <<<

-- >>> 202610020004_admin_management.sql >>>
alter table public.states add column if not exists is_active boolean not null default true;
alter table public.lgas add column if not exists is_active boolean not null default true;
alter table public.wards add column if not exists is_active boolean not null default true;

revoke insert, update, delete on public.states, public.lgas, public.wards, public.polling_units from anon, authenticated;

create index if not exists user_profiles_admin_scope_idx
  on public.user_profiles(role, state_code, lga_code, ward_code, polling_unit_code, is_active);
create index if not exists geography_active_scope_idx
  on public.polling_units(state_code, lga_code, ward_code, is_active);

comment on column public.states.is_active is 'Super Admin managed availability flag; historical records remain intact.';
comment on column public.lgas.is_active is 'Super Admin managed availability flag; historical records remain intact.';
comment on column public.wards.is_active is 'Super Admin managed availability flag; historical records remain intact.';

-- <<< 202610020004_admin_management.sql <<<

commit;
