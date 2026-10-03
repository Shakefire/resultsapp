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
