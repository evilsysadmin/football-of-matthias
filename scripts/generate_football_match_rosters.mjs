// Generate the Godot snapshot from the manager's ONLY canonical player catalog.
// Run: node scripts/generate_football_match_rosters.mjs [--check]
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
import { FOOTBALL_MANAGER_CLUBS } from '../frontend/src/footballManagerClubs.js';
import { getFootballClubRoster } from '../frontend/src/footballManagerRoster.js';
import { getFootballElevenMatchStarters } from '../frontend/src/footballElevenRoster.js';

export const FOOTBALL_MATCH_ROSTERS_URL = new URL('../games/chess-football-godot/data/scouting_rosters_v1.json', import.meta.url);

export function renderFootballMatchRosters() {
  const clubs = Object.fromEntries(FOOTBALL_MANAGER_CLUBS.map((club) => [
    club.id,
    getFootballClubRoster(club).map(({ id, name, role, age, bio, scouting }) => ({
      id, name, role, age, bio, scouting,
    })),
  ]));
  // Append-only: preserve all 54 historical scouting records. The 4-3-3
  // lists only 11 IDs plus 3 genuinely new footballers per club, avoiding
  // duplicated profiles or accidental changes to manager journal semantics.
  const eleven = Object.fromEntries(FOOTBALL_MANAGER_CLUBS.map((club) => {
    const legacyIds = new Set(getFootballClubRoster(club).map(({ id }) => id));
    const starters = getFootballElevenMatchStarters(club);
    return [club.id, {
      lineupIds: starters.map(({ id }) => id),
      extraPlayers: starters.filter(({ id }) => !legacyIds.has(id))
        .map(({ id, name, role, age, bio, scouting }) => ({ id, name, role, age, bio, scouting })),
    }];
  }));
  return JSON.stringify({ version: 1, clubs, eleven }, null, 2) + '\n';
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const content = renderFootballMatchRosters();
  if (process.argv.includes('--check')) {
    if (readFileSync(FOOTBALL_MATCH_ROSTERS_URL, 'utf8') !== content) {
      console.error('Godot scouting snapshot is stale: regenerate with node scripts/generate_football_match_rosters.mjs');
      process.exitCode = 1;
    } else {
      console.log('FOOTBALL_SCOUTING_SNAPSHOT_SYNC_OK 6 clubs / 54 manager players + 18 distinct 11v11 extras');
    }
  } else {
    writeFileSync(FOOTBALL_MATCH_ROSTERS_URL, content);
    console.log('Generated scouting_rosters_v1.json');
  }
}
