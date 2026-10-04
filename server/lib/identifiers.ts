/**
 * Deterministic user-ID generation.
 * Format examples:
 *   Super Admin  → SA-HQ
 *   State Admin  → ST-LAG
 *   LGA Admin    → LG-LAG-AGE
 *   Ward Admin   → WD-LAG-AGE-W01
 *   PU Staff     → PU-LAG-AGE-W01-U001
 */

import type { AppRole } from './auth.js';

/** Two-letter Supabase state_code → 3-letter mnemonic. */
const STATE_ACRONYM: Record<string, string> = {
  AB: 'ABI', AD: 'ADM', AK: 'AKW', AN: 'ANA', BA: 'BAU', BE: 'BEN',
  BO: 'BON', BY: 'BYE', CR: 'CRS', DE: 'DEL', EB: 'EBO', ED: 'EDO',
  EK: 'EKI', EN: 'ENU', FC: 'FCT', GO: 'GOM', IM: 'IMO', JI: 'JIG',
  KD: 'KAD', KE: 'KEB', KN: 'KAN', KO: 'KOG', KT: 'KAT', KW: 'KWA',
  LA: 'LAG', NA: 'NAS', NI: 'NIG', OG: 'OGU', ON: 'OND', OS: 'OSU',
  OY: 'OYO', PL: 'PLA', RI: 'RIV', SO: 'SOK', TA: 'TAR', YO: 'YOB',
  ZA: 'ZAM',
};

/** Derive a ≤3-letter ALL-CAPS acronym from an LGA name. */
export function lgaAcronym(lgaName: string): string {
  const clean = lgaName.trim().toUpperCase().replace(/[^A-Z\s]/g, '');
  const words = clean.split(/\s+/).filter(Boolean);
  if (words.length === 1) return words[0].slice(0, 3);
  // Multi-word: first letter of each word, up to 3 chars.
  return words.map((w) => w[0]).join('').slice(0, 3);
}

export interface UserIdParams {
  role: AppRole;
  stateCode?: string | null;
  lgaCode?: string | null;
  lgaName?: string | null;
  wardCode?: string | null;
  pollingUnitCode?: string | null;
}

/**
 * Generate a deterministic user ID from geographic parameters.
 * Returns strings like PU-LAG-AGE-W01-U001.
 */
export function generateUserId(params: UserIdParams): string {
  const roleTag: Record<AppRole, string> = {
    super_admin: 'SA',
    state_admin: 'ST',
    lga_admin: 'LG',
    ward_admin: 'WD',
    polling_unit_staff: 'PU',
  };

  const tag = roleTag[params.role];

  if (params.role === 'super_admin') return `${tag}-HQ`;

  const stateAcr = STATE_ACRONYM[params.stateCode?.toUpperCase() ?? ''] ?? params.stateCode?.toUpperCase().slice(0, 3) ?? 'UNK';

  if (params.role === 'state_admin') return `${tag}-${stateAcr}`;

  const lgaAcr = lgaAcronym(params.lgaName ?? params.lgaCode ?? 'UNK');

  if (params.role === 'lga_admin') return `${tag}-${stateAcr}-${lgaAcr}`;

  const ward = `W${(params.wardCode ?? '').replace(/^0+/, '').padStart(2, '0')}`;

  if (params.role === 'ward_admin') return `${tag}-${stateAcr}-${lgaAcr}-${ward}`;

  const unit = `U${(params.pollingUnitCode ?? '').replace(/^0+/, '').padStart(3, '0')}`;
  return `${tag}-${stateAcr}-${lgaAcr}-${ward}-${unit}`;
}
