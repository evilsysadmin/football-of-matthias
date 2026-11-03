import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { FOOTBALL_MANAGER_CLUBS } from './footballManagerClubs.js';
import { getFootballClubRoster } from './footballManagerRoster.js';
import { getFootballElevenMatchStarters, FOOTBALL_ELEVEN_ROLES } from './footballElevenRoster.js';
import { FOOTBALL_MATCH_ROSTERS_URL, renderFootballMatchRosters } from '../../scripts/generate_football_match_rosters.mjs';

describe('Football · manager/Godot roster authority', () => {
  it('keeps the exported match catalog byte-for-byte synchronized with all 54 player profiles', () => {
    const exported = readFileSync(FOOTBALL_MATCH_ROSTERS_URL, 'utf8');
    expect(exported).toBe(renderFootballMatchRosters());
    const data = JSON.parse(exported);
    expect(data.version).toBe(1);
    expect(Object.keys(data.clubs)).toEqual(FOOTBALL_MANAGER_CLUBS.map(({ id }) => id));
    expect(Object.values(data.clubs).flat()).toHaveLength(54);
    expect(Object.values(data.eleven).flatMap(({ extraPlayers }) => extraPlayers)).toHaveLength(18);
    expect(Object.keys(data.eleven)).toEqual(FOOTBALL_MANAGER_CLUBS.map(({ id }) => id));
    for (const club of FOOTBALL_MANAGER_CLUBS) {
      expect(data.clubs[club.id]).toEqual(getFootballClubRoster(club).map(
        ({ id, name, role, age, bio, scouting }) => ({ id, name, role, age, bio, scouting }),
      ));
      const starters = getFootballElevenMatchStarters(club);
      expect(starters.map(({ role }) => role)).toEqual(FOOTBALL_ELEVEN_ROLES);
      expect(new Set(starters.map(({ id }) => id)).size).toBe(11);
      expect(data.eleven[club.id].lineupIds).toEqual(starters.map(({ id }) => id));
      expect(data.eleven[club.id].extraPlayers).toEqual(starters.slice(0).filter(
        ({ id }) => !new Set(data.clubs[club.id].map((p) => p.id)).has(id),
      ).map(({ id, name, role, age, bio, scouting }) => ({ id, name, role, age, bio, scouting })));
    }
    // The live Godot quick match currently fields only these two canonical
    // clubs; the other four remain available for future team selection.
    expect(data.clubs['fc-matthias'][4].scouting.pace).toBe(90);
    expect(data.clubs['fc-matthias'][3].scouting.stamina).toBe(92);
    expect(data.clubs['real-enroque'][0].role).toBe('POR');
  });
});
