// Versioned, fictional scouting catalog. Index order and the legacy roster IDs
// remain stable: career journals replay only ID, ATQ and DEF. Seven scouting
// ratings are informational until Godot's match integration is designed.
export const FOOTBALL_SCOUTING_ATTRIBUTES = Object.freeze([
  Object.freeze({ key: 'pace', label: 'Velocidad' }),
  Object.freeze({ key: 'stamina', label: 'Resistencia' }),
  Object.freeze({ key: 'technique', label: 'Técnica' }),
  Object.freeze({ key: 'passing', label: 'Pase' }),
  Object.freeze({ key: 'shooting', label: 'Remate' }),
  Object.freeze({ key: 'tackling', label: 'Defensa' }),
  Object.freeze({ key: 'keeping', label: 'Portería' }),
]);
const RAW_PROFILES = {
  "fc-matthias": [
    [
      "Óscar Campos",
      29,
      "Portero de reflejos felinos; manda en el área y apenas regala rechaces.",
      49,
      78,
      46,
      54,
      20,
      39,
      85
    ],
    [
      "Iván Prieto",
      27,
      "Central de escuela antigua: anticipa, ordena y sale tocando sin alardes.",
      65,
      84,
      58,
      70,
      34,
      84,
      12
    ],
    [
      "Sergio Cano",
      24,
      "Cerebro de posesión, vive entre líneas y ve pases que nadie espera.",
      71,
      82,
      88,
      90,
      62,
      62,
      10
    ],
    [
      "Eric Roca",
      30,
      "Interior incansable que equilibra el equipo y llega desde segunda línea.",
      76,
      92,
      75,
      81,
      69,
      76,
      9
    ],
    [
      "Lucas Aguirre",
      23,
      "Nueve eléctrico: primer paso temible y remate seco con ambas piernas.",
      90,
      79,
      84,
      64,
      92,
      32,
      8
    ],
    [
      "Bruno Luna",
      34,
      "Guardameta veterano, menos veloz pero enorme en el mano a mano.",
      39,
      66,
      50,
      58,
      16,
      31,
      88
    ],
    [
      "Gael Campos",
      20,
      "Defensa de cantera, agresivo en el robo y valiente cuando sube.",
      82,
      77,
      68,
      61,
      48,
      74,
      7
    ],
    [
      "Hugo Prieto",
      26,
      "Organizador de zurda educada; acelera los ataques con un solo toque.",
      73,
      74,
      86,
      91,
      57,
      49,
      11
    ],
    [
      "Álex Cano",
      21,
      "Delantero de apoyo, asociativo y oportunista en el segundo palo.",
      77,
      78,
      75,
      76,
      79,
      43,
      6
    ]
  ],
  "real-enroque": [
    [
      "Iker Vidal",
      31,
      "Portero sobrio y de gran colocación; prefiere asegurar a lucirse.",
      42,
      72,
      43,
      67,
      17,
      36,
      88
    ],
    [
      "Leo Costa",
      28,
      "Defensa elegante que rompe líneas con pases verticales.",
      65,
      83,
      76,
      84,
      40,
      79,
      8
    ],
    [
      "Marcos Rey",
      22,
      "Mediapunta exquisito; controla en espacios minúsculos y filtra balones.",
      79,
      75,
      91,
      89,
      65,
      51,
      8
    ],
    [
      "Dani Ferrer",
      26,
      "Interior de metrónomo, siempre ofrece una línea de pase.",
      71,
      88,
      86,
      93,
      56,
      63,
      12
    ],
    [
      "Nico León",
      25,
      "Goleador cerebral: desmarque breve, toque rápido y mucha puntería.",
      79,
      75,
      86,
      74,
      91,
      38,
      5
    ],
    [
      "Álvaro Serrano",
      20,
      "Portero de gran proyección, destaca por sus reflejos y pies.",
      52,
      76,
      63,
      73,
      20,
      36,
      80
    ],
    [
      "Julián Vidal",
      32,
      "Zaguero experimentado; lee las coberturas antes de que llegue el peligro.",
      54,
      72,
      66,
      77,
      28,
      85,
      10
    ],
    [
      "Adrián Costa",
      24,
      "Centrocampista de pausa y último pase, especialista en saques cortos.",
      68,
      74,
      81,
      87,
      61,
      53,
      7
    ],
    [
      "Mateo Rey",
      19,
      "Canterano de regate valiente; alterna genialidades y decisiones precipitadas.",
      86,
      68,
      86,
      70,
      74,
      35,
      6
    ]
  ],
  "atletico-torreon": [
    [
      "Adrián Valdés",
      32,
      "Portero de guantes duros; domina los balones divididos y la voz de mando.",
      39,
      77,
      37,
      46,
      15,
      48,
      84
    ],
    [
      "Saúl Barrera",
      29,
      "Defensa rocoso, contundente por abajo y disciplinado en el bloque.",
      57,
      83,
      49,
      53,
      29,
      88,
      8
    ],
    [
      "Tomás Robledo",
      27,
      "Medio recuperador que sostiene el repliegue con oficio.",
      65,
      86,
      62,
      59,
      46,
      84,
      8
    ],
    [
      "Néstor Blanco",
      24,
      "Volante todoterreno: persigue al rival y lanza contras.",
      75,
      91,
      67,
      70,
      57,
      73,
      10
    ],
    [
      "Rubén Alarcón",
      28,
      "Punta de choque; gana la posición y remata de primeras.",
      72,
      77,
      61,
      52,
      82,
      51,
      6
    ],
    [
      "Pablo Merino",
      21,
      "Portero ágil y valiente en salidas, aún debe mejorar el juego con los pies.",
      59,
      71,
      40,
      41,
      16,
      32,
      78
    ],
    [
      "Diego Montes",
      23,
      "Lateral reconvertido al fútbol cinco, rápido en las ayudas.",
      81,
      80,
      56,
      58,
      40,
      75,
      7
    ],
    [
      "Fermín Ortega",
      30,
      "Mediocentro táctico: pocas florituras y mucha lectura defensiva.",
      61,
      79,
      70,
      76,
      47,
      78,
      8
    ],
    [
      "Joel Pastor",
      20,
      "Delantero de presión feroz, roba arriba y aprovecha segundas jugadas.",
      82,
      84,
      64,
      56,
      73,
      58,
      5
    ]
  ],
  "union-alfil": [
    [
      "Marcos Luna",
      25,
      "Portero ágil, inicia contragolpes con lanzamientos largos.",
      51,
      73,
      49,
      68,
      18,
      42,
      78
    ],
    [
      "Dani Campos",
      24,
      "Defensa de ida y vuelta, especialista en cerrar bandas.",
      79,
      82,
      60,
      64,
      35,
      77,
      8
    ],
    [
      "Nico Prieto",
      27,
      "Extremo reconvertido a interior, abre campo y centra con precisión.",
      85,
      77,
      74,
      83,
      54,
      52,
      5
    ],
    [
      "Álvaro Cano",
      22,
      "Mediocampista de centro tenso y llegada al segundo palo.",
      72,
      83,
      74,
      86,
      67,
      59,
      7
    ],
    [
      "Julián Roca",
      29,
      "Delantero aéreo y rematador, sabe esperar el centro adecuado.",
      66,
      73,
      69,
      53,
      84,
      40,
      5
    ],
    [
      "Adrián Aguirre",
      33,
      "Veterano de portería; difícil de batir en distancias cortas.",
      37,
      61,
      37,
      52,
      14,
      29,
      82
    ],
    [
      "Mateo Luna",
      21,
      "Defensa zurdo que proyecta bien la pelota por fuera.",
      78,
      78,
      66,
      70,
      39,
      70,
      6
    ],
    [
      "Iker Campos",
      26,
      "Interior de recorrido largo, centro medido y gran resistencia.",
      81,
      89,
      67,
      82,
      48,
      61,
      8
    ],
    [
      "Leo Prieto",
      19,
      "Punta rápido que amenaza el espacio libre más que el juego de espaldas.",
      89,
      72,
      72,
      56,
      74,
      30,
      6
    ]
  ],
  "deportivo-gambito": [
    [
      "Víctor Mena",
      24,
      "Portero atrevido que juega adelantado; alterna paradas brillantes y riesgos.",
      61,
      66,
      56,
      59,
      20,
      29,
      69
    ],
    [
      "Fabio Ledesma",
      22,
      "Defensa ofensivo, rompe líneas aunque deje huecos a su espalda.",
      78,
      68,
      65,
      66,
      49,
      59,
      8
    ],
    [
      "Samuel Cuesta",
      20,
      "Regateador imprevisible, encara incluso cuando sería más fácil pasar.",
      86,
      70,
      86,
      58,
      62,
      35,
      7
    ],
    [
      "Mauro Serrano",
      27,
      "Interior de último pase y disparo lejano, poco amigo de replegar.",
      68,
      72,
      78,
      81,
      75,
      38,
      8
    ],
    [
      "Enzo Pereda",
      23,
      "Delantero explosivo que vive al límite del fuera de juego.",
      92,
      67,
      76,
      51,
      84,
      24,
      5
    ],
    [
      "Darío Cordero",
      29,
      "Suplente bajo palos, fuerte en el uno contra uno y limitado por arriba.",
      48,
      65,
      41,
      44,
      14,
      31,
      73
    ],
    [
      "Rafa Villalba",
      25,
      "Zaguero veloz que corrige con piernas lo que pierde en colocación.",
      85,
      74,
      51,
      48,
      35,
      64,
      5
    ],
    [
      "Noé Ramírez",
      19,
      "Canterano habilidoso, gran conducción pero irregular en el último pase.",
      80,
      69,
      82,
      61,
      54,
      34,
      7
    ],
    [
      "Héctor Gálvez",
      31,
      "Segundo delantero curtido; protege el balón y golpea sin avisar.",
      60,
      64,
      71,
      59,
      78,
      37,
      5
    ]
  ],
  "peones-del-norte": [
    [
      "Bruno Salas",
      30,
      "Portero paciente, protege su palo y ordena los cierres.",
      43,
      77,
      39,
      49,
      15,
      45,
      76
    ],
    [
      "Gael Soler",
      25,
      "Defensa resistente que aguanta el uno contra uno sin lanzarse.",
      68,
      87,
      54,
      56,
      24,
      80,
      7
    ],
    [
      "Hugo Paredes",
      23,
      "Mediocentro sacrificado, barre por delante de la zaga.",
      66,
      90,
      59,
      61,
      46,
      75,
      8
    ],
    [
      "Álex Ríos",
      21,
      "Lanzador de contraataques, corre más de lo que pausa.",
      88,
      81,
      64,
      70,
      50,
      53,
      7
    ],
    [
      "Óscar Molina",
      28,
      "Delantero de pocos toques, letal si recibe al espacio.",
      83,
      76,
      69,
      47,
      80,
      39,
      6
    ],
    [
      "Iván Gil",
      32,
      "Arquero de oficio, firme ante disparos fuertes y algo lento en las salidas.",
      35,
      65,
      42,
      53,
      16,
      38,
      79
    ],
    [
      "Sergio Salas",
      19,
      "Defensa de cantera con zancada larga y buen juego aéreo.",
      74,
      77,
      50,
      45,
      31,
      70,
      7
    ],
    [
      "Eric Soler",
      26,
      "Pasador trabajador, nunca deja de ofrecerse en apoyo.",
      70,
      85,
      67,
      74,
      49,
      57,
      8
    ],
    [
      "Lucas Paredes",
      22,
      "Atacante zurdo que busca diagonales y disparos al segundo palo.",
      79,
      74,
      72,
      59,
      76,
      35,
      5
    ]
  ]
};

export const FOOTBALL_PLAYER_PROFILES = Object.freeze(Object.fromEntries(
  Object.entries(RAW_PROFILES).map(([clubId, rows]) => [
    clubId,
    Object.freeze(rows.map(([name, age, bio, ...ratings]) => Object.freeze({
      name, age, bio,
      scouting: Object.freeze(Object.fromEntries(
        FOOTBALL_SCOUTING_ATTRIBUTES.map(({ key }, index) => [key, ratings[index]]),
      )),
    }))),
  ]),
));

const OVERALL_WEIGHTS = Object.freeze({
  POR: Object.freeze({ keeping: .77, pace: .07, stamina: .06, technique: .04, passing: .06 }),
  DEF: Object.freeze({ tackling: .43, stamina: .19, pace: .18, passing: .12, technique: .08 }),
  MED: Object.freeze({ passing: .31, technique: .25, stamina: .18, pace: .12, tackling: .09, shooting: .05 }),
  DEL: Object.freeze({ shooting: .40, pace: .21, technique: .17, passing: .10, stamina: .08, tackling: .04 }),
});

export function footballPlayerOverall(role, scouting) {
  const weights = OVERALL_WEIGHTS[role];
  if (!weights || !scouting || FOOTBALL_SCOUTING_ATTRIBUTES.some(({ key }) =>
    !Number.isInteger(scouting[key]) || scouting[key] < 1 || scouting[key] > 99)) {
    throw new Error('Invalid football player scouting ratings');
  }
  return Math.round(Object.entries(weights).reduce(
    (sum, [attribute, weight]) => sum + scouting[attribute] * weight, 0,
  ));
}

export function getFootballScoutingProfile(clubId, index, fallbackName, role, attack, defense) {
  const authored = FOOTBALL_PLAYER_PROFILES[clubId]?.[index];
  // Custom test/legacy clubs outside the six official clubs remain supported.
  // The authored catalog is not required for an otherwise valid old roster.
  const limit = (value) => Math.max(12, Math.min(93, Math.round(value)));
  const scouting = authored?.scouting || Object.freeze({
    pace: limit((attack + defense) / 2 + 4),
    stamina: limit((attack + defense) / 2 + 6),
    technique: limit(attack + 1),
    passing: limit(attack + 2),
    shooting: limit(attack - 4),
    tackling: limit(defense + 3),
    keeping: role === 'POR' ? limit(defense + 8) : 8,
  });
  return Object.freeze({
    name: authored?.name || fallbackName,
    age: authored?.age || 22 + index,
    bio: authored?.bio || 'Jugador polivalente de la plantilla; su perfil se adapta a las necesidades del equipo.',
    scouting,
    overall: footballPlayerOverall(role, scouting),
  });
}
