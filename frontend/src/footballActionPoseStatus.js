// Read-only cross-origin R2 art receipts. Never include match/user telemetry.
export const FOOTBALL_POSE_TEAMS = Object.freeze([
  Object.freeze({ id: 0, label: 'FC Matthias' }),
  Object.freeze({ id: 1, label: 'Real Enroque' }),
]);
export const FOOTBALL_POSE_ACTIONS = Object.freeze([
  Object.freeze({ id: 'dribble_cut', label: 'Recorte' }),
  Object.freeze({ id: 'dribble_burst', label: 'Toque largo' }),
  Object.freeze({ id: 'tackle', label: 'Entrada' }),
  Object.freeze({ id: 'slide_tackle', label: 'Segada' }),
]);
const VALID_KEYS = new Set(FOOTBALL_POSE_TEAMS.flatMap((team) =>
  FOOTBALL_POSE_ACTIONS.map((pose) => `${team.id}:${pose.id}`)
));
export const FOOTBALL_POSE_TOTAL = VALID_KEYS.size;

export function parseFootballPoseReceipt(message) {
  if (message?.source !== 'chess-football-godot' ||
      message?.type !== 'action-poses-status' ||
      message.team_size !== 11 || message.expected !== FOOTBALL_POSE_TOTAL ||
      !Array.isArray(message.installed) ||
      message.installed.length < 1 || message.installed.length > FOOTBALL_POSE_TOTAL) {
    return null;
  }
  const installed = new Set(message.installed);
  if (installed.size !== message.installed.length ||
      [...installed].some((key) => typeof key !== 'string' || !VALID_KEYS.has(key))) {
    return null;
  }
  return [...installed];
}

export function footballPoseTeamCount(installed, teamId) {
  return FOOTBALL_POSE_ACTIONS.reduce(
    (count, pose) => count + Number(installed.includes(`${teamId}:${pose.id}`)),
    0
  );
}
