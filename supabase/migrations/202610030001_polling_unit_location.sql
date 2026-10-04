alter table public.polling_units
  add column if not exists location text;
