import { describe, it, expect } from 'vitest';
import { FOOTBALL_QUICK_DIFFICULTIES, normalizeFootballQuickDifficulty, footballQuickMatchUrl } from './footballQuickDifficulty.js';

describe('Football quick match levels', () => {
  it('offers exactly four stable levels and normal fallbacks', () => {
    expect(FOOTBALL_QUICK_DIFFICULTIES.map(x=>x.id)).toEqual(['easy','normal','hard','expert']);
    expect(FOOTBALL_QUICK_DIFFICULTIES.map(x=>x.label)).toEqual(['Fácil','Normal','Difícil','Experto']);
    expect(normalizeFootballQuickDifficulty('invalid')).toBe('normal');
    expect(normalizeFootballQuickDifficulty(null)).toBe('normal');
  });
  const release = 'https://assets.chess-studio.shadowops.dpdns.org/football-of-matthias/staging/releases/1234567890abcdef/index.html';

  it('always boots the full XI for all difficulties on the immutable staging release', () => {
    for (const { id } of FOOTBALL_QUICK_DIFFICULTIES) {
      const resolved = new URL(footballQuickMatchUrl(release, id));
      expect(resolved.origin + resolved.pathname).toBe(release);
      expect(resolved.search).toBe('');
      expect(resolved.hash).toBe('#football-difficulty=' + id + '&football-team-size=11');
    }
    expect(footballQuickMatchUrl(release)).toBe(release + '#football-difficulty=normal&football-team-size=11');
    expect(footballQuickMatchUrl(release, 'expert#foo')).toBe(release + '#football-difficulty=normal&football-team-size=11');
    expect(footballQuickMatchUrl('', 'expert')).toBe('');
  });

  it('has no public 5v5 option and never enables XI on foreign or untrusted runtime URLs', () => {
    // A stale third argument cannot revive the former 5-a-side picker.
    expect(footballQuickMatchUrl(release, 'hard', 5)).toBe(release + '#football-difficulty=hard&football-team-size=11');
    const outside = 'https://assets.chess-studio.shadowops.dpdns.org/football-of-matthias/production/releases/1234567890abcdef/index.html';
    expect(footballQuickMatchUrl(outside, 'expert')).toBe(outside + '#football-difficulty=expert');
    expect(footballQuickMatchUrl('https://example.org/foo.html', 'easy')).toBe('https://example.org/foo.html#football-difficulty=easy');
  });
});
