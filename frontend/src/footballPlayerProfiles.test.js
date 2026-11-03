import { describe, expect, it } from 'vitest';
import { FOOTBALL_MANAGER_CLUBS } from './footballManagerClubs.js';
import { getFootballClubRoster, getDefaultFootballLineup, evaluateFootballLineup } from './footballManagerRoster.js';
import { FOOTBALL_PLAYER_PROFILES, FOOTBALL_SCOUTING_ATTRIBUTES, footballPlayerOverall } from './footballPlayerProfiles.js';
import { getDevelopedFootballRoster } from './footballManagerDevelopment.js';
import { createFootballCareer, replayFootballCareer, playFootballCareerRound } from './footballManagerCareer.js';

describe('Football · 54 fictional scouting profiles', () => {
  it('has nine unique, authored identities per club, with real individual stats and bios', () => {
    const ids = new Set();
    const names = new Set();
    const statVectors = new Set();
    for (const club of FOOTBALL_MANAGER_CLUBS) {
      expect(FOOTBALL_PLAYER_PROFILES[club.id]).toHaveLength(9);
      const roster = getFootballClubRoster(club);
      expect(roster).toHaveLength(9);
      expect(roster.map(({ role }) => role)).toEqual(['POR','DEF','MED','MED','DEL','POR','DEF','MED','DEL']);
      for (const [index, player] of roster.entries()) {
        expect(player.id).toBe(`${club.id}-${player.role.toLowerCase()}-${index < 5 ? [1,1,1,2,1][index] : [2,2,3,2][index-5]}`);
        expect(ids.has(player.id)).toBe(false);
        expect(names.has(player.name)).toBe(false);
        ids.add(player.id); names.add(player.name);
        expect(player.name).toBe(FOOTBALL_PLAYER_PROFILES[club.id][index].name);
        expect(player.age).toBeGreaterThanOrEqual(18);
        expect(player.bio.length).toBeGreaterThan(35);
        expect(Object.isFrozen(player)).toBe(true);
        expect(Object.isFrozen(player.scouting)).toBe(true);
        expect(Object.keys(player.scouting)).toHaveLength(7);
        for (const { key } of FOOTBALL_SCOUTING_ATTRIBUTES) {
          expect(Number.isInteger(player.scouting[key])).toBe(true);
          expect(player.scouting[key]).toBeGreaterThanOrEqual(1);
          expect(player.scouting[key]).toBeLessThanOrEqual(99);
        }
        expect(player.overall).toBe(footballPlayerOverall(player.role, player.scouting));
        statVectors.add(FOOTBALL_SCOUTING_ATTRIBUTES.map(({ key }) => player.scouting[key]).join(':'));
      }
      expect(evaluateFootballLineup(roster, getDefaultFootballLineup(roster)).attackDelta).toBe(0);
    }
    expect(ids.size).toBe(54);
    expect(names.size).toBe(54);
    expect(statVectors.size).toBe(54);
  });

  it('preserves the old ATQ/DEF league model and lineup IDs for existing saved careers', () => {
    const base = [[20,79],[43,74],[62,62],[55,70],[80,39],[19,88],[58,61],[76,50],[66,55]];
    for (const club of FOOTBALL_MANAGER_CLUBS) {
      const roster = getFootballClubRoster(club);
      expect(roster.map(({ attack, defense }, index) => [attack, defense]))
        .toEqual(base.map(([a,d]) => [a+(club.level-3)*3, d+(club.level-3)*3]));
    }
    const club = FOOTBALL_MANAGER_CLUBS[0];
    const journal = createFootballCareer(club.id, 43);
    const original = replayFootballCareer(journal);
    const played = playFootballCareerRound(journal);
    expect(played.season.results).toHaveLength(3);
    expect(replayFootballCareer(played.journal).season.results).toEqual(played.season.results);
    expect(original.season.currentRound).toBe(0);
    const grown = getDevelopedFootballRoster(getFootballClubRoster(club), {
      [getFootballClubRoster(club)[0].id]: { starts: 8, shooting: 4, shape: 2 },
    });
    expect(grown[0].scouting).toEqual(getFootballClubRoster(club)[0].scouting);
    expect(grown[0].bio).toBe(getFootballClubRoster(club)[0].bio);
    expect(grown[0].attackGrowth).toBeGreaterThan(0);
  });

  it('supports custom legacy clubs without forcing an official catalog entry', () => {
    const roster = getFootballClubRoster({ id: 'custom-legacy-club', level: 3 });
    expect(roster).toHaveLength(9);
    expect(roster[0].name.length).toBeGreaterThan(0);
    expect(roster[0].scouting.keeping).toBeGreaterThan(0);
    expect(() => footballPlayerOverall('striker', roster[0].scouting)).toThrow('scouting');
  });
});
