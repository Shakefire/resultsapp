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

