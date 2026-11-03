// Generate the Godot snapshot from the manager's ONLY canonical player catalog.
// Run: node scripts/generate_football_match_rosters.mjs [--check]
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
import { FOOTBALL_MANAGER_CLUBS } from '../frontend/src/footballManagerClubs.js';
import { getFootballClubRoster } from '../frontend/src/footballManagerRoster.js';
import { getFootballElevenMatchLineup, FOOTBALL_ELEVEN_EXTRAS } from '../frontend/src/footballElevenExtras.js';

export const FOOTBALL_MATCH_ROSTERS_URL = new URL('../games/chess-football-godot/data/scouting_rosters_v1.json', import.meta.url);

export function renderFootballMatchRosters() {
  const clubs = Object.fromEntries(FOOTBALL_MANAGER_CLUBS.map((club) => [
    club.id,
    getFootballClubRoster(club).map(({ id, name, role, age, bio, scouting }) => ({
      id, name, role, age, bio, scouting,
    })),
  ]));
  // Additive 11v11 quick-match lineups only: no change to any of the
  // 54 manager identities or its saved deterministic five-a-side journal.
  const eleven = Object.fromEntries(FOOTBALL_MANAGER_CLUBS
    .filter((club) => Object.hasOwn(FOOTBALL_ELEVEN_EXTRAS, club.id))
    .map((club) => [club.id, getFootballElevenMatchLineup(
      club.id, getFootballClubRoster(club),
    ).map(({ id, name, role, age, bio, scouting }) => ({
      id, name, role, age, bio, scouting,
    }))]));
  return JSON.stringify({ version: 1, clubs, eleven }, null, 2) + '\n';
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const content = renderFootballMatchRosters();
  if (process.argv.includes('--check')) {
    if (readFileSync(FOOTBALL_MATCH_ROSTERS_URL, 'utf8') !== content) {
      console.error('Godot scouting snapshot is stale: regenerate with node scripts/generate_football_match_rosters.mjs');
      process.exitCode = 1;
    } else {
      console.log('FOOTBALL_SCOUTING_SNAPSHOT_SYNC_OK 6 clubs / 54 manager players + 2 future elevens');
    }
  } else {
    writeFileSync(FOOTBALL_MATCH_ROSTERS_URL, content);
    console.log('Generated scouting_rosters_v1.json');
  }
}
