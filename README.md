# Smart Electoral Results API

This repository contains the Vercel TypeScript API, Supabase schema/migrations, geography import source, and deployment documentation for Smart Electoral Results.

## Deploy

Import this repository into Vercel with the repository root as the project root. Configure the server-side variables listed in `.env.example` using your project credentials. Never commit `.env` files or expose the Supabase service key or R2 credentials to the Flutter client.

Apply the four Supabase migrations in order, or for a fresh project only, use `supabase/bootstrap.sql` once in the Supabase SQL Editor. Read `docs/setup-and-deployment.md` before loading geography or provisioning the first Super Admin. The provisional ward seed is not production-ready.

The Flutter client is intentionally maintained outside this backend-only repository. It must be built with `API_BASE_URL` set to the deployed Vercel URL.
