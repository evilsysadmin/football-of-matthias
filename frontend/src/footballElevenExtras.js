// Eight fixed, fictional outfield identities needed by the first future
// 11v11 quick-match lineups. Keep the original nine-player manager rosters,
// fatigue keys, and 5v5 formation untouched until an explicit career migration.
const freeze = Object.freeze;
const RAW_EXTRAS = {
  "fc-matthias": [
    {
      "id": "fc-matthias-def-3",
      "name": "Tomás Berenguer",
      "role": "DEF",
      "age": 26,
      "bio": "Central sereno, domina el juego aéreo y cierra el segundo palo.",
      "scouting": {
        "pace": 68,
        "stamina": 84,
        "technique": 64,
        "passing": 70,
        "shooting": 30,
        "tackling": 84,
        "keeping": 9
      }
    },
    {
      "id": "fc-matthias-def-4",
      "name": "Joel Llorens",
      "role": "DEF",
      "age": 22,
      "bio": "Lateral de ida y vuelta, rápido al repliegue y prudente en las entradas.",
      "scouting": {
        "pace": 81,
        "stamina": 77,
        "technique": 60,
        "passing": 64,
        "shooting": 42,
        "tackling": 76,
        "keeping": 7
      }
    },
    {
      "id": "fc-matthias-ext-1",
      "name": "Bruno Vega",
      "role": "EXT",
      "age": 24,
      "bio": "Extremo de desborde corto, busca la línea de fondo y el pase atrás.",
      "scouting": {
        "pace": 89,
        "stamina": 76,
        "technique": 83,
        "passing": 78,
        "shooting": 71,
        "tackling": 40,
        "keeping": 5
      }
    },
    {
      "id": "fc-matthias-ext-2",
      "name": "Samuel Molina",
      "role": "EXT",
      "age": 21,
      "bio": "Extremo zurdo que ataca el espacio y centra antes del primer toque rival.",
      "scouting": {
        "pace": 86,
        "stamina": 72,
        "technique": 79,
        "passing": 68,
        "shooting": 74,
        "tackling": 33,
        "keeping": 6
      }
    }
  ],
  "real-enroque": [
    {
      "id": "real-enroque-def-3",
      "name": "Nacho Beltrán",
      "role": "DEF",
      "age": 28,
      "bio": "Central poderoso que anticipa el pase interior y protege al guardameta.",
      "scouting": {
        "pace": 69,
        "stamina": 85,
        "technique": 62,
        "passing": 65,
        "shooting": 38,
        "tackling": 86,
        "keeping": 8
      }
    },
    {
      "id": "real-enroque-def-4",
      "name": "César Rubio",
      "role": "DEF",
      "age": 23,
      "bio": "Lateral veloz y técnico, abre la banda sin perder la posición defensiva.",
      "scouting": {
        "pace": 82,
        "stamina": 80,
        "technique": 68,
        "passing": 76,
        "shooting": 46,
        "tackling": 76,
        "keeping": 6
      }
    },
    {
      "id": "real-enroque-ext-1",
      "name": "Héctor Vidal",
      "role": "EXT",
      "age": 25,
      "bio": "Extremo paciente, temporiza para colocar centros al pie del delantero.",
      "scouting": {
        "pace": 87,
        "stamina": 79,
        "technique": 84,
        "passing": 82,
        "shooting": 68,
        "tackling": 42,
        "keeping": 8
      }
    },
    {
      "id": "real-enroque-ext-2",
      "name": "Raúl Montoro",
      "role": "EXT",
      "age": 21,
      "bio": "Extremo vertical, busca el uno contra uno y pisa área en diagonal.",
      "scouting": {
        "pace": 91,
        "stamina": 73,
        "technique": 79,
        "passing": 67,
        "shooting": 77,
        "tackling": 35,
        "keeping": 6
      }
    }
  ]
};
export const FOOTBALL_ELEVEN_EXTRAS = freeze(Object.fromEntries(
  Object.entries(RAW_EXTRAS).map(([clubId, players]) => [
    clubId,
    freeze(players.map(({ scouting, ...player }) => freeze({
      ...player,
      scouting: freeze({ ...scouting }),
    }))),
  ]),
));

// Keeper, 4 defenders, 3 midfielders, 2 wingers, striker.
// Nine-manager roster indices stay stable: [0..8]. The second keeper and
// spare forward remain reserves, never secretly redeployed as defenders.
const MANAGER_INDICES = freeze([0, 1, 6, -1, -2, 2, 3, 7, -3, -4, 4]);
const EXPECTED_ROLES = freeze(['POR','DEF','DEF','DEF','DEF','MED','MED','MED','EXT','EXT','DEL']);

export function getFootballElevenMatchLineup(clubId, managerNine) {
  const extras = FOOTBALL_ELEVEN_EXTRAS[clubId];
  if (!extras || !Array.isArray(managerNine) || managerNine.length !== 9) {
    throw new Error('Unsupported Football 11v11 roster');
  }
  const players = MANAGER_INDICES.map((index) => (
    index >= 0 ? managerNine[index] : extras[-index - 1]
  ));
  if (players.some((p, i) => !p || p.role !== EXPECTED_ROLES[i]
    || !p.id.startsWith(`${clubId}-`)
    || Object.values(p.scouting || {}).length !== 7
    || Object.values(p.scouting).some((n) => !Number.isInteger(n) || n < 1 || n > 99))
    || new Set(players.map((p) => p.id)).size !== 11
    || new Set(players.map((p) => p.name)).size !== 11) {
    throw new Error('Invalid Football 11v11 starting eleven');
  }
  return freeze(players);
}
