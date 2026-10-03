# Release checklist: role isolation and administration

This checklist is the acceptance plan for release review. Execute it against a staging deployment with seeded test accounts and sanitized evidence. A result marked “pass” must be supported by the API response and audit row, not only by hidden UI controls.

## Role-by-role acceptance checks

| Role | Allowed actions to confirm | Denials / isolation to confirm |
| --- | --- | --- |
| Polling Unit Staff | Sign in with provisioned credentials; view assigned-unit submissions and voter register; upload evidence; submit a result; correct a returned result. | Request another polling unit's records, upload grant, or evidence URL; submit a different unit code; approve/review a result; submit when election is closed; submit mock GPS or accuracy worse than 25 m. Each must be denied by the API. |
| Ward Admin | List and open only submissions in assigned ward; view signed evidence; verify a submitted result; return with a reason. | Change ward code in the app/request; decide another ward's submission; return without reason; repeat a decision against a changed status. Each must be denied or conflict. |
| LGA Admin | View results only in assigned LGA; inspect completeness; approve the LGA total only when every active polling unit has a latest Ward-verified revision. | Approve with missing, returned, submitted, or unverified units; access another LGA; use per-submission decision API to bypass aggregation. Each must be denied. |
| State Admin | Monitor only assigned state; approve only when every loaded LGA has an approved total; export a state-approved CSV and confirm summary/source IDs, approver, generator, timestamps, and audit record. | Access another state; approve with a missing LGA; export an unapproved result; alter election or source IDs in the request. Each must be denied. |
| Super Admin | Provision accounts with valid role/location; view accounts; deactivate/reactivate subordinate accounts; issue a temporary password; add/rename/activate/deactivate geography at every level. | Provision or assign a role outside the valid location hierarchy; act on self or another Super Admin; deactivate a parent with active child locations/accounts; call management APIs as any non-Super Admin. Each must be denied. |

## Shared authorization checks

- Change a User ID in the UI/request and confirm the server still uses the bearer token's profile for role and geography.
- Call each privileged endpoint with no token, expired token, inactive profile, and a temporary-password account. Expect authentication/authorization failure.
- Call decision endpoints with an invalid transition and stale status. Expect `409`/`400`; confirm no status, decision, or summary was partially written.
- Request an evidence download URL for a key from another polling unit/ward/LGA/state. Expect `403`; confirm valid short-lived links expire.
- Attempt direct Supabase `INSERT`, `UPDATE`, and `DELETE` on geography tables using an authenticated non-Super Admin token. Confirm the database denies each mutation.
- Check that account role, location, password reset, active status, geography, result decisions, summary approvals, and exports have actor/time audit evidence.
- Check that changing or deactivating directory records does not delete historical submissions or summaries.

## Deployment configuration

- Apply migrations `202610020001` through `202610020004` in order.
- Set `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `APP_ORIGINS`, `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET_NAME`, and `R2_KEY_PREFIX` as server-side Vercel environment variables. Do not put the service key or R2 credentials in Flutter configuration.
- Keep R2 private; configure exact web-origin CORS for `PUT` and `GET` and `Content-Type`. Confirm mobile clients upload bytes directly to R2.
- Build Flutter with `API_BASE_URL` pointing to the deployed Vercel project. Confirm production excludes the preview-only mock adapters from app initialization.
- Bootstrap one Super Admin through the trusted process. Sign in and rotate its temporary password.
- Load a validated, versioned state/LGA/ward/polling-unit directory. Reconcile known source discrepancies before activating polling-unit assignments.
- Create the election and ensure its open/close window is correct. Confirm only one election is open.
- Run all acceptance checks above in staging, review API/server logs and audit rows, and record the release approver and tested build SHA before production rollout.

## Current execution status

The acceptance cases are documented but require deployed Supabase, Vercel, R2, provisioned test accounts, and a validated polling-unit directory to execute end-to-end. Do not treat this checklist as a passed production security certification.

Local checks on 2026-10-03: `flutter test` passed (65 tests); `npm run typecheck` passed; `npm audit --omit=dev` found zero production dependency advisories. `flutter analyze` reported no errors, but exited non-zero because of 20 informational lint findings. Full `npm audit` reports 11 development-tree advisories (1 moderate, 10 high) through the Vercel/TypeScript toolchain; npm’s suggested fix forces a breaking `@vercel/node` downgrade, so that change was not applied. Review and resolve this toolchain advisory before production release.
