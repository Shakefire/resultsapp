#!/usr/bin/env node
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const apply = process.argv.includes('--apply');
const envPath = resolve('.env');
const csvPath = resolve('data/geography/inec-polling-units.csv');
const sourceVersion = 'INEC-CVR-2026-08-10';
const expected = { states: 37, lgas: 774, wards: 8809, pollingUnits: 176846, profiles: 1 };
const stateCodes = new Map([
  ['ABIA', 'AB'], ['ADAMAWA', 'AD'], ['AKWA IBOM', 'AK'], ['ANAMBRA', 'AN'],
  ['BAUCHI', 'BA'], ['BAYELSA', 'BY'], ['BENUE', 'BE'], ['BORNO', 'BO'],
  ['CROSS RIVER', 'CR'], ['DELTA', 'DE'], ['EBONYI', 'EB'], ['EDO', 'ED'],
  ['EKITI', 'EK'], ['ENUGU', 'EN'], ['FCT', 'FC'], ['GOMBE', 'GO'],
  ['IMO', 'IM'], ['JIGAWA', 'JI'], ['KADUNA', 'KD'], ['KANO', 'KN'],
  ['KATSINA', 'KT'], ['KEBBI', 'KE'], ['KOGI', 'KO'], ['KWARA', 'KW'],
  ['LAGOS', 'LA'], ['NASARAWA', 'NA'], ['NIGER', 'NI'], ['OGUN', 'OG'],
  ['ONDO', 'ON'], ['OSUN', 'OS'], ['OYO', 'OY'], ['PLATEAU', 'PL'],
  ['RIVERS', 'RI'], ['SOKOTO', 'SO'], ['TARABA', 'TA'], ['YOBE', 'YO'],
  ['ZAMFARA', 'ZA'],
]);
const officialStateCodes = new Map([
  ['ABIA', '01'], ['ADAMAWA', '02'], ['AKWA IBOM', '03'], ['ANAMBRA', '04'],
  ['BAUCHI', '05'], ['BAYELSA', '06'], ['BENUE', '07'], ['BORNO', '08'],
  ['CROSS RIVER', '09'], ['DELTA', '10'], ['EBONYI', '11'], ['EDO', '12'],
  ['EKITI', '13'], ['ENUGU', '14'], ['GOMBE', '15'], ['IMO', '16'],
  ['JIGAWA', '17'], ['KADUNA', '18'], ['KANO', '19'], ['KATSINA', '20'],
  ['KEBBI', '21'], ['KOGI', '22'], ['KWARA', '23'], ['LAGOS', '24'],
  ['NASARAWA', '25'], ['NIGER', '26'], ['OGUN', '27'], ['ONDO', '28'],
  ['OSUN', '29'], ['OYO', '30'], ['PLATEAU', '31'], ['RIVERS', '32'],
  ['SOKOTO', '33'], ['TARABA', '34'], ['YOBE', '35'], ['ZAMFARA', '36'],
  ['FCT', '37'],
]);

function parseEnv(contents) {
  const result = new Map();
  for (const line of contents.split(/\r?\n/)) {
    const match = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$/);
    if (!match || line.trimStart().startsWith('#')) continue;
    let value = match[2].trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    result.set(match[1], value);
  }
  return result;
}

function parseCsv(text) {
  const rows = [];
  let row = [];
  let field = '';
  let quoted = false;
  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];
    if (quoted) {
      if (char === '"' && text[i + 1] === '"') { field += '"'; i += 1; }
      else if (char === '"') quoted = false;
      else field += char;
    } else if (char === '"') quoted = true;
    else if (char === ',') { row.push(field); field = ''; }
    else if (char === '\n') { row.push(field.replace(/\r$/, '')); rows.push(row); row = []; field = ''; }
    else field += char;
  }
  if (quoted) throw new Error('CSV ended inside a quoted field.');
  if (field || row.length) { row.push(field.replace(/\r$/, '')); rows.push(row); }
  return rows;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function parseDataset(text) {
  const rows = parseCsv(text);
  const header = rows.shift();
  const columns = ['state_code', 'state_name', 'lga_code', 'lga_name', 'ward_code', 'ward_name', 'pu_code', 'pu_name', 'pu_location', 'full_code', 'portal_id'];
  assert(JSON.stringify(header) === JSON.stringify(columns), 'Unexpected polling-unit CSV columns.');
  const states = new Set();
  const lgas = new Map();
  const wards = new Map();
  const pollingUnits = [];
  const seenUnits = new Set();
  for (const row of rows) {
    assert(row.length === 11, `Expected 11 CSV fields; received ${row.length}.`);
    const [sourceStateCode, stateName, lgaCode, lgaName, wardCode, wardName, puCode, puName, puLocation, fullCode] = row;
    const stateCode = stateCodes.get(stateName);
    assert(stateCode && officialStateCodes.get(stateName) === sourceStateCode, `State code/name mismatch: ${stateName}/${sourceStateCode}.`);
    assert(/^\d{2}$/.test(lgaCode) && /^\d{2}$/.test(wardCode) && /^\d{3}$/.test(puCode), `Invalid geography code in ${fullCode}.`);
    assert(fullCode === `${sourceStateCode}/${lgaCode}/${wardCode}/${puCode}`, `Invalid full_code ${fullCode}.`);
    assert(lgaName && wardName && puName, `Missing geography name in ${fullCode}.`);
    const lgaKey = `${stateCode}/${lgaCode}`;
    const wardKey = `${lgaKey}/${wardCode}`;
    const puKey = `${wardKey}/${puCode}`;
    const lgaRow = [lgaCode, `${sourceStateCode}/${lgaCode}`, stateCode, lgaName, stateCode === 'FC', sourceVersion];
    const wardRow = [wardCode, `${sourceStateCode}/${lgaCode}/${wardCode}`, stateCode, lgaCode, wardName, sourceVersion];
    const oldLga = lgas.get(lgaKey);
    const oldWard = wards.get(wardKey);
    assert(!oldLga || oldLga[3] === lgaName, `Conflicting LGA names for ${lgaKey}.`);
    assert(!oldWard || oldWard[4] === wardName, `Conflicting ward names for ${wardKey}.`);
    assert(!seenUnits.has(puKey), `Duplicate polling-unit code ${fullCode}.`);
    states.add(stateCode);
    lgas.set(lgaKey, lgaRow);
    wards.set(wardKey, wardRow);
    seenUnits.add(puKey);
    pollingUnits.push({
      code: puCode,
      state_code: stateCode,
      lga_code: lgaCode,
      ward_code: wardCode,
      name: puName,
      delimitation_code: fullCode,
      is_active: true,
      source_version: sourceVersion,
      ...(puLocation ? { location: puLocation } : {}),
    });
  }
  const counts = { states: states.size, lgas: lgas.size, wards: wards.size, pollingUnits: pollingUnits.length };
  for (const [key, value] of Object.entries(expected)) {
    if (key === 'profiles') continue;
    assert(counts[key] === value, `Expected ${value} ${key}; found ${counts[key]}.`);
  }
  return { lgas: [...lgas.values()], wards: [...wards.values()], pollingUnits, counts };
}

const config = parseEnv(await readFile(envPath, 'utf8'));
const baseUrl = config.get('SUPABASE_URL')?.replace(/\/$/, '');
const serviceKey = config.get('SUPABASE_SERVICE_ROLE_KEY') ?? config.get('SUPABASE_SECRET_KEY');
assert(baseUrl && serviceKey, 'Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (or SUPABASE_SECRET_KEY) in .env.');
assert(new URL(baseUrl).hostname === 'ujoztoevtedbxudtifbl.supabase.co', 'SUPABASE_URL is not the expected project; stopping before any database writes.');

const dataset = parseDataset(await readFile(csvPath, 'utf8'));
console.log(`Local source validated: ${dataset.counts.states} states, ${dataset.counts.lgas} LGAs, ${dataset.counts.wards} wards, ${dataset.counts.pollingUnits} polling units.`);

const headers = { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, 'Content-Type': 'application/json' };
async function request(path, options = {}) {
  const response = await fetch(`${baseUrl}/rest/v1/${path}`, { ...options, headers: { ...headers, ...options.headers } });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Supabase request failed (${response.status}): ${body.slice(0, 1000)}`);
  }
  return response;
}

async function count(table, filters = '') {
  const response = await request(`${table}?select=*&limit=1${filters}`, { headers: { Prefer: 'count=exact' } });
  const range = response.headers.get('content-range');
  const total = Number(range?.split('/').at(-1));
  assert(Number.isFinite(total), `Could not read exact row count for ${table}.`);
  return total;
}

async function json(path) {
  return (await request(path)).json();
}

const before = {
  states: await count('states'),
  lgas: await count('lgas'),
  wards: await count('wards'),
  pollingUnits: await count('polling_units'),
  profiles: await count('user_profiles'),
  lgaSummaries: await count('result_summaries', '&level=eq.lga'),
};
const profiles = await json('user_profiles?select=role,lga_code,ward_code,polling_unit_code&limit=1000');
assert(profiles.length === before.profiles, 'Profile list exceeded the safe preflight limit.');
assert(profiles.every((profile) => profile.lga_code === null && profile.ward_code === null && profile.polling_unit_code === null), 'Geographically scoped accounts exist; stopping before catalogue replacement.');
assert(before.states === expected.states && before.profiles === expected.profiles, `Unexpected state/profile counts: ${JSON.stringify(before)}.`);
assert(before.lgaSummaries === 0, 'LGA result summaries exist; stopping before replacing their geography references.');

const targetLgas = await count('lgas', `&source_version=eq.${sourceVersion}`);
const targetWards = await count('wards', `&source_version=eq.${sourceVersion}`);
if (before.pollingUnits > 0) {
  const targetPollingUnits = await count('polling_units', `&source_version=eq.${sourceVersion}`);
  assert(before.pollingUnits === targetPollingUnits, 'Polling-unit rows from another source exist; refusing to overwrite them.');
  assert(before.lgas === expected.lgas && targetLgas === expected.lgas && before.wards === expected.wards && targetWards === expected.wards,
    'A partial or mismatched catalogue exists alongside polling units; refusing to modify it.');
} else {
  assert(
    (before.lgas === expected.lgas && before.wards === 8799)
      || (before.lgas === 0 && before.wards === 0)
      || (before.lgas === expected.lgas && before.wards === expected.wards && targetLgas === expected.lgas && targetWards === expected.wards),
    `Unexpected current catalogue counts: ${JSON.stringify(before)}.`,
  );
}

if (!apply) {
  console.log(`Preflight passed. Current Supabase counts: ${JSON.stringify(before)}. Run again with --apply to replace provisional LGA/ward rows and import polling units.`);
  process.exit(0);
}

const targetCatalogReady = before.lgas === expected.lgas && before.wards === expected.wards
  && targetLgas === expected.lgas && targetWards === expected.wards;
if (before.pollingUnits === 0 && !targetCatalogReady) {
  if (before.wards > 0) {
    await request('wards?code=not.is.null', { method: 'DELETE', headers: { Prefer: 'return=minimal' } });
  }
  if (before.lgas > 0) {
    await request('lgas?code=not.is.null', { method: 'DELETE', headers: { Prefer: 'return=minimal' } });
  }
}

const batchSize = 500;
async function upsert(table, rows, conflict, label) {
  let done = 0;
  for (let start = 0; start < rows.length; start += batchSize) {
    const batch = rows.slice(start, start + batchSize);
    await request(`${table}?on_conflict=${encodeURIComponent(conflict)}`, {
      method: 'POST',
      headers: { Prefer: 'resolution=merge-duplicates,return=minimal' },
      body: JSON.stringify(batch),
    });
    done += batch.length;
    if (done === rows.length || done % 10000 === 0) console.log(`${label}: ${done}/${rows.length}`);
  }
}

await upsert('lgas', dataset.lgas.map(([code, source_code, state_code, name, is_fct_area_council, source_version]) => ({
  code, source_code, state_code, name, is_fct_area_council, source_version,
})), 'state_code,code', 'LGAs');
await upsert('wards', dataset.wards.map(([code, source_code, state_code, lga_code, name, source_version]) => ({
  code, source_code, state_code, lga_code, name, source_version,
})), 'state_code,lga_code,code', 'Wards');

let includeLocation = true;
try {
  await request('polling_units?select=location&limit=0');
} catch {
  includeLocation = false;
}
if (!includeLocation) console.log('Database has no location column; importing all supported fields. Run the location migration later to retain pu_location values.');
const unitRows = includeLocation ? dataset.pollingUnits : dataset.pollingUnits.map(({ location, ...row }) => row);
await upsert('polling_units', unitRows, 'state_code,lga_code,ward_code,code', 'Polling units');

const after = {
  states: await count('states'),
  lgas: await count('lgas'),
  wards: await count('wards'),
  pollingUnits: await count('polling_units'),
  profiles: await count('user_profiles'),
};
assert(after.states === expected.states && after.lgas === expected.lgas && after.wards === expected.wards
  && after.pollingUnits === expected.pollingUnits && after.profiles === expected.profiles,
`Post-import counts failed validation: ${JSON.stringify(after)}.`);
console.log(`Import complete and verified: ${JSON.stringify(after)}.`);
