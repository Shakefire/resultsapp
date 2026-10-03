# Authorization and results workflow

This document is the implementation contract for the role hierarchy and results flow. It is based on the supplied flowcharts and the agreed role responsibilities. The screenshots are cropped, so open policy decisions are called out explicitly.

## Architecture ownership

- Flutter presents screens and captures user input; it is not an authorization authority.
- Supabase Auth authenticates provisioned users.
- The Vercel backend validates the signed-in identity, account status, role, assigned geography, and requested workflow transition for each operation.
- Supabase Postgres stores identities' application profiles, geography, submissions, decisions, file metadata, and audit events. Row Level Security provides a second enforcement layer for data access.
- Cloudflare R2 stores evidence files. The backend grants short-lived access to individual objects; file bytes do not pass through Vercel Functions.
- A user's role and geography come from their server-managed account and assignment records. Neither is inferred from a User ID.

## Roles and scope

| Role | Data scope | Permitted workflow actions |
| --- | --- | --- |
| Polling Unit Staff | Their assigned polling unit | Create and submit that unit's result; view its submission, evidence, status, and any return reason; correct and resubmit a returned result; upload/view authorized voter-register files for that unit. |
| Ward Admin | Their assigned ward and its polling units | Review submitted polling-unit results; verify a result or return it with a reason. |
| LGA Admin | Their assigned LGA and its wards | Review ward results, monitor ward completion, validate and approve the LGA total. |
| State Admin | Their assigned state and its LGAs | Monitor LGA progress, review and approve the state summary, export authorized official reports. |
| Super Admin | System-wide account and geography administration | Provision/deactivate accounts, assign roles and locations, initiate credential resets, manage the state/LGA/ward/polling-unit directory. No result approval privilege is implied by Super Admin status. |

Access must be checked for every backend operation and scoped query. Hiding a button or choosing a dashboard in Flutter is not sufficient authorization.

## Proposed submission lifecycle

```text
DRAFT
  └─ Polling Unit Staff submits ─> SUBMITTED
       └─ Ward Admin reviews ─────> WARD_VERIFIED
       │                            └─ visible in LGA review queue
       └─ Ward Admin returns ─────> RETURNED
                                    └─ Staff corrects and resubmits ─> SUBMITTED

WARD_VERIFIED results
  └─ LGA Admin validates/approves the LGA total ─> LGA_APPROVED
       └─ visible to State Admin

LGA_APPROVED totals
  └─ State Admin approves state summary ─────────> STATE_APPROVED
       └─ eligible for official report export
```

The authoritative status belongs to the backend/database. Every transition records the actor, role, timestamp, previous status, next status, and any decision reason. A return requires a non-empty reason. The client must not set approval status directly when submitting figures or media.

## Submission and evidence rules

1. Staff can create a submission only for the polling unit assigned to their account, for an election that accepts submissions.
2. The submission includes figures, result-sheet photo, declaration video, capture timestamp, and location metadata as required by the election configuration.
3. Evidence uploads go directly to private R2 objects using short-lived, object-scoped URLs. The backend verifies the object metadata before accepting the submission.
4. Supabase stores object keys and evidence metadata, not public permanent URLs or the media bytes.
5. A submission is not considered received until the backend commits the submission and returns its durable identifier and status.
6. A returned result keeps its prior decision history. Staff correct the submission and resubmit; prior review events are not overwritten.
7. Approvals are append-only events. Current status may be represented on the submission for efficient reads, but decision history remains authoritative for audit.

## Aggregation and visibility

- A Ward Admin sees only results in the assigned ward.
- An LGA Admin sees only ward results in the assigned LGA. The LGA total is calculated from the ward results included under an agreed completeness/dispute policy.
- A State Admin sees only LGA results in the assigned state. The state summary follows an agreed completeness/dispute policy.
- A downstream level must not treat an upstream result as approved until the corresponding approval transition has committed.
- Reports include election identity, geographic scope, included result versions/statuses, generation time, and generating account. The export action is audited.

## Account provisioning and User IDs

- Public self-registration is removed for operational accounts. Super Admin provisions each user and assigns a role and geography.
- Users authenticate with the issued User ID and password. On successful authentication, the backend returns the assigned profile and scope.
- A User ID may encode compact geographic codes for identification, but it never grants permission. Super Admin assignment changes regenerate the ID to match the new scope; the account profile remains the authorization source.
- User ID format, code catalog, and temporary-password/first-login reset behavior are defined in the account-provisioning stage.

## Implemented approval and completeness policy

- A Ward Admin verifies a submitted polling-unit revision or returns it with a non-empty reason. A return is the system's representation of a disputed result; there is no separate dispute status. The staff member sees the return reason and can create the next revision. Earlier revisions and review events remain stored.
- An LGA total is the sum of the latest Ward-verified revision for every active polling unit in that LGA for the election. Missing, submitted, returned, or otherwise unverified units block approval. An LGA with no active polling units cannot be approved. Vote totals are summed by party key; registered voters, accredited voters, rejected ballots, valid votes, and total votes cast are also summed.
- A State summary is the sum of approved LGA totals. Every LGA in the loaded state directory must have an approved total; any missing LGA blocks State approval.
- Summary approval, source status changes, decision history, and audit event are committed in one Postgres function transaction. The summary preserves its source submission/summary IDs and the calculated figures.
- State CSV includes the approved summary, each source polling-unit result, scope codes, revision, figures, approval time and approver User ID, report generation time, and generating User ID. The export audit event identifies the immutable summary and a hash of its source submission IDs.

## Implementation checkpoint

The code includes a real polling-unit repository, server-scoped submission/history APIs, direct R2 uploads using short-lived signed URLs, secured voter-register upload/access, Ward decisions, atomic completeness-gated LGA and State summary approval, and audited CSV output. These require the migrations to be applied, R2 credentials and bucket CORS configured, an open election, and an authoritative active polling-unit directory. The checked-in geography still lacks polling-unit records and its ward count differs from INEC's 2023 figure; without validated polling-unit data, submissions cannot be assigned and the LGA completeness gate intentionally remains closed. A signed PDF is not implemented because no official template or signing requirements are supplied.
