-- Migration: add can_provision_users flag to user_profiles
-- Allows Super Admin (or State Admin) to delegate account-creation power
-- to State or LGA admins.

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS can_provision_users boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.user_profiles.can_provision_users IS
  'When true, this admin can provision accounts within their geographic scope. Grantable by Super Admin or State Admin.';
