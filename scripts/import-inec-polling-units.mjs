#!/usr/bin/env node
import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const inputPath = resolve(process.argv[2] ?? 'data/geography/inec-polling-units.csv');
const outputPath = resolve(process.argv[3] ?? 'supabase/seed/inec-polling-units.sql');
const expected = { states: 37, lgas: 774, wards: 8809, pollingUnits: 176846 };
const sourceVersion = 'INEC-CVR-2026-08-10';
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

function parseCsv(text) {
  const rows = [];
  let row = [];
  let field = '';
  let quoted = false;
  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];
    if (quoted) {
      if (char === '"' && text[i + 1] === '"') {
        field += '"';
        i += 1;
      } else if (char === '"') {
        quoted = false;
      } else {
        field += char;
      }
    } else if (char === '"') {
      quoted = true;
    } else if (char === ',') {
      row.push(field);
      field = '';
    } else if (char === '\n') {
      row.push(field.replace(/\r$/, ''));
      rows.push(row);
      row = [];
      field = '';
    } else {
      field += char;
    }
  }
  if (quoted) throw new Error('CSV ended inside a quoted field.');
  if (field || row.length) {
    row.push(field.replace(/\r$/, ''));
    rows.push(row);
  }
  return rows;
}

function sql(value) {
  if (value === null || value === undefined) return 'null';
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  return `'${String(value).replaceAll("'", "''")}'`;
}

function insertRows(table, columns, rows, conflictColumns, updates, batchSize = 500) {
  const statements = [];
  for (let start = 0; start < rows.length; start += batchSize) {
    const batch = rows.slice(start, start + batchSize);
    const values = batch.map((row) => `  (${row.map(sql).join(', ')})`).join(',\n');
    statements.push(
      `insert into public.${table} (${columns.join(', ')}) values\n${values}\non conflict (${conflictColumns.join(', ')}) do update set\n  ${updates.map((column) => `${column} = excluded.${column}`).join(',\n  ')};`,
    );
  }
  return statements.join('\n\n');
}

const [header, ...records] = parseCsv(await readFile(inputPath, 'utf8'));
const expectedHeader = [
  'state_code', 'state_name', 'lga_code', 'lga_name', 'ward_code', 'ward_name',
  'pu_code', 'pu_name', 'pu_location', 'full_code', 'portal_id',
];
if (JSON.stringify(header) !== JSON.stringify(expectedHeader)) {
  throw new Error(`Unexpected CSV columns: ${header?.join(', ') ?? 'none'}`);
}

const states = new Map();
const lgas = new Map();
const wards = new Map();
const pollingUnits = [];
const seenPuCodes = new Set();
for (const fields of records) {
  if (fields.length !== expectedHeader.length) throw new Error(`Expected 11 columns; got ${fields.length}.`);
  const [sourceStateCode, stateName, lgaCode, lgaName, wardCode, wardName, puCode, puName, puLocation, fullCode] = fields;
  const stateCode = stateCodes.get(stateName);
  if (!stateCode || officialStateCodes.get(stateName) !== sourceStateCode || !/^\d{2}$/.test(lgaCode)
    || !/^\d{2}$/.test(wardCode) || !/^\d{3}$/.test(puCode)
    || fullCode !== `${sourceStateCode}/${lgaCode}/${wardCode}/${puCode}`
    || !lgaName || !wardName || !puName) {
    throw new Error(`Invalid or unmapped INEC row: ${fields.join(',')}`);
  }
  const lgaKey = `${stateCode}/${lgaCode}`;
  const wardKey = `${lgaKey}/${wardCode}`;
  const puKey = `${wardKey}/${puCode}`;
  states.set(stateCode, stateName);
  const lgaRecord = [lgaCode, `${sourceStateCode}/${lgaCode}`, stateCode, lgaName, stateCode === 'FC', sourceVersion];
  const wardRecord = [wardCode, `${sourceStateCode}/${lgaCode}/${wardCode}`, stateCode, lgaCode, wardName, sourceVersion];
  const previousLga = lgas.get(lgaKey);
  const previousWard = wards.get(wardKey);
  if (previousLga && previousLga[3] !== lgaName) throw new Error(`Conflicting LGA names for ${lgaKey}.`);
  if (previousWard && previousWard[4] !== wardName) throw new Error(`Conflicting ward names for ${wardKey}.`);
  if (seenPuCodes.has(puKey)) throw new Error(`Duplicate polling-unit code ${fullCode}.`);
  lgas.set(lgaKey, lgaRecord);
  wards.set(wardKey, wardRecord);
  seenPuCodes.add(puKey);
  pollingUnits.push([puCode, stateCode, lgaCode, wardCode, puName, puLocation || null, fullCode, true, sourceVersion]);
}

const uniqueNames = (entries, nameIndex, level) => {
  const names = new Set();
  for (const [key, record] of entries) {
    const parent = key.split('/').slice(0, -1).join('/');
    const nameKey = `${parent}/${record[nameIndex].trim().toLocaleUpperCase('en')}`;
    if (names.has(nameKey)) throw new Error(`Duplicate ${level} name under ${parent}: ${record[nameIndex]}`);
    names.add(nameKey);
  }
};
uniqueNames(lgas, 3, 'LGA');
uniqueNames(wards, 4, 'ward');

const counts = { states: states.size, lgas: lgas.size, wards: wards.size, pollingUnits: pollingUnits.length };
for (const [key, value] of Object.entries(expected)) {
  if (counts[key] !== value) throw new Error(`Expected ${value} ${key}; found ${counts[key]}.`);
}
console.log(`Validated ${counts.states} states, ${counts.lgas} LGAs, ${counts.wards} wards, ${counts.pollingUnits} polling units.`);

const sqlText = [
  '-- Generated from saidiadegoke/nigeria-inec-geo data/polling-units.csv.',
  '-- Dataset provenance: scraped from INEC CVR portal on 2026-08-10; verify with INEC before production use.',
  '-- This is a one-time catalogue replacement. It preserves public.states and public.user_profiles.',
  '-- The guarded deletes fail if polling units already exist or profiles are geographically scoped.',
  '-- Existing result/history rows also prevent deletion through their foreign keys, rolling back the transaction.',
  '-- Expected final counts: 37 states, 774 LGAs, 8,809 wards, 176,846 polling units.',
  'begin;',
  `alter table public.polling_units add column if not exists location text;`,
  `do $$ begin
  if exists (select 1 from public.polling_units) then
    raise exception 'Import stopped: polling_units is not empty; reconcile instead of replacing the catalogue.';
  end if;
  if exists (select 1 from public.user_profiles where lga_code is not null or ward_code is not null or polling_unit_code is not null) then
    raise exception 'Import stopped: at least one account is scoped to geography; remap assignments first.';
  end if;
end $$;`,
  'delete from public.wards;',
  'delete from public.lgas;',
  insertRows('lgas', ['code', 'source_code', 'state_code', 'name', 'is_fct_area_council', 'source_version'], [...lgas.values()],
    ['state_code', 'code'], ['source_code', 'name', 'is_fct_area_council', 'source_version']),
  insertRows('wards', ['code', 'source_code', 'state_code', 'lga_code', 'name', 'source_version'], [...wards.values()],
    ['state_code', 'lga_code', 'code'], ['source_code', 'name', 'source_version']),
  insertRows('polling_units', ['code', 'state_code', 'lga_code', 'ward_code', 'name', 'location', 'delimitation_code', 'is_active', 'source_version'], pollingUnits,
    ['state_code', 'lga_code', 'ward_code', 'code'], ['name', 'location', 'delimitation_code', 'is_active', 'source_version']),
  `do $$ begin
  if (select count(*) from public.states) <> ${expected.states}
    or (select count(*) from public.lgas) <> ${expected.lgas}
    or (select count(*) from public.wards) <> ${expected.wards}
    or (select count(*) from public.polling_units) <> ${expected.pollingUnits} then
    raise exception 'Geography row counts do not match the validated INEC snapshot; rolling back.';
  end if;
end $$;`,
  'commit;',
  `select
  (select count(*) from public.states) as states,
  (select count(*) from public.lgas) as lgas,
  (select count(*) from public.wards) as wards,
  (select count(*) from public.polling_units) as polling_units,
  (select count(*) from public.user_profiles) as profiles;`,
].join('\n\n');

await writeFile(outputPath, sqlText, 'utf8');
console.log(`Wrote ${outputPath} (${Buffer.byteLength(sqlText)} bytes).`);
