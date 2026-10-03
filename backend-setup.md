# Backend setup

For a separated deployment handoff covering Vercel, Supabase, R2, initial Super Admin setup, and the required configuration values, see [docs/setup-and-deployment.md](docs/setup-and-deployment.md).

The single Vercel Function in `api/dispatch.ts` dispatches the API routes implemented in `server/routes/v1/`; `vercel.json` rewrites `/api/v1/*` to it to stay within the Hobby plan's function limit. Deploy this repository as a Vercel project and configure the Supabase environment variables from `.env.example` in Vercel's server-side environment settings. `SUPABASE_SERVICE_ROLE_KEY` must never be included in Flutter build configuration. Register future endpoints in the dispatcher rather than adding function files under `api/`.

Apply SQL migrations from `supabase/migrations/` to the Supabase project before invoking the API. The state migration seeds all 36 states and FCT. To produce the LGA/ward seed from the attributed source bundle, run:

For a **fresh Supabase project only**, the four migrations are also combined into [supabase/bootstrap.sql](supabase/bootstrap.sql) for a single SQL Editor run. Do not run that combined file after applying the migrations individually. It does not contain the provisional geography seed or a Super Admin account.

```powershell
node scripts/import-nigeria-geography.mjs data/geography/nigeria-open-admin-data-hierarchy.json supabase/seed/nigeria-geography.sql
```

The importer verifies 37 state/FCT records and 774 LGAs/Area Councils and blocks a ward-count mismatch. INEC reports 8,809 Registration Areas/Wards for the 2023 election; the current community dataset contains 8,799. The checked-in `supabase/seed/provisional-nigeria-geography.sql` was generated with an explicit provisional override and must not be applied to production before the 10-ward difference is reconciled. See `data/geography/README.md` for attribution and status. Polling-unit data is not in that source bundle.

Provision the first Super Admin through a trusted Supabase Auth/admin operation and insert the matching `user_profiles` row; after that, `POST /api/v1/admin/users` provisions subordinate accounts and returns the temporary password once.

Apply all workflow migrations in filename order, including the storage-grant and approved-summary migrations. Configure `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, and `R2_BUCKET_NAME` only in Vercel server environment variables. Keep the R2 bucket private. Configure bucket CORS for the exact Flutter Web origin(s), `PUT` and `GET` methods, and the `Content-Type` request header. Mobile direct uploads do not send media through Vercel. Create/open the active election from the Super Admin dashboard; only one election can be open at once.

Flutter builds must receive `API_BASE_URL` at compile time, for example:

```powershell
flutter run --dart-define=API_BASE_URL=https://your-vercel-project.vercel.app
```

For Flutter web, set `APP_ORIGINS` to the exact web origin(s), comma-separated. Native mobile requests without an `Origin` header are allowed. The current API endpoints are:

- `POST /api/v1/auth/login` — User ID and password sign-in.
- `PATCH /api/v1/auth/password` — authenticated password update; verifies the temporary/current password before first-login rotation.
- `GET /api/v1/me` — verified provisioned profile and assigned role/location.
- `GET /api/v1/geography?level=...` — Super Admin-only location choices (`states`, `lgas`, `wards`, or `polling_units`). Child levels require their parent codes.
- `POST /api/v1/admin/users` — Super Admin account provisioning.
- `GET /api/v1/admin/accounts` and `PATCH /api/v1/admin/accounts` — Super Admin account directory, activation status, role/location assignment, and temporary-password reset.
- `GET /api/v1/admin/geography`, `POST /api/v1/admin/geography`, and `PATCH /api/v1/admin/geography` — Super Admin location directory management. Records are deactivated rather than deleted so historical results remain intact.
- `GET /api/v1/workflow/review-queue` — Ward, LGA, or State Admin's server-scoped review queue.
- `POST /api/v1/workflow/decisions` — records a role-checked decision with reason/history/audit.
- `GET /api/v1/workflow/my-records` — Polling Unit Staff's records and register in their assigned unit.
- `POST /api/v1/workflow/submissions` — commits a result only after scoped, authorized R2 evidence has been verified.
- `POST /api/v1/evidence/upload-url` and `GET /api/v1/evidence/download-url` — short-lived, object-scoped R2 links.
- `POST /api/v1/evidence/voter-register` — commits a secured voter-register PDF reference.
- `GET /api/v1/workflow/summary-readiness` and `POST /api/v1/workflow/summary-approvals` — completeness and atomic LGA/State total approval.
- `GET /api/v1/reports/state-summary` — reportable elections for a State Admin; add `?electionId=...` to generate audited CSV content.

The Flutter dashboard exposes administration only to an initialized Super Admin. Account creation assigns one of the four subordinate roles and its required location scope. Account deactivation, reactivation, and password resets are audited; temporary passwords are returned only for display after reset. Geography can be created, renamed, activated, and deactivated, but records are never hard-deleted. Server routes independently enforce these permissions. The first Super Admin remains a trusted bootstrap operation. Polling Unit Staff accounts cannot be provisioned until the polling-unit directory is loaded.

Ward Admins can verify or return each submission with a reason. LGA and State Admins approve complete aggregate summaries; incomplete active polling units or missing LGA summaries block approval. The State Admin can save an audited CSV export containing the approved summary and its source polling-unit results. A signed PDF requires an official template and signing process that are not currently supplied.

The initial migration seeds the 36 states and FCT. LGA, ward, and polling-unit records must be loaded from a validated, versioned INEC source before accounts at those scopes can be provisioned.

See [docs/release-checklist.md](docs/release-checklist.md) for role-by-role access acceptance checks and release configuration steps. They must be executed on staging; they are not automatically passed by hiding unauthorized controls in Flutter.
