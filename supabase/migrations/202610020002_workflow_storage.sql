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
