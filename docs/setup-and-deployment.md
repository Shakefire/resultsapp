# Setup and deployment handoff

This project has three separately configured parts: the Vercel API, Supabase (authentication and database), and Cloudflare R2 (file storage). Flutter is the client and is configured with the public Vercel API URL.

## 1. Backend to deploy to Vercel

Deploy the repository root as a Vercel project. One Vercel Function at `api/dispatch.ts` serves the API handlers under `server/routes/v1/`; `vercel.json` rewrites the `/api/v1/*` paths to that dispatcher. `package.json`, `package-lock.json`, and `vercel.json` are part of the deployment. There is no separate backend server process to deploy.

In the Vercel project settings, add the following environment variables for each environment you use (Development, Preview, Production):

| Variable | Value/source | Secret? |
| --- | --- | --- |
| `SUPABASE_URL` | Supabase project URL | No |
| `SUPABASE_ANON_KEY` | Supabase publishable/anon key | No; server uses it for password sign-in |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase service-role secret key | **Yes; server only** |
| `APP_ORIGINS` | Exact browser origin(s), comma-separated, e.g. `https://your-app.vercel.app` | No |
| `R2_ACCOUNT_ID` | Cloudflare account ID | Treat as private config |
| `R2_ACCESS_KEY_ID` | R2 S3 API token access key | **Yes** |
| `R2_SECRET_ACCESS_KEY` | Matching R2 S3 API token secret | **Yes** |
| `R2_BUCKET_NAME` | Private R2 bucket name (`storageapp`) | No |
| `R2_KEY_PREFIX` | Object-key prefix inside the bucket (`inecresults/`) | No; defaults to `inecresults/` |

Do not place the service-role key or R2 credentials in Flutter, source control, or a public environment file. `.env.example` contains placeholders, not working credentials.

The deployed backend URL will look like `https://<vercel-project>.vercel.app`. Flutter must be built/run with that URL:

```powershell
flutter run -d web-server --web-port 8080 --dart-define=API_BASE_URL=https://<vercel-project>.vercel.app
```

For production web builds, use the same `--dart-define` when building Flutter. Add the exact deployed Flutter web origin to Vercel `APP_ORIGINS`.

## 2. Supabase code and data to apply

Create a Supabase project, then apply the SQL migrations in this exact order:

1. `supabase/migrations/202610020001_initial_election_schema.sql` — tables, role/status types, row-level security policies, and the 36 states plus FCT.
2. `supabase/migrations/202610020002_workflow_storage.sql` — result submission, review, evidence metadata/storage grants, and workflow rules.
3. `supabase/migrations/202610020003_approval_summaries.sql` — LGA/state summary approval and aggregation.
4. `supabase/migrations/202610020004_admin_management.sql` — account/geography administration support.

Apply using the Supabase SQL Editor or Supabase CLI linked to the intended project. Keep a record of which migration versions have run; do not run them against the wrong project.

Then load a validated geography dataset. The first migration includes Nigeria's 36 states and FCT, but not LGAs, wards, or polling units. Do **not** use `supabase/seed/provisional-nigeria-geography.sql` in production until the documented 10-ward source discrepancy is reconciled. The attributed source and importer status are described in `data/geography/README.md` and `backend-setup.md`. The project currently has no polling-unit source file; load a validated polling-unit directory before provisioning Polling Unit Staff.

Create/open the election after logging in as Super Admin. Only one election may be open at a time.

## 3. Cloudflare R2 setup

Create a private R2 bucket for election evidence and voter-register PDFs. Create an S3-compatible R2 API token with only the access needed for this bucket, then put its account ID, access key ID, secret, and bucket name in Vercel's server-side environment variables above.

For Flutter Web direct uploads/downloads, configure bucket CORS for the exact web origin(s), methods `PUT` and `GET`, and request header `Content-Type`. Do not make the bucket public; the API issues short-lived object-scoped signed URLs.

### Results archive naming (planned; not implemented yet)

R2 stores evidence objects only. The API stores result figures and their approval records in Supabase, and the State Admin CSV endpoint returns an audited CSV to the client; it does not write that report into R2. Evidence and register object keys use the `inecresults/` prefix inside the `storageapp` bucket. Result exports are not yet written to R2, and objects do not yet receive descriptive custom metadata. The bucket name is `storageapp`; `inecresults/` is an object-key prefix within that bucket, not a second bucket.

For app-independent access, keep Supabase as the authoritative workflow database and write immutable exports to R2 when a state summary is approved. A readable layout should be:

```text
inecresults/results/<election-code>/state/<state-code>/summary-<summary-id>/state-summary.json
inecresults/results/<election-code>/state/<state-code>/summary-<summary-id>/state-summary.csv
inecresults/evidence/<election-code>/state/<state-code>/lga/<lga-code>/ward/<ward-code>/pu/<pu-code>/submission/<submission-id>/rev-<revision>/<evidence-type>.<ext>
inecresults/registers/<state-code>/lga/<lga-code>/ward/<ward-code>/pu/<pu-code>/<register-id>/voter-register.pdf
```

Each exported summary should include an explicit schema version, election and geography codes/names, summary ID, approval actor and UTC timestamp, source submission/summary IDs, figures, and generated-at timestamp. Add ASCII R2 custom metadata for `record-type`, `schema-version`, `election-code`, `state-code`, `lga-code`, `ward-code`, `polling-unit-code`, `summary-id` or `submission-id`, and `revision`. Keep the export immutable by using the approved summary ID in the key. The implementation must write the R2 object only after the database approval commits, and use an outbox/retry record so a temporary R2 failure cannot lose the export or roll back an approved election result. Signed URLs remain the app access path; keep the bucket private.

## 4. First Super Admin and login credentials

There is **no seeded Super Admin account or default password**. The first one is bootstrapped by an operator with trusted Supabase Auth/admin access, after migrations and geography have been applied. Create a confirmed Supabase Auth user and insert its matching `user_profiles` row using that Auth user's UUID, a unique 4–24 character User ID, `role = 'super_admin'`, no geographic scope, `is_active = true`, and `must_change_password = true`. The `user_profiles` schema and scope constraint are in migration `202610020001`.

The login screen takes the User ID and password, not a normal email. For this first account, the Supabase Auth email must follow the backend's internal mapping: `<lowercase-user-id>@accounts.smart-electoral-results.invalid`. Use a strong initial password and store it securely; there is no project default to share. Sign in once and change it. Do not create the profile with a role or scope copied from an untrusted client request.

After bootstrap, Super Admin creates other accounts in the app. The API generates each short geography-based User ID and a random temporary password, displays the temporary password once, and requires the user to change it at first login. The server-stored role and geography assignment determine access; editing the User ID does not grant privileges.

## 5. Deployment order

1. Create Supabase and R2 projects/bucket; collect the credentials listed above.
2. Apply the four database migrations in order, then load verified geography and polling-unit data.
3. Deploy this repository to Vercel and configure the Supabase, R2, and `APP_ORIGINS` variables. Redeploy after changing environment variables.
4. Bootstrap the first Super Admin directly through a trusted Supabase Auth/admin operation and matching profile row.
5. Build/run Flutter with `API_BASE_URL` set to the Vercel deployment URL; sign in and rotate the initial password.
6. Create the election and use the staging checks in `docs/release-checklist.md` before production use.

## 6. Values you need to provide or collect

- Supabase project URL, anon/publishable key, and service-role key.
- Cloudflare account ID, bucket name, and bucket-scoped R2 access key ID/secret.
- The final Flutter Web origin(s), for the Vercel `APP_ORIGINS` allowlist and R2 CORS.
- The Vercel project URL, for Flutter's `API_BASE_URL`.
- A chosen first Super Admin User ID and strong password; create them during the trusted bootstrap. No current credentials exist in this repository.
- Validated LGA/ward and polling-unit source data. The existing provisional ward seed has a documented count mismatch and is not production-ready.

The project currently expects legacy variable names `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` in Vercel. The supplied Supabase values use the newer publishable/secret-key format. The planned `@supabase/server` package supports the new key format, but it is not installed or wired into this repository yet; do not assume the pasted new names work with the current API until that migration is complete. Supabase's current `@supabase/server` guidance uses plural `SUPABASE_PUBLISHABLE_KEYS`, `SUPABASE_SECRET_KEYS`, and `SUPABASE_JWKS` for local/self-hosted configuration; the package is documented as public beta. `SUPABASE_JWKS_URL` by itself is not the variable name documented there.

Never paste service-role or R2 secret keys into chat. Enter them directly into Vercel's environment settings. See `backend-setup.md` for API routes and `docs/release-checklist.md` for access acceptance checks.
