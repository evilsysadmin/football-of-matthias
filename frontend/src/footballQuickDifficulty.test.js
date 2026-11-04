import { describe, it, expect } from 'vitest';
import { FOOTBALL_QUICK_DIFFICULTIES, normalizeFootballQuickDifficulty, footballQuickMatchUrl, footballStagingElevenEnabled } from './footballQuickDifficulty.js';

describe('Football quick match levels', () => {
  it('offers exactly four stable levels and normal fallbacks', () => {
    expect(FOOTBALL_QUICK_DIFFICULTIES.map(x=>x.id)).toEqual(['easy','normal','hard','expert']);
    expect(FOOTBALL_QUICK_DIFFICULTIES.map(x=>x.label)).toEqual(['Fácil','Normal','Difícil','Experto']);
    expect(normalizeFootballQuickDifficulty('invalid')).toBe('normal');
    expect(normalizeFootballQuickDifficulty(null)).toBe('normal');
  });
  it('keeps the immutable runtime release URL intact and passes a validated fragment', () => {
    const origin = 'https://assets.chess-studio.shadowops.dpdns.org/football-of-matthias/staging/releases/1234567890abcdef/index.html';
    for (const {id} of FOOTBALL_QUICK_DIFFICULTIES) {
      const resolved = new URL(footballQuickMatchUrl(origin,id));
      expect(resolved.origin+resolved.pathname).toBe(origin);
      expect(resolved.search).toBe('');
      expect(resolved.hash).toBe('#football-difficulty='+id);
    }
    expect(footballQuickMatchUrl(origin,'expert#foo')).toBe(origin+'#football-difficulty=normal');
    expect(footballQuickMatchUrl('', 'expert')).toBe('');
  });
  it('restricts the 11v11 launch to staging and keeps the CPU difficulty intact', () => {
    const release = 'https://assets.chess-studio.shadowops.dpdns.org/football-of-matthias/staging/releases/1234567890abcdef/index.html';
    expect(footballStagingElevenEnabled('staging.football.shadowops.dpdns.org')).toBe(true);
    expect(footballStagingElevenEnabled('football.shadowops.dpdns.org')).toBe(false);
    expect(footballStagingElevenEnabled('staging.football.shadowops.dpdns.org.evil.tld')).toBe(false);
    expect(footballQuickMatchUrl(release, 'hard', 11)).toBe(release+'#football-difficulty=hard&football-team-size=11');
    expect(footballQuickMatchUrl(release, 'hard', 5)).toBe(release+'#football-difficulty=hard');
    expect(footballQuickMatchUrl(release, 'hard', '11')).toBe(release+'#football-difficulty=hard');
    const outside = 'https://assets.chess-studio.shadowops.dpdns.org/football-of-matthias/production/releases/1234567890abcdef/index.html';
    expect(footballQuickMatchUrl(outside,'expert',11)).toBe(outside+'#football-difficulty=expert');
    expect(footballQuickMatchUrl('https://example.org/foo.html','easy',11)).toBe('https://example.org/foo.html#football-difficulty=easy');
  });
});
