import { getFootballClubRoster } from './footballManagerRoster.js';

// Match-only 4-3-3 identities. The manager's nine-player journal and its
// immutable 5v5 squad remain unchanged until a versioned career migration.
const freeze = Object.freeze;
const ATTRIBUTES = freeze(["pace","stamina","technique","passing","shooting","tackling","keeping"]);
const SUPPLEMENTAL = freeze({
  "fc-matthias": [
    [
      "Héctor Salvat",
      26,
      "Central de corte limpio, domina el juego aéreo y sabe iniciar desde atrás.",
      [
        81,
        86,
        72,
        75,
        39,
        82,
        8
      ]
    ],
    [
      "Unai Cabrera",
      22,
      "Lateral intenso, gana metros por fuera sin descuidar la espalda.",
      [
        74,
        82,
        71,
        67,
        35,
        81,
        7
      ]
    ],
    [
      "Izan Marín",
      24,
      "Extremo incisivo, ataca el intervalo entre lateral y central.",
      [
        88,
        82,
        84,
        74,
        81,
        35,
        6
      ]
    ]
  ],
  "real-enroque": [
    [
      "Pau Ortega",
      25,
      "Lateral asociativo que combina por dentro y da continuidad a la posesión.",
      [
        72,
        83,
        82,
        88,
        31,
        78,
        8
      ]
    ],
    [
      "Jaime Robles",
      29,
      "Central sereno, sobresale leyendo desmarques y saliendo con criterio.",
      [
        68,
        82,
        76,
        85,
        30,
        86,
        7
      ]
    ],
    [
      "Nil Cortés",
      20,
      "Extremo habilidoso, busca el uno contra uno con paciencia.",
      [
        84,
        77,
        88,
        86,
        79,
        33,
        4
      ]
    ]
  ],
  "atletico-torreon": [
    [
      "César Olmedo",
      27,
      "Central expeditivo, agresivo en la marca y fuerte por alto.",
      [
        59,
        88,
        49,
        54,
        27,
        93,
        6
      ]
    ],
    [
      "Víctor Garrido",
      24,
      "Lateral trabajador, tapa la banda y ayuda siempre al central.",
      [
        70,
        87,
        56,
        61,
        32,
        87,
        8
      ]
    ],
    [
      "Aitor Benítez",
      22,
      "Atacante de presión incansable, corre al espacio tras cada robo.",
      [
        81,
        91,
        60,
        56,
        76,
        65,
        6
      ]
    ]
  ],
  "union-alfil": [
    [
      "Biel Navarro",
      21,
      "Carrilero veloz, busca la línea de fondo para poner centros.",
      [
        84,
        84,
        70,
        77,
        42,
        71,
        4
      ]
    ],
    [
      "Rodrigo Gil",
      30,
      "Central veterano con gran colocación y salida segura.",
      [
        72,
        81,
        66,
        74,
        37,
        79,
        7
      ]
    ],
    [
      "Samuel Torres",
      23,
      "Extremo a pierna cambiada, rompe hacia dentro y dispara.",
      [
        90,
        75,
        79,
        74,
        80,
        39,
        6
      ]
    ]
  ],
  "deportivo-gambito": [
    [
      "Xavi Ferrán",
      24,
      "Defensa valiente que arriesga el pase vertical para salir jugando.",
      [
        73,
        65,
        67,
        78,
        35,
        67,
        7
      ]
    ],
    [
      "Pol Medina",
      20,
      "Lateral ofensivo, todavía aprende cuándo replegar.",
      [
        82,
        61,
        79,
        77,
        44,
        58,
        6
      ]
    ],
    [
      "Enzo Lozano",
      25,
      "Delantero creativo de regate y último toque impredecibles.",
      [
        90,
        70,
        85,
        69,
        83,
        22,
        5
      ]
    ]
  ],
  "peones-del-norte": [
    [
      "Jon Aranda",
      28,
      "Central disciplinado, protege el área y gana duelos por anticipación.",
      [
        61,
        88,
        52,
        58,
        35,
        79,
        7
      ]
    ],
    [
      "Borja Echevarría",
      26,
      "Defensa de recorrido, recupera la posición tras cada contra.",
      [
        70,
        86,
        59,
        68,
        28,
        84,
        6
      ]
    ],
    [
      "Asier Domínguez",
      23,
      "Punta móvil, explota los metros libres en transiciones rápidas.",
      [
        85,
        82,
        70,
        62,
        74,
        41,
        5
      ]
    ]
  ]
});
export const FOOTBALL_ELEVEN_ROLES = freeze(['POR', 'DEF', 'DEF', 'DEF', 'DEF', 'MED', 'MED', 'MED', 'DEL', 'DEL', 'DEL']);

// Eight legacy outfield+keeper identities are reused, with three new players
// per club. The backup keeper is NOT secretly fielded as an outfield player.
export function getFootballElevenMatchStarters(club) {
  const legacy = getFootballClubRoster(club);
  const additions = SUPPLEMENTAL[club.id];
  if (!Array.isArray(additions) || additions.length !== 3) {
    throw new Error('No canonical 11v11 squad for club');
  }
  const players = additions.map(([name, age, bio, ratings], index) => {
    const role = index === 2 ? 'DEL' : 'DEF';
    const ordinal = index === 2 ? 3 : index + 3;
    return freeze({
      id: `${club.id}-${role.toLowerCase()}-${ordinal}`,
      name, role, age, bio,
      scouting: freeze(Object.fromEntries(ATTRIBUTES.map((key, i) => [key, ratings[i]]))),
    });
  });
  const starters = [legacy[0], legacy[1], legacy[6], players[0], players[1],
    legacy[2], legacy[3], legacy[7], legacy[4], legacy[8], players[2]];
  if (new Set(starters.map(({ id }) => id)).size !== 11
    || starters.some(({ role }, i) => role !== FOOTBALL_ELEVEN_ROLES[i])) {
    throw new Error('Invalid 4-3-3 canonical lineup');
  }
  return freeze(starters);
}
