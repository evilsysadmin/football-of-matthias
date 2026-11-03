import { describe, expect, it } from 'vitest';
import { FOOTBALL_MANAGER_CLUBS } from './footballManagerClubs.js';
import { getFootballClubRoster } from './footballManagerRoster.js';
import { getFootballElevenMatchLineup, FOOTBALL_ELEVEN_EXTRAS } from './footballElevenExtras.js';
import { renderFootballMatchRosters } from '../../scripts/generate_football_match_rosters.mjs';

describe('Football · 11v11 lineup sourcing without altering nine-player careers', () => {
  it('builds two 4-3-3 XIs, all unique, with seven authored stats and biographies', () => {
    const parsed = JSON.parse(renderFootballMatchRosters());
    expect(Object.keys(parsed.clubs)).toHaveLength(6);
    expect(Object.values(parsed.clubs).every((club) => club.length === 9)).toBe(true);
    expect(Object.keys(parsed.eleven)).toEqual(['fc-matthias', 'real-enroque']);
    const overall = new Set();
    for (const club of FOOTBALL_MANAGER_CLUBS.slice(0, 2)) {
      const nine = getFootballClubRoster(club);
      const eleven = getFootballElevenMatchLineup(club.id, nine);
      expect(eleven).toHaveLength(11);
      expect(eleven.map((player) => player.role))
        .toEqual(['POR','DEF','DEF','DEF','DEF','MED','MED','MED','EXT','EXT','DEL']);
      expect(new Set(eleven.map((player) => player.id)).size).toBe(11);
      expect(eleven.filter((player) => player.role === 'POR')).toHaveLength(1);
      expect(eleven.filter((player) => !nine.some((base) => base.id === player.id))).toHaveLength(4);
      expect(eleven.every((player) => Object.values(player.scouting).length === 7
        && Object.values(player.scouting).every((rating) => Number.isInteger(rating)
        && rating >= 1 && rating <= 99) && player.bio.length > 20)).toBe(true);
      expect(parsed.eleven[club.id]).toEqual(eleven.map(({ id, name, role, age, bio, scouting }) =>
        ({ id, name, role, age, bio, scouting })));
      for (const player of eleven) {
        expect(overall.has(player.id)).toBe(false);
        overall.add(player.id);
      }
      expect(getFootballClubRoster(club)).toEqual(nine);
      expect(parsed.clubs[club.id]).toHaveLength(9);
      expect(parsed.clubs[club.id].slice(0, 5).map((p) => p.id))
        .toEqual(nine.slice(0, 5).map((p) => p.id));
      expect(FOOTBALL_ELEVEN_EXTRAS[club.id]).toHaveLength(4);
      expect(FOOTBALL_ELEVEN_EXTRAS[club.id].every(Object.isFrozen)).toBe(true);
    }
    expect(overall.size).toBe(22);
  });
  it('rejects old nine-player rosters miscast as eleven and unsupported clubs', () => {
    const club = FOOTBALL_MANAGER_CLUBS[0], nine = getFootballClubRoster(club);
    expect(() => getFootballElevenMatchLineup(club.id, nine.slice(0, 8))).toThrow('roster');
    expect(() => getFootballElevenMatchLineup('club-inventado', nine)).toThrow('roster');
    expect(() => getFootballElevenMatchLineup(club.id, [...nine.slice(0, 8), nine[0]])).toThrow('eleven');
    expect(getFootballElevenMatchLineup(club.id, nine))
      .toEqual(getFootballElevenMatchLineup(club.id, nine));
  });
});
