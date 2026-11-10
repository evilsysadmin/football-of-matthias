import { describe, expect, it } from 'vitest';
import { FOOTBALL_POSE_ACTIONS, FOOTBALL_POSE_TEAMS, FOOTBALL_POSE_TOTAL,
  footballPoseTeamCount, parseFootballPoseReceipt } from './footballActionPoseStatus.js';

const keys = FOOTBALL_POSE_TEAMS.flatMap((team) =>
  FOOTBALL_POSE_ACTIONS.map((pose) => `${team.id}:${pose.id}`)
);
const receipt = (installed) => ({
  source: 'chess-football-godot',
  type: 'action-poses-status',
  team_size: 11,
  expected: 8,
  installed,
});

describe('Football · live action pose R2 status', () => {
  it('accepts only unique, bounded, XI installation receipts', () => {
    expect(FOOTBALL_POSE_TOTAL).toBe(8);
    expect(parseFootballPoseReceipt(receipt(keys))).toEqual(keys);
    expect(footballPoseTeamCount(keys, 0)).toBe(4);
    expect(footballPoseTeamCount(keys.slice(0, 5), 1)).toBe(1);
  });
  it('rejects invalid sources, spoofed counts, duplicates and invented animations', () => {
    expect(parseFootballPoseReceipt({ ...receipt(keys), team_size: 5 })).toBeNull();
    expect(parseFootballPoseReceipt({ ...receipt(keys), source: 'other' })).toBeNull();
    expect(parseFootballPoseReceipt({ ...receipt(keys), expected: 9 })).toBeNull();
    expect(parseFootballPoseReceipt(receipt([]))).toBeNull();
    expect(parseFootballPoseReceipt(receipt([keys[0], keys[0]]))).toBeNull();
    expect(parseFootballPoseReceipt(receipt(['0:goalkeeper']))).toBeNull();
    expect(parseFootballPoseReceipt(receipt([...keys, '0:run']))).toBeNull();
  });
});
