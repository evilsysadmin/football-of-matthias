import { describe, expect, it } from 'vitest';
import { getFootballManagerClub } from './footballManagerClubs.js';
import { getFootballClubRoster } from './footballManagerRoster.js';
import { createFootballCareer, editFootballCareer, playFootballCareerRound } from './footballManagerCareer.js';
import { createFootballManagerMatchRatings, getFootballEarnedScouting } from './footballManagerMatchRatings.js';

const roster = getFootballClubRoster(getFootballManagerClub('fc-matthias'));
const keeper = roster.find(p => p.role === 'POR');
const forward = roster.find(p => p.role === 'DEL');
const defender = roster.find(p => p.role === 'DEF');

describe('Football RPG · effective match ratings', () => {
  it('keeps untrained profiles unchanged and trains only appropriate skills', () => {
    expect(getFootballEarnedScouting(forward)).toEqual(forward.scouting);
    const shooting = getFootballEarnedScouting(forward, { starts: 2, shooting: 2 });
    expect(shooting.shooting).toBe(Math.min(99, forward.scouting.shooting + 1));
    expect(shooting.tackling).toBe(forward.scouting.tackling);
    const shape = getFootballEarnedScouting(defender, { starts: 2, shape: 2 });
    expect(shape.tackling).toBe(Math.min(99, defender.scouting.tackling + 1));
    expect(shape.shooting).toBe(defender.scouting.shooting);
    const saves = getFootballEarnedScouting(keeper, { starts: 2, shape: 2 });
    expect(saves.keeping).toBe(Math.min(99, keeper.scouting.keeping + 1));
    expect(saves.shooting).toBe(keeper.scouting.shooting);
  });
  it('bounds every attribute and rejects impossible training histories', () => {
    const effective = getFootballEarnedScouting(defender, { starts: 200, shape: 200 });
    for (const [key, value] of Object.entries(effective)) {
      expect(value).toBeGreaterThanOrEqual(defender.scouting[key]);
      expect(value).toBeLessThanOrEqual(Math.min(99, defender.scouting[key] + 4));
    }
    expect(getFootballEarnedScouting({ ...forward, scouting: { ...forward.scouting, shooting: 98 } }, { starts: 20, shooting: 20 }).shooting).toBe(99);
    expect(() => getFootballEarnedScouting(forward, { starts: 1, shooting: 2 })).toThrow();
    expect(Object.isFrozen(effective)).toBe(true);
  });
  it('prepares an immutable five-player snapshot from real replayed career decisions', () => {
    let journal = createFootballCareer('fc-matthias');
    journal = editFootballCareer(journal, { training: 'shooting' }).journal;
    for (let i = 0; i < 2; i++) journal = playFootballCareerRound(journal).journal;
    const before = JSON.stringify(journal);
    const snapshot = createFootballManagerMatchRatings(journal);
    expect(snapshot).toEqual(createFootballManagerMatchRatings(JSON.parse(before)));
    expect(JSON.stringify(journal)).toBe(before);
    expect(snapshot).toMatchObject({ version: 1, clubId: 'fc-matthias', teamSize: 5, season: 1, round: 3 });
    expect(snapshot.players.map(p => p.id)).toEqual(journal.nextLineup);
    expect(snapshot.players.find(p => p.id === forward.id).scouting.shooting).toBe(Math.min(99, forward.scouting.shooting + 1));
    expect(Object.isFrozen(snapshot.players[0].scouting)).toBe(true);
    expect(Object.isFrozen(snapshot.players)).toBe(true);
    const substitute = roster.find(p => p.role === 'DEL' && p.id !== forward.id);
    const rotated = editFootballCareer(journal, { lineup: journal.nextLineup.map(id => id === forward.id ? substitute.id : id) }).journal;
    expect(createFootballManagerMatchRatings(rotated).players.find(p => p.id === substitute.id).scouting).toEqual(substitute.scouting);
    expect(() => createFootballManagerMatchRatings({ ...journal, nextLineup: ['fake'] })).toThrow();
  });
  it('does not allow a completed season to prepare another match', () => {
    let journal = createFootballCareer('fc-matthias');
    for (let i = 0; i < 10; i++) journal = playFootballCareerRound(journal).journal;
    expect(() => createFootballManagerMatchRatings(journal)).toThrow('complete');
  });
});
