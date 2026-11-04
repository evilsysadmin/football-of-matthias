// Contract for the four pre-match CPU levels; unrelated to the manager's journal.
export const FOOTBALL_QUICK_DIFFICULTIES = Object.freeze([
  Object.freeze({ id: 'easy', label: 'Fácil', description: 'Más tiempo para pensar y menos presión rival.' }),
  Object.freeze({ id: 'normal', label: 'Normal', description: 'La CPU de siempre, con adaptación al partido.' }),
  Object.freeze({ id: 'hard', label: 'Difícil', description: 'Mayor presión y decisiones más rápidas.' }),
  Object.freeze({ id: 'expert', label: 'Experto', description: 'Reacción rápida y presión exigente.' }),
]);
export const DEFAULT_FOOTBALL_QUICK_DIFFICULTY = 'normal';

// The experimental XI selector is exclusive to Football's authenticated
// staging entry. It does not add an 11v11 switch to other hosts.
export function footballStagingElevenEnabled(hostname) {
  return hostname === 'staging.football.shadowops.dpdns.org';
}
export function normalizeFootballQuickDifficulty(value) {
  return FOOTBALL_QUICK_DIFFICULTIES.some((level) => level.id === value) ? value : DEFAULT_FOOTBALL_QUICK_DIFFICULTY;
}
export function footballQuickMatchUrl(url, difficulty = DEFAULT_FOOTBALL_QUICK_DIFFICULTY, teamSize = 5) {
  if (!url) return '';
  const result = new URL(url);
  // Fragments are read by Godot at boot, never sent to the release CDN.
  const stagingRelease = result.protocol === 'https:'
    && result.hostname === 'assets.chess-studio.shadowops.dpdns.org'
    && /^\\/football-of-matthias\\/staging\\/releases\\/[0-9a-f]{16}\\/index\\.html$/.test(result.pathname);
  const previewXi = stagingRelease && teamSize === 11;
  result.hash = `football-difficulty=${normalizeFootballQuickDifficulty(difficulty)}${previewXi ? '&football-team-size=11' : ''}`;
  return result.href;
}
