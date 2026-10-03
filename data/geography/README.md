# Nigeria geography source

The state seed is in the first Supabase migration. The LGA/Area Council and ward source bundle is staged from the Open Admin Data Nigeria Administrative Divisions dataset, licensed CC-BY-4.0 and last updated 2026-06-01.

Source repository: https://github.com/open-admin-data/nigeria-administrative-divisions

That bundle reports 37 states/FCT, 774 LGAs/Area Councils, and 8,799 wards. INEC's published 2023 election report gives 8,809 Registration Areas/Wards. The 10-record discrepancy must be reconciled against the current INEC electoral directory before treating the ward seed as production-authoritative. The importer blocks generation by default; `--allow-ward-count-mismatch` is an explicit provisional-data override.

Polling-unit records are not included in this reference bundle. They must come from an INEC-validated polling-unit dataset before provisioning polling-unit staff accounts.
