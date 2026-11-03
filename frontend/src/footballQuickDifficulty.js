// Contract for the four pre-match CPU levels; unrelated to the manager's journal.
export const FOOTBALL_QUICK_DIFFICULTIES = Object.freeze([
  Object.freeze({ id: 'easy', label: 'Fácil', description: 'Más tiempo para pensar y menos presión rival.' }),
  Object.freeze({ id: 'normal', label: 'Normal', description: 'La CPU de siempre, con adaptación al partido.' }),
  Object.freeze({ id: 'hard', label: 'Difícil', description: 'Mayor presión y decisiones más rápidas.' }),
  Object.freeze({ id: 'expert', label: 'Experto', description: 'Reacción rápida y presión exigente.' }),
]);
export const DEFAULT_FOOTBALL_QUICK_DIFFICULTY = 'normal';
export function normalizeFootballQuickDifficulty(value) {
  return FOOTBALL_QUICK_DIFFICULTIES.some((level) => level.id === value) ? value : DEFAULT_FOOTBALL_QUICK_DIFFICULTY;
}
export function footballQuickMatchUrl(url, difficulty = DEFAULT_FOOTBALL_QUICK_DIFFICULTY) {
  if (!url) return '';
  const result = new URL(url);
  // Fragments are read by Godot at boot, never sent to the release CDN.
  result.hash = `football-difficulty=${normalizeFootballQuickDifficulty(difficulty)}`;
  return result.href;
}
