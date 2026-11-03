# Chess Football — reglas de producto y dirección futura

## Producto actual: fútbol jugable

Chess Football es un juego de fútbol **jugable**, construido sobre el runtime
Godot Web existente. Su identidad visual y el control directo del partido
son un activo del producto, no una demo desechable.

Reglas de aceptación para cualquier iteración de partido:

- **Tamaño aparente consistente**: jugadores de ambos equipos y porteros
  mantienen una estatura comparable al recorrer distintas profundidades del
  campo y cambiar de orientación. La perspectiva no crea gigantes en primer
  plano ni miniaturas al fondo.
- **Luz y arte consistentes**: girar no oscurece ni aclara bruscamente una
  camiseta. Se conserva el sombreado dibujado en cada personaje; no se
  homogenizan colores de equipación, piel ni identidad.
- **Atlas canónicos aprobados intactos** salvo revisión visual explícita de
  nuevos assets. Se conserva el contacto de las botas y las sombras de
  contacto con el césped.
- **Jugabilidad independiente del render**: los ajustes visuales no alteran
  colisiones, velocidades, porteros, IA, controles ni resultados de partido.
- **QA de producto, no sólo tests**: revisar capturas reales y comparativas
  (profundidad, direcciones, porteros, acciones, táctico, móvil) además de
  Godot y arranque Web en Chromium. No aprobar una regresión visible porque
  un smoke test haya terminado verde.

El procedimiento de entrega de Football vive en
[`docs/ci/football-required-merge-gate.md`](../ci/football-required-merge-gate.md).
Estas normas son un **contrato operativo y de producto**, no sustituyen
técnicamente un required status check del ruleset de GitHub.

## Dirección futura: «Despacho del míster» (inspiración PC Fútbol)

**Implementación incremental en curso.** La pantalla de bienvenida y su
entrada separada a `Partida rápida` / `Modo mánager` ya llegaron en #5336,
y el selector de seis clubes ficticios con estilos y objetivos en #5337.
La primera liga estadística reversible se desarrolla en #5339: hasta que
supere la CI y la revisión visual, no se debe presentar como carrera
persistente ni como simulación enlazada a partidos Godot. El modo conserva
la inspiración de gestión futbolística clásica, sin copiar interfaces,
marcas, plantillas o contenido protegido de terceros. El partido Godot
sigue jugable de forma independiente.

### Bucle de juego

1. Elegir un club ficticio y empezar la temporada con objetivos deportivos
   y financieros visibles.
2. Gestionar una plantilla con posiciones, atributos, forma, cansancio,
   estado físico, moral, potencial, edad, contratos y salarios.
3. Preparar alineación, banquillo, táctica y entrenamientos; decidir
   fichajes, ventas y renovaciones dentro de un presupuesto real.
4. Avanzar un calendario con liga, clasificación, resultados, sanciones,
   lesiones y evolución de jugadores; premios/pérdidas justificados por
   hechos simulados, no eventos inventados tras el resultado.
5. Para cada encuentro, **jugar** con el motor actual, **ver** el partido
   o **simularlo** y recibir una crónica basada en los eventos reales.
6. Cobrar ingresos, pagar nóminas, responder a objetivos de directiva y
   afrontar el mercado siguiente; nueva temporada con persistencia.

### Economía y simulación

- Moneda única clara, balances explicables, ingresos de taquilla,
  patrocinio y premios, gastos de plantilla y traspasos, deuda/límites
  y prohibición de dinero infinito generado por trucos de UI.
- El motor de simulación de resultados debe usar atributos, tácticas,
  fatiga, localía y azar controlado. No presentar resultados aleatorios
  puros como si respondieran a las decisiones tácticas del usuario.
- Historial y estadísticas de jugadores/clubes sólo cuando existan datos
  calculados o persistidos; rankings y narrativas nunca se inventan.
- Los partidos **jugados** reportarán un resultado final al calendario
  una única vez (idempotencia); los **simulados** no fingirán que hubo
  acciones del jugador. Evitar que dos modelos otorguen recompensas
  o actualicen la clasificación dos veces.
- Guardados versionados, recuperación tras F5, sin cambios destructivos
  sobre partidas rápidas o partidas de Football preexistentes.

### Progresión incremental (alineada con el backlog vivo #34)

- **Slice 0 · El veneno de «una jornada más»**: seis clubes ficticios,
  calendario de ida/vuelta reproducible, motor estadístico con seed
  inyectable, resultados y clasificación. Sin backend, Web Storage,
  economía o plantillas persistentes todavía. Primero demostrar que el
  calendario y la tabla ya enganchan **sin render de partidos**.
- **Slice 1 · Plantillas y decisiones**: futbolistas con atributos
  estrictamente futbolísticos, forma, fatiga, moral, edad y potencial;
  alineaciones y tácticas con consecuencias medibles. Las piezas de
  ajedrez sólo dan identidad y arquetipos: nunca reglas de movimiento.
- **Slice 2 · Carrera del mánager**: mercado, contratos, cantera,
  salarios, economía y temporadas encadenadas sólo después de
  validar los dos slices anteriores.
- **Integración Godot en HOLD para el mánager**: el partido Godot ya
  existe como experiencia separada; enlazarlo al calendario
  (Jugar/Ver/Simular y un `MatchResult` único) sólo cuando el motor
  estadístico sea la autoridad y el loop de gestión esté validado.
- **Profundidad opcional posterior**: divisiones, ascensos/descensos,
  directiva, patrocinadores e instalaciones; evitar complejidad
  antes de que las decisiones básicas sean divertidas.

El diseño y la prioridad de estos slices ya viven en
[Backlog vivo · Chess Studio #34](https://github.com/evilsysadmin/chess-studio/issues/34).
Este documento precisa el contrato de producto, **no crea una segunda
hoja de ruta ni autoriza implementarlo todo de golpe**.

### Límites de UX y arquitectura

- No convertir la pantalla actual de partido en un menú de contabilidad:
  el acceso al despacho será un **modo separado y opcional**.
- Mostrar primero las decisiones de la jornada y los indicadores
  esenciales. Estadísticas densas, libro mayor, scouting e historial
  detrás de vistas de detalle. Legible en móvil.
- Un solo calendario y una única autoridad de estado por temporada.
  Mantener el render 3D, el núcleo deportivo y la gestión desacoplados.
- Los clubes/jugadores ficticios evitan dependencia de licencias deportivas.
- Entregar en PR pequeñas: contrato de datos → simulación verificable →
  interfaz → vínculo con partidos → profundidad económica. No arrancar
  directamente con una gran reescritura.

## Catálogo de scouting v1 (54 jugadores)

Los seis clubes oficiales tienen ahora nueve futbolistas de identidad estable, nombre
ficticio propio, edad, mini-biografía y siete atributos de 1 a 99: velocidad,
resistencia, técnica, pase, remate, defensa y portería. La GRL es una lectura
ponderada por posición, no una media aritmética universal. El catálogo está en
`frontend/src/footballPlayerProfiles.js`, indexado en el mismo orden y con los
mismos IDs de `footballManagerRoster.js` para conservar las carreras.

**Límite deliberado:** estas siete cifras son todavía *scouting* y NO influyen
en el partido Godot ni en los resultados de liga; la simulación estadística
mantiene exactamente los valores históricos ATQ/DEF y su desarrollo, fatiga,
tácticas y journal. La siguiente PR podrá conectar atributos concretos a acciones
reales en Godot con calibración, prueba visual y contrato de integración, sin
alterar silenciosamente resultados guardados. Las fichas se consultan desde la
selección de club y la plantilla del despacho.

## Slice siguiente · atributos físicos del partido rápido

La fuente única de las 54 fichas es `frontend/src/footballManagerRoster.js`.
`node scripts/generate_football_match_rosters.mjs` exporta todas las
identidades y atributos a `games/chess-football-godot/data/scouting_rosters_v1.json`.
Un test compara los bytes generados con el repositorio en cada PR, evitando
que Godot y el mánager puedan divergir silenciosamente.

En el partido rápido actual, los **cinco titulares de FC Matthias y de
Real Enroque** ya aplican velocidad (±10 % sobre el desplazamiento de
campo; no se altera el movimiento especial del portero) y resistencia
(de −10 % a +20 % sobre el desgaste al esprintar). Se aplican igual al futbolista
controlado por humanos y por la IA. Los otros cuatro clubes y los suplentes
están preparados en el catálogo, pero todavía no hay selector de equipos
ni sustituciones en Godot. Técnica/pase/remate/defensa/portería siguen
sin afectar a la simulación física hasta slices específicos posteriores.

La simulación estadística y la validación/reproducción de carreras mánager
no consumen estos nuevos multiplicadores ni cambian los resultados previos.

## Partida rápida · dificultad de CPU
Antes del partido, el jugador elige Fácil / Normal / Difícil / Experto.
La opción se transmite al export de Godot con un fragmento URL
`#football-difficulty=...` validado por ambos lados: no se envía a R2
ni exige conexiones entre dominios. Los valores desconocidos y las
ejecuciones nativas se comportan como Normal.

Los niveles cambian únicamente a la CPU de Real Enroque: intervalo
de decisión, radio de presión, esfuerzo en defensa/ataque y distancia
desde la que intenta rematar. Normal preserva los parámetros históricos.
La dificultad no altera los atributos físicos individuales, el portero,
el movimiento del balón, los compañeros del jugador ni las carreras mánager.
La adaptación táctica durante el partido se mantiene encima de cada nivel.
