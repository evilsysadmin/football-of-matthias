// Versioned read model for future Godot match-start handoff. Only the
// replay-validated manager journal is authoritative for earned growth.
import { replayFootballCareer } from './footballManagerCareer.js';
import { getFootballManagerClub } from './footballManagerClubs.js';
import { getFootballClubRoster } from './footballManagerRoster.js';
import { getFootballPlayerProgress } from './footballManagerDevelopment.js';
import { FOOTBALL_SCOUTING_ATTRIBUTES, footballPlayerOverall } from './footballPlayerProfiles.js';

export const FOOTBALL_MATCH_RATINGS_VERSION = 1;
export const FOOTBALL_MATCH_RATING_GROWTH_CAP = 4;
const freeze = Object.freeze;
const keys = FOOTBALL_SCOUTING_ATTRIBUTES.map(({ key }) => key);

// Initial, bounded balance: match attendance gives gradual conditioning
// and technique; recorded training improves role-appropriate skills.
// No level bonus, no invented individual passes/shots, no change to ATQ/DEF.
export function getFootballEarnedScouting(player, development = {}) {
  footballPlayerOverall(player.role, player.scouting);
  const { starts = 0, shooting = 0, shape = 0 } = development;
  getFootballPlayerProgress({ starts, shooting, shape }); // validate ledger
  const general = Math.floor(starts / 4);
  const focusedShot = Math.floor(shooting / 2);
  const focusedShape = Math.floor(shape / 2);
  const keeper = player.role === 'POR';
  const requested = {
    pace: keeper ? 0 : Math.floor(starts / 8),
    stamina: general,
    technique: general,
    passing: keeper ? 0 : general + (player.role === 'MED' ? focusedShape : 0),
    shooting: keeper ? 0 : focusedShot,
    tackling: keeper ? 0 : focusedShape + (player.role === 'DEF' ? general : 0),
    keeping: keeper ? general + focusedShape : 0,
  };
  return freeze(Object.fromEntries(keys.map(key => [
    key, Math.min(99, player.scouting[key] + Math.min(FOOTBALL_MATCH_RATING_GROWTH_CAP, requested[key])),
  ])));
}

// The existing manager is 5v5, not the optional XI quick-match catalog.
// Never fabricate a career XI or accept caller-supplied arbitrary ratings.
// Snapshot preparation does not advance a round or change standings.
export function createFootballManagerMatchRatings(journal) {
  const { journal: validated, season } = replayFootballCareer(journal);
  if (season.currentRound >= 10) throw new Error('Football manager season is complete');
  const roster = getFootballClubRoster(getFootballManagerClub(validated.clubId));
  const players = validated.nextLineup.map(id => {
    const player = roster.find(candidate => candidate.id === id);
    return freeze({
      id: player.id,
      role: player.role,
      scouting: getFootballEarnedScouting(player, season.managerDevelopment?.[id]),
    });
  });
  return freeze({
    version: FOOTBALL_MATCH_RATINGS_VERSION,
    clubId: validated.clubId,
    teamSize: 5,
    season: validated.completedSeasons.length + 1,
    round: season.currentRound + 1,
    players: freeze(players),
  });
}
