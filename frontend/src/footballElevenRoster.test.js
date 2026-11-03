import { describe, it, expect } from 'vitest';
import { FOOTBALL_MANAGER_CLUBS } from './footballManagerClubs.js';
import { getFootballClubRoster, getDefaultFootballLineup } from './footballManagerRoster.js';
import { getFootballElevenMatchStarters, FOOTBALL_ELEVEN_ROLES } from './footballElevenRoster.js';

describe('Football · 11v11 identities without career journal migration', () => {
  it('provides 11 different 4-3-3 starters per club and keeps every legacy 5v5 player ID', () => {
    for (const club of FOOTBALL_MANAGER_CLUBS) {
      const old = getFootballClubRoster(club);
      const previousIds = old.map(({ id }) => id);
      const previousFive = getDefaultFootballLineup(old);
      const starters = getFootballElevenMatchStarters(club);
      expect(starters).toHaveLength(11);
      expect(starters.map(({ role }) => role)).toEqual(FOOTBALL_ELEVEN_ROLES);
      expect(starters.map(({ id }) => id)).toEqual([
        old[0].id, old[1].id, old[6].id,
        `${club.id}-def-3`, `${club.id}-def-4`,
        old[2].id, old[3].id, old[7].id,
        old[4].id, old[8].id, `${club.id}-del-3`,
      ]);
      expect(new Set(starters.map(({ id }) => id)).size).toBe(11);
      expect(getFootballClubRoster(club).map(({ id }) => id)).toEqual(previousIds);
      expect(getDefaultFootballLineup(getFootballClubRoster(club))).toEqual(previousFive);
      for (const p of starters) {
        expect(p.name.length).toBeGreaterThan(5);
        expect(p.bio.length).toBeGreaterThan(20);
        expect(p.age).toBeGreaterThanOrEqual(18);
        for (const v of Object.values(p.scouting)) {
          expect(Number.isInteger(v) && v >= 1 && v <= 99).toBe(true);
        }
      }
      expect(Object.isFrozen(starters)).toBe(true);
    }
  });

  it('rejects an unknown club rather than inventing 11 match identities', () => {
    expect(() => getFootballElevenMatchStarters({ id: 'unregistered', level: 3 })).toThrow();
  });
});
