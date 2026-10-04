# Nigeria geography source

The state seed is in the first Supabase migration. The LGA/Area Council and ward source bundle is staged from the Open Admin Data Nigeria Administrative Divisions dataset, licensed CC-BY-4.0 and last updated 2026-06-01.

Source repository: https://github.com/open-admin-data/nigeria-administrative-divisions

That bundle reports 37 states/FCT, 774 LGAs/Area Councils, and 8,799 wards. INEC's published 2023 election report gives 8,809 Registration Areas/Wards. The 10-record discrepancy must be reconciled against the current INEC electoral directory before treating the ward seed as production-authoritative. The importer blocks generation by default; `--allow-ward-count-mismatch` is an explicit provisional-data override.

Polling-unit records are not included in this reference bundle. They must come from an INEC-validated polling-unit dataset before provisioning polling-unit staff accounts.

## INEC polling-unit snapshot

`inec-polling-units.csv` is a third-party snapshot scraped from the INEC CVR portal on 2026-08-10. It contains 176,846 polling units and their INEC state/LGA/ward/unit codes, names, and location labels. INEC's 2023 General Election Report independently publishes the 176,846 total. The snapshot is not an official bulk download and should be reconciled with INEC before production use.

The Supabase API importer reads `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` from the local `.env`, performs safety checks, then writes in 500-row batches. Run it with `--apply` to replace the provisional catalogue and load polling units:

```sh
node scripts/import-inec-polling-units-to-supabase.mjs --apply
```

The importer preserves the existing state rows and profiles, replaces the provisional LGA/ward catalogue with the snapshot's 774 LGAs and 8,809 wards, and upserts the 176,846 polling units. It stops if unrelated polling-unit data, geographically scoped profiles, or LGA summaries exist. The SQL generator `scripts/import-inec-polling-units.mjs` remains available to create `supabase/seed/inec-polling-units.sql` for direct database clients; the 20 MB SQL file is too large for Supabase SQL Editor.
