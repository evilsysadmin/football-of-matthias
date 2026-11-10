import { lazy, Suspense, useEffect, useLayoutEffect, useRef, useState } from 'react';
import { requestWarRoomLandscapeFullscreen } from './useWarRoomImmersive.js';
import {readFootballCloudCareer,writeFootballCloudCareer} from '../footballCareerCloud.js';
import { FOOTBALL_MANAGER_CLUBS, getFootballManagerClub } from '../footballManagerClubs.js';
import { footballStandings, FOOTBALL_MANAGER_TACTICS } from '../footballManagerSeason.js';
import { footballClubObjectiveReport } from '../footballManagerObjectives.js';
import { FOOTBALL_TRAINING_PLANS } from '../footballManagerTraining.js';
import { getDevelopedFootballRoster, FOOTBALL_MAX_GROWTH_PER_ATTRIBUTE } from '../footballManagerDevelopment.js';
import { createFootballCareer, editFootballCareer, playFootballCareerRound, startNextFootballSeason, FOOTBALL_CAREER_MAX_SEASONS, readFootballCareer, replayFootballCareer, writeFootballCareer } from '../footballManagerCareer.js';
import { getFootballClubRoster, getDefaultFootballLineup, FOOTBALL_FIVE_POSITIONS, getFootballFatigue } from '../footballManagerRoster.js';
import { FOOTBALL_SCOUTING_ATTRIBUTES } from '../footballPlayerProfiles.js';
import { FOOTBALL_QUICK_DIFFICULTIES, DEFAULT_FOOTBALL_QUICK_DIFFICULTY } from '../footballQuickDifficulty.js';
import { resolveChessFootballGodotUrl } from '../chessFootballGodotRuntime.js';
import { FOOTBALL_BUILD_ID } from '../releaseUpdate.js';
import './ChessFootballEntry.css';
import './FootballHome.css';
import './FootballQuickSetup.css';
import ReleaseUpdateNotice from './ReleaseUpdateNotice.jsx';
import FootballSaveTransfer from './FootballSaveTransfer.jsx';
import FootballManagerDesk from './FootballManagerDesk.jsx';

const ChessFootballGodotHost = lazy(() => import('./ChessFootballGodotHost.jsx'));

// Support feedback about an apparently unchanged match without adding
// anything to the playable pitch. Fetch the protected runtime manifest only
// after the player explicitly opens this compact pre-match diagnostic.
function FootballQuickVersionDetails() {
  const [open, setOpen] = useState(false);
  const [runtime, setRuntime] = useState(null);
  useEffect(() => {
    if (!open) return undefined;
    let active = true;
    setRuntime(null);
    resolveChessFootballGodotUrl().then((value) => {
      if (active) setRuntime(value);
    });
    return () => { active = false; };
  }, [open]);
  const loadedSha = FOOTBALL_BUILD_ID;
  const runtimeSha = runtime?.sourceSha || '';
  const mismatch = Boolean(loadedSha && runtimeSha && loadedSha !== runtimeSha);
  return (
    <details className="chess-football-entry__quick-version" onToggle={(event) => setOpen(event.currentTarget.open)}>
      <summary>Versión del partido</summary>
      {open ? (
        <div className="chess-football-entry__quick-version-content">
          <p>Menú cargado: <code>{loadedSha ? loadedSha.slice(0, 12) : 'Desarrollo local'}</code></p>
          <p>Motor anunciado: <code>{runtime === null ? 'Comprobando…' : runtimeSha ? runtimeSha.slice(0, 12) : 'No verificable'}</code></p>
          {runtime?.release ? <p>Release Godot: <code>{runtime.release}</code></p> : null}
          {mismatch ? (
            <p role="alert">El menú y el motor anuncian versiones distintas. Vuelve al vestuario y actualiza antes de comparar cambios.</p>
          ) : null}
          <small>Lecturas del navegador y del manifiesto; no prueban el despliegue.</small>
        </div>
      ) : null}
    </details>
  );
}

function FootballSquadDevelopment({ players }) {
  const grown = players.filter((player) => player.attackGrowth || player.defenseGrowth).length;
  return (
    <details className="chess-football-entry__development" aria-label="Fichas de la plantilla">
      <summary>Plantilla · {players.length} futbolistas{grown ? ` · ${grown} mejorados` : ''}</summary>
      <p>Abre cada ficha para ver su biografía y sus siete atributos (1–99). La GRL pondera su posición. En Partido rápido, los siete atributos ya influyen en el partido (velocidad, resistencia, técnica, pase, remate, defensa y portería). La liga mánager sigue usando ATQ, DEF y fatiga.</p>
      <ul>
        {players.map((player) => (
          <li key={player.id}>
            <details className="chess-football-entry__player-card">
              <summary>
                <span><strong>{player.name}</strong><small>{player.role} · {player.age} años · {player.starts} titularidades</small></span>
                <b>GRL {player.overall}</b>
              </summary>
              <p>{player.bio}</p>
              <dl className="chess-football-entry__scouting">
                {FOOTBALL_SCOUTING_ATTRIBUTES.map(({ key, label }) => (
                  <div key={key}><dt>{label}</dt><dd>{player.scouting[key]}</dd></div>
                ))}
              </dl>
              <p className="chess-football-entry__player-growth">
                Simulación actual: ATQ {player.attack}{player.attackGrowth ? ` (+${player.attackGrowth})` : ''} · DEF {player.defense}{player.defenseGrowth ? ` (+${player.defenseGrowth})` : ''}
              </p>
            </details>
          </li>
        ))}
      </ul>
    </details>
  );
}

export default function ChessFootballEntry({ onExit, careerStorage='local' }) {
  const [view, setView] = useState('welcome');
  const [welcomeArtAvailable, setWelcomeArtAvailable] = useState(true);
  const [quickDifficulty, setQuickDifficulty] = useState(DEFAULT_FOOTBALL_QUICK_DIFFICULTY);
  const scrollSurface = useRef(null);
  const [selectedClubId, setSelectedClubId] = useState(null);
  const [season, setSeason] = useState(null);
  const [tactic, setTactic] = useState('balanced');
  const [lineupIds, setLineupIds] = useState(null);
  const [journal, setJournal] = useState(null);
  const [careerHistory, setCareerHistory] = useState([]);
  const [savedCareer, setSavedCareer] = useState(() => careerStorage==='mongo'?{status:'loading'}:readFootballCareer());
  const cloudRevision=useRef(null);
  const saving=useRef(false);
  const [replacePending, setReplacePending] = useState(false);
  const [saveStatus, setSaveStatus] = useState(null);
  const selectedClub = getFootballManagerClub(selectedClubId);
  const roster = selectedClub ? getFootballClubRoster(selectedClub) : [];
  const developedRoster = getDevelopedFootballRoster(roster, season?.managerDevelopment);
  const defaultLineup = selectedClub ? getDefaultFootballLineup(roster) : [];
  const startingFive = lineupIds || defaultLineup;
  const standings = season ? footballStandings(season) : [];
  const objective = season && selectedClubId ? footballClubObjectiveReport(season, selectedClubId) : null;
  const seasonNumber = (journal?.completedSeasons?.length || 0) + 1;
  const navigateManagerDesk = (area) => {
    const root = scrollSurface.current;
    const target = root?.querySelector('[data-manager-section="' + area + '"]')
      || (area === 'results' && root?.querySelector('[data-manager-section="fixtures"]'))
      || (area === 'plan' && root?.querySelector('[data-manager-section="objective"]'));
    if (!target) return;
    if (area === 'squad') target.querySelector('details')?.setAttribute('open', '');
    target.scrollIntoView({ block: 'start', behavior: 'auto' });
    target.focus({ preventScroll: true });
  };

  // Each new room starts at its entrance. Reusing this mounted full-screen
  // scroller otherwise carries a deep standings offset back into Welcome.
  useLayoutEffect(() => {
    if (view !== 'match' && scrollSurface.current) scrollSurface.current.scrollTop = 0;
  }, [view]);

  useEffect(()=>{
    if(careerStorage!=='mongo')return;
    let live=true;
    readFootballCloudCareer().then(saved=>{
      if(!live)return;
      cloudRevision.current=saved.status==='future'?null:saved.revision;
      setSavedCareer(saved);
    }).catch(()=>{
      if(!live)return;
      cloudRevision.current=null;
      setSavedCareer({status:'unavailable'});
    });
    return()=>{live=false;cloudRevision.current=null;};
  },[careerStorage]);

  const showCareer = ({ journal: nextJournal, season: nextSeason, history = [] }) => {
    setCareerHistory(history);
    setSelectedClubId(nextJournal.clubId);
    setJournal(nextJournal);
    setSeason(nextSeason);
    setTactic(nextJournal.nextTactic);
    setLineupIds(nextJournal.nextLineup);
    setView('season');
  };

  const persistCareer = async (next) => {
    if(careerStorage!=='mongo'){
      const outcome=writeFootballCareer(next.journal);
      if(outcome.status==='saved'||outcome.status==='memory')setSavedCareer({status:'available',...next});
      setSaveStatus(outcome.status);
      return outcome;
    }
    if(saving.current||cloudRevision.current===null||!['available','empty'].includes(savedCareer.status)){
      setSaveStatus('unavailable');
      return {status:'unavailable'};
    }
    saving.current=true;
    try{
      const outcome=await writeFootballCloudCareer(next.journal,cloudRevision.current);
      cloudRevision.current=outcome.revision;
      setSavedCareer({status:'available',...next});
      setSaveStatus('cloud');
      return outcome;
    }catch(error){
      // A failed write must not mutate the local backup or pretend it is synced.
      // Re-load explicitly after a conflict/outage rather than guessing a winner.
      cloudRevision.current=null;
      setSaveStatus(error.code==='conflict'?'conflict':'unavailable');
      return {status:error.code==='conflict'?'conflict':'unavailable'};
    }finally{saving.current=false;}
  };

  const continueCareer = () => {
    const restored=careerStorage==='mongo'?savedCareer:readFootballCareer();
    setSavedCareer(restored);
    if(restored.status==='available'){
      setSaveStatus(null);
      showCareer(restored);
    }
  };

  const confirmNewSeason = async () => {
    if (!selectedClub || !['available','empty','invalid'].includes(savedCareer.status)) return;
    const start = createFootballCareer(selectedClub.id);
    const next = replayFootballCareer(start);
    const result = await persistCareer(next);
    if (!['saved','memory','cloud'].includes(result.status)) return;
    setReplacePending(false);
    showCareer(next);
  };

  const openSeasonPreview = () => {
    if (!['available','empty','invalid'].includes(savedCareer.status)) return;
    if (savedCareer.status !== 'empty') {
      setReplacePending(true);
      return;
    }
    confirmNewSeason();
  };

  const changeDraft = async (patch) => {
    if (!journal) return;
    const next = editFootballCareer(journal, patch);
    const outcome = await persistCareer(next);
    if (!['saved','memory','cloud'].includes(outcome.status)) return;
    showCareer(next);
  };

  const simulateNextRound = async () => {
    if (!journal) return;
    const next = playFootballCareerRound(journal);
    const outcome = await persistCareer(next);
    if (!['saved','memory','cloud'].includes(outcome.status)) return;
    showCareer(next);
  };

  const renewSeason = async () => {
    if (!journal || season?.currentRound !== 10 || seasonNumber >= FOOTBALL_CAREER_MAX_SEASONS) return;
    const next = startNextFootballSeason(journal);
    const outcome = await persistCareer(next);
    if (!['saved','memory','cloud'].includes(outcome.status)) return;
    showCareer(next);
    if (scrollSurface.current) scrollSurface.current.scrollTop = 0;
  };

  const startQuickMatch = () => {
    // Fullscreen/orientation require a real user gesture. Opening Football's
    // welcome screen should never rotate or lock the phone.
    const coarsePointer = typeof window.matchMedia === 'function'
      && window.matchMedia('(pointer: coarse)').matches;
    if (coarsePointer) {
      document.documentElement.dataset.chessFootballImmersive = 'requested';
      void requestWarRoomLandscapeFullscreen();
    }
    setView('match');
  };

  if (view === 'match') {
    return (
      <Suspense fallback={<div className="chess-football-entry__loading" role="status">Preparando el campo…</div>}>
        <ChessFootballGodotHost difficulty={quickDifficulty} onExit={() => setView('welcome')} />
      </Suspense>
    );
  }

  return (
    <main ref={scrollSurface} className="chess-football-entry" data-football-view={view} data-football-home-art={welcomeArtAvailable ? "available" : "missing"}>
      <div className="chess-football-entry__content">
        {view !== 'welcome' && (
          <button type="button" className="chess-football-entry__back" onClick={() => setView(view === 'season' ? 'club' : view === 'club' ? 'manager' : 'welcome')}>
            ← {view === 'season' ? 'Volver a la ficha' : view === 'club' ? 'Volver a los clubes' : 'Volver a Football'}
          </button>
        )}
        <header className="chess-football-entry__masthead">
          {view !== 'welcome' && <span className="chess-football-entry__eyebrow">{view === 'season' ? `Temporada ${seasonNumber}` : 'Football'}</span>}
          <h1>Football <em>of Matthias</em></h1>
          <p>Elige tu forma de vivir el fútbol. Un partido ahora, o la carrera de un club entero.</p>
        </header>

        {view === 'welcome' ? (
          <section className="chess-football-entry__welcome-scene" aria-label="Elige un modo de Football of Matthias">
            <img
              className="chess-football-entry__welcome-art"
              src="/football-home-v1.webp"
              alt=""
              aria-hidden="true"
              width="1672"
              height="941"
              decoding="async"
              fetchPriority="high"
              onError={() => setWelcomeArtAvailable(false)}
            />
            <button type="button" className="chess-football-entry__welcome-back" onClick={onExit}>← ShadowOps</button>
            <div className="chess-football-entry__choices">
              <button type="button" className="chess-football-entry__choice chess-football-entry__choice--quick" onClick={() => setView('quick-setup')}>
                <span className="chess-football-entry__choice-icon" aria-hidden="true">⚽</span>
                <small>Salta al campo</small>
                <strong>Partida rápida</strong>
                <span>Partido completo de 11 contra 11. Sin calendarios ni despachos: a jugar.</span>
                <b>Jugar ahora →</b>
              </button>
              <button type="button" className="chess-football-entry__choice chess-football-entry__choice--manager" onClick={() => setView('manager')}>
                <span className="chess-football-entry__choice-icon" aria-hidden="true">♚</span>
                <small>Dirige el club</small>
                <strong>Modo mánager</strong>
                <span>Construye tu equipo, prepara la temporada y decide el futuro del club.</span>
                <b>Entrar al despacho →</b>
              </button>
            </div>
            <div className="chess-football-entry__welcome-career">
              {savedCareer.status === 'available' ? (
                <div className="chess-football-entry__career-resume" aria-label="Temporada guardada">
                  <strong>{FOOTBALL_MANAGER_CLUBS.find((club) => club.id === savedCareer.journal.clubId)?.name}</strong>
                  <p>Temporada {(savedCareer.journal.completedSeasons?.length || 0) + 1} · Jornada {savedCareer.season.currentRound} de 10.</p>
                  <button type="button" className="chess-football-entry__manager-return" onClick={continueCareer}>Continuar temporada</button>
                </div>
              ) : savedCareer.status === 'future' ? (
                <p className="chess-football-entry__career-warning" role="status">Hay una carrera creada con una versión más nueva. Se conserva intacta; actualiza el juego para continuar.</p>
              ) : savedCareer.status === 'invalid' ? (
                <p className="chess-football-entry__career-warning" role="status">El último guardado no se puede leer. No se borrará hasta que confirmes una nueva temporada.</p>
              ) : savedCareer.status === 'loading' ? (
                <p role="status">Consultando tu carrera en Mongo…</p>
              ) : savedCareer.status === 'unavailable' ? (
                <p className="chess-football-entry__career-warning" role="alert">Mongo no está disponible. No se modificará tu carrera. Tus copias locales siguen intactas.</p>
              ) : null}
              <FootballSaveTransfer cloud={careerStorage==='mongo'} savedCareer={savedCareer}
                onImported={async journal=>persistCareer(replayFootballCareer(journal))} />
            </div>
          </section>        ) : view === 'quick-setup' ? (
          <section className="chess-football-entry__quick-setup" aria-labelledby="football-quick-setup-title">
            <div className="chess-football-entry__quick-brief">
              <div className="chess-football-entry__quick-intro">
                <span className="chess-football-entry__eyebrow">La previa · Partido rápido</span>
                <h2 id="football-quick-setup-title">Elige a tu rival</h2>
                <p>La dificultad cambia cómo juega la CPU. Tu once, las estadísticas y las reglas no cambian.</p>
                <div className="chess-football-entry__quick-fixture" aria-label="FC Matthias contra Real Enroque">
                  <strong>FC Matthias</strong><span aria-hidden="true">VS</span><strong>Real Enroque</strong>
                </div>
                <div className="chess-football-entry__quick-details">
                  <span>11 contra 11</span><span>Campo completo</span>
                </div>
              </div>
              <div className="chess-football-entry__quick-pitch" aria-hidden="true">
                <div className="chess-football-entry__quick-pitch-lines">
                  <span className="chess-football-entry__quick-pitch-midline" />
                  <span className="chess-football-entry__quick-pitch-circle" />
                  <span className="chess-football-entry__quick-pitch-box chess-football-entry__quick-pitch-box--left" />
                  <span className="chess-football-entry__quick-pitch-box chess-football-entry__quick-pitch-box--right" />
                  <i className="chess-football-entry__quick-pitch-dot chess-football-entry__quick-pitch-dot--one" />
                  <i className="chess-football-entry__quick-pitch-dot chess-football-entry__quick-pitch-dot--two" />
                  <i className="chess-football-entry__quick-pitch-dot chess-football-entry__quick-pitch-dot--three" />
                  <i className="chess-football-entry__quick-pitch-dot chess-football-entry__quick-pitch-dot--four" />
                </div>
                <small>La pizarra del míster · 11v11</small>
              </div>
            </div>
            <div className="chess-football-entry__quick-section-heading">
              <strong>Intensidad del rival</strong>
              <span>Selecciona una dificultad</span>
            </div>
            <div className="chess-football-entry__quick-levels" role="group" aria-label="Dificultad del rival">
              {FOOTBALL_QUICK_DIFFICULTIES.map(({ id, label, description }, index) => (
                <button key={id} type="button" aria-pressed={quickDifficulty === id}
                  className={`chess-football-entry__quick-level${quickDifficulty === id ? ' is-selected' : ''}`}
                  onClick={() => setQuickDifficulty(id)}>
                  <span className="chess-football-entry__quick-level-number" aria-hidden="true">{String(index + 1).padStart(2, '0')}</span>
                  <strong>{label}</strong>
                  <span>{description}</span>
                  <span className="chess-football-entry__quick-level-check" aria-hidden="true">✓</span>
                </button>
              ))}
            </div>
            <div className="chess-football-entry__quick-action-row">
              <p className="chess-football-entry__quick-selection" role="status" aria-live="polite">
                Rival seleccionado <strong>{FOOTBALL_QUICK_DIFFICULTIES.find(({ id }) => id === quickDifficulty)?.label}</strong>
              </p>
              <button type="button" className="chess-football-entry__quick-kickoff" onClick={startQuickMatch}>
                Saltar al campo · 11v11 · {FOOTBALL_QUICK_DIFFICULTIES.find(({ id }) => id === quickDifficulty)?.label}
              </button>
            </div>
            <details className="chess-football-entry__quick-controls">
              <summary>Controles del partido <span>Teclado y móvil</span></summary>
              <div className="chess-football-entry__quick-controls-grid">
                <div>
                  <strong>Teclado</strong>
                  <dl>
                    <div><dt>WASD / flechas</dt><dd>Mover</dd></div>
                    <div><dt>Shift</dt><dd>Esprintar</dd></div>
                    <div><dt>Espacio / Intro</dt><dd>Pasar / tirar</dd></div>
                    <div><dt>Q / V</dt><dd>Cambiar jugador / cámara</dd></div>
                    <div><dt>E</dt><dd>Amago parado, recorte corriendo o entrada defendiendo</dd></div>
                    <div><dt>Shift + E</dt><dd>Toque largo con balón o segada defendiendo</dd></div>
                  </dl>
                </div>
                <div>
                  <strong>Móvil y táctil</strong>
                  <dl>
                    <div><dt>Joystick izquierdo</dt><dd>Mover; doble toque y mantener para esprintar</dd></div>
                    <div><dt>Toca al compañero</dt><dd>Pasar</dd></div>
                    <div><dt>Toca la portería</dt><dd>Tirar</dd></div>
                    <div><dt>Toca al rival</dt><dd>Entrar al balón</dd></div>
                    <div><dt>Toca césped libre</dt><dd>Regatear</dd></div>
                  </dl>
                </div>
              </div>
              <p>Durante el encuentro, MENÚ pausa el partido. Los gestos cambian según tengas o no la posesión.</p>
            </details>
            <p className="chess-football-entry__quick-hint">Puedes volver a Football desde el menú del partido.</p>
            <FootballQuickVersionDetails />
          </section>
        ) : view === 'manager' ? (
          <section className="chess-football-entry__manager chess-football-entry__manager--selection" aria-labelledby="football-manager-title">
            <span className="chess-football-entry__eyebrow">Modo mánager · Pretemporada</span>
            <h2 id="football-manager-title">El despacho del míster</h2>
            <p>Elige tu club. Seis proyectos ficticios, seis maneras de complicarte la vida. Tu temporada estadística se guarda por perfil para poder continuarla.</p>
            <div className="chess-football-entry__clubs" aria-label="Clubes disponibles">
              {FOOTBALL_MANAGER_CLUBS.map((club) => (
                <button
                  type="button"
                  className="chess-football-entry__club"
                  key={club.id}
                  onClick={() => { setSelectedClubId(club.id); setSeason(null); setLineupIds(null); setReplacePending(false); setTactic('balanced'); setView('club'); }}
                  aria-label={`Elegir ${club.name}`}
                >
                  <span className="chess-football-entry__crest" aria-hidden="true">{club.initials}</span>
                  <strong>{club.name}</strong>
                  <span>{club.style}</span>
                  <small>{'★'.repeat(club.level)}{'☆'.repeat(5 - club.level)}</small>
                </button>
              ))}
            </div>
            <button type="button" className="chess-football-entry__manager-return" onClick={() => setView('welcome')}>Volver a elegir modo</button>
          </section>
        ) : view === 'club' ? (
          <section className="chess-football-entry__manager" aria-labelledby="football-club-review-title">
            <span className="chess-football-entry__eyebrow">Modo mánager · Club elegido</span>
            <h2 id="football-club-review-title">{selectedClub?.name || 'Selecciona un club'}</h2>
            {selectedClub ? (
              <div className="chess-football-entry__club-summary">
                <p><strong>Estilo:</strong> {selectedClub.style}</p>
                <p><strong>Objetivo propuesto:</strong> {selectedClub.objective}</p>
                <p>Liga de seis clubes y diez jornadas, con quinteto y fatiga. La carrera se guarda {careerStorage==='mongo'?'en Mongo con tu ShadowOps ID':'en este dispositivo'}; los partidos Godot aún van por separado.</p>
              </div>
            ) : null}
            {selectedClub ? <FootballSquadDevelopment players={developedRoster} /> : null}
            {replacePending ? (
              <div className="chess-football-entry__career-confirm" role="group" aria-label="Confirmar nueva temporada">
                <p>Ya existe una carrera guardada. Crear otra sustituirá su historial, resultados y fatiga. Esta acción no se puede deshacer.</p>
                <button type="button" className="chess-football-entry__manager-return" onClick={confirmNewSeason}>Confirmar nueva temporada</button>
                <button type="button" className="chess-football-entry__manager-return is-secondary" onClick={() => setReplacePending(false)}>Conservar la anterior</button>
              </div>
            ) : (
              <button type="button" className="chess-football-entry__manager-return" disabled={!['empty','available','invalid'].includes(savedCareer.status)} onClick={openSeasonPreview}>Empezar temporada de prueba</button>
            )}
            <button type="button" className="chess-football-entry__manager-return is-secondary" onClick={() => setView('manager')}>Cambiar de club</button>
          </section>
        ) : (
          <section className="chess-football-entry__manager chess-football-entry__manager--season" aria-labelledby="football-season-title">
            <span className="chess-football-entry__eyebrow">Temporada {seasonNumber} de {FOOTBALL_CAREER_MAX_SEASONS} · Carrera del club</span>
            <h2 id="football-season-title">{selectedClub?.name || 'Mi club'}</h2>
            <FootballManagerDesk club={selectedClub} season={season} standings={standings} onNavigate={navigateManagerDesk} />
            {careerHistory.length ? (
              <details className="chess-football-entry__history" aria-label="Historial del club">
                <summary>Archivo de temporadas · {careerHistory.length} {careerHistory.length === 1 ? "completada" : "completadas"}</summary>
                <ol>{careerHistory.map((year) => (
                  <li key={year.number}>
                    Temporada {year.number} · {year.position}.º puesto · {year.points} puntos · {year.objectiveMet ? 'Objetivo cumplido' : 'Objetivo no alcanzado'}
                  </li>
                ))}</ol>
              </details>
            ) : null}
            {saveStatus === 'saved' ? <p className="chess-football-entry__save-state" role="status">Progreso guardado en este dispositivo.</p> : null}
            {saveStatus === 'cloud' ? <p className="chess-football-entry__save-state" role="status">Carrera guardada en Mongo con tu ShadowOps ID.</p> : null}
            {saveStatus === 'conflict' ? <p className="chess-football-entry__career-warning" role="alert">La carrera ha cambiado en otro dispositivo. Recarga antes de continuar; tus datos remotos no se han sobrescrito.</p> : null}
            {saveStatus === 'unavailable' ? <p className="chess-football-entry__career-warning" role="alert">No se ha podido guardar. Mongo no ha confirmado los cambios. Recarga cuando vuelva el servicio.</p> : null}
            {saveStatus === 'memory' ? <p className="chess-football-entry__career-warning" role="status">El almacenamiento está bloqueado: los cambios sólo están disponibles en esta pestaña.</p> : null}
            {objective ? (
              <section className="chess-football-entry__objective" aria-label="Objetivo del club" data-manager-section="objective" tabIndex={-1}>
                <div className="chess-football-entry__objective-heading">
                  <strong>Objetivo del club · {objective.title}</strong>
                  <span>{objective.statusLabel}</span>
                </div>
                <p>{objective.detail}</p>
                <p className="chess-football-entry__objective-progress">{objective.progress}</p>
              </section>
            ) : null}
            <table className="chess-football-entry__standings" aria-label="Clasificación de liga" data-manager-section="table" tabIndex={-1}>
              <thead><tr><th scope="col">#</th><th scope="col">Club</th><th scope="col">PJ</th><th scope="col">Pts</th></tr></thead>
              <tbody>
                {standings.map((club, index) => (
                  <tr key={club.id} className={club.id === selectedClubId ? 'is-my-club' : ''}>
                    <td>{index + 1}</td><th scope="row">{club.name}</th><td>{club.played}</td><td>{club.points}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            {season && season.currentRound < season.rounds.length ? (
              <section className="chess-football-entry__lineup" aria-label="Alineación del míster" data-manager-section="squad" tabIndex={-1}>
                <details>
                  <summary>Preparar quinteto titular</summary>
                  <p>Fútbol 5: portero, defensa, dos medios y delantero. Cada jornada suma 17 puntos de cansancio a los titulares y recupera 22 a los suplentes. La fatiga reduce su rendimiento hasta que roten.</p>
                  <div className="chess-football-entry__lineup-slots">
                    {startingFive.map((playerId, index) => {
                      const player = developedRoster.find((entry) => entry.id === playerId);
                      if (!player) return null;
                      return (
                        <label key={index}>
                          <span className="chess-football-entry__slot-label">
                            {FOOTBALL_FIVE_POSITIONS[player.role]} {player.role === 'MED' ? (index === 2 ? '1' : '2') : ''}
                            <b className="chess-football-entry__slot-fatigue">Fatiga {getFootballFatigue(season.managerFatigue, player.id)}%</b>
                          </span>
                          <select
                            aria-label={`Titular ${index + 1} · ${player.role}`}
                            value={playerId}
                            onChange={(event) => {
                              const nextId = event.target.value;
                              const next = [...startingFive];
                              next[index] = nextId;
                              changeDraft({ lineup: next });
                            }}
                          >
                            {developedRoster.filter((candidate) => candidate.role === player.role).map((candidate) => (
                              <option key={candidate.id} value={candidate.id} disabled={startingFive.includes(candidate.id) && candidate.id !== playerId}>
                                {candidate.name} · ATQ {candidate.attack} / DEF {candidate.defense} · F{getFootballFatigue(season.managerFatigue, candidate.id)}%
                              </option>
                            ))}
                          </select>
                        </label>
                      );
                    })}
                  </div>
                  <FootballSquadDevelopment players={developedRoster} />
                </details>
              </section>
            ) : null}
            {season && season.currentRound < season.rounds.length ? (
              <section className="chess-football-entry__plan" aria-label="Plan del míster para la próxima jornada" data-manager-section="plan" tabIndex={-1}>
                <h3>Tu planteamiento</h3>
                <p>Elige cómo afrontará tu club el próximo encuentro. Sólo afecta a tu partido; los demás siguen su simulación normal.</p>
                <div className="chess-football-entry__plan-options" role="group" aria-label="Táctica del siguiente partido">
                  {FOOTBALL_MANAGER_TACTICS.map((plan) => (
                    <button
                      key={plan.id}
                      type="button"
                      aria-pressed={tactic === plan.id}
                      className="chess-football-entry__plan-option"
                      onClick={() => changeDraft({ tactic: plan.id })}
                    >{plan.label}</button>
                  ))}
                </div>
                <p className="chess-football-entry__plan-effect" role="status">
                  {FOOTBALL_MANAGER_TACTICS.find((plan) => plan.id === tactic)?.description}
                </p>
              </section>
            ) : null}
            {season && season.currentRound < season.rounds.length ? (
              <section className="chess-football-entry__training" aria-label="Entrenamiento de la jornada">
                <details>
                  <summary>Preparar entrenamiento · {FOOTBALL_TRAINING_PLANS.find((plan) => plan.id === journal?.nextTraining)?.label || 'Rutina normal'}</summary>
                  <p>Una sesión antes del partido: más ataque, más defensa o recuperación. El esfuerzo también se paga con cansancio.</p>
                  <div className="chess-football-entry__training-options" role="group" aria-label="Plan de entrenamiento">
                    {FOOTBALL_TRAINING_PLANS.map((plan) => (
                      <button type="button" key={plan.id}
                        className="chess-football-entry__training-option"
                        aria-pressed={journal?.nextTraining === plan.id}
                        onClick={() => changeDraft({ training: plan.id })}
                      >{plan.label}</button>
                    ))}
                  </div>
                  <p role="status">{FOOTBALL_TRAINING_PLANS.find((plan) => plan.id === journal?.nextTraining)?.description}</p>
                </details>
              </section>
            ) : null}
            {season && season.currentRound < season.rounds.length ? (
              <div className="chess-football-entry__fixture-list" aria-label="Próxima jornada" data-manager-section="fixtures" tabIndex={-1}>
                <h3>Próxima jornada</h3>
                {season.rounds[season.currentRound].map((fixture) => (
                  <p key={fixture.id}>{season.clubs.find((club) => club.id === fixture.homeId)?.name} – {season.clubs.find((club) => club.id === fixture.awayId)?.name}</p>
                ))}
              </div>
            ) : (
              <section className="chess-football-entry__lineup" aria-label="Plantilla al cierre" data-manager-section="squad" tabIndex={-1}>
                <p>Temporada completada. La clasificación final ya está calculada.</p>
                <FootballSquadDevelopment players={developedRoster} />
              </section>
            )}
            {season?.currentRound === season?.rounds.length && season ? (
              <section className="chess-football-entry__renewal" aria-label="Cierre de temporada">
                <strong>Temporada {seasonNumber} completada · {objective?.position}.º puesto</strong>
                <p>{objective?.statusLabel}. Tus futbolistas mantienen las mejoras ganadas, el cansancio se recupera en pretemporada y el calendario siguiente tendrá un nuevo sorteo reproducible.</p>
                {seasonNumber < FOOTBALL_CAREER_MAX_SEASONS ? (
                  <button type="button" className="chess-football-entry__manager-return" onClick={renewSeason}>
                    Comenzar temporada {seasonNumber + 1}
                  </button>
                ) : <p>Has completado las {FOOTBALL_CAREER_MAX_SEASONS} temporadas de esta primera carrera. Su historial permanece guardado.</p>}
              </section>
            ) : null}
            {season?.results.length ? (
              <div className="chess-football-entry__fixture-list" aria-label="Resultados de la última jornada" data-manager-section="results" tabIndex={-1}>
                <h3>Últimos resultados</h3>
                {season.results.slice(-3).map((result) => (
                  <p key={result.fixtureId}>
                    {season.clubs.find((club) => club.id === result.homeId)?.name} {result.homeGoals}–{result.awayGoals} {season.clubs.find((club) => club.id === result.awayId)?.name}
                    {result.managerLineup?.some((id, slot) => id !== defaultLineup[slot]) ? (
                      <span className="chess-football-entry__used-plan"> · Quinteto alternativo</span>
                    ) : null}
                    {result.managerFatigueAtKickoff > 0 ? (
                      <span className="chess-football-entry__used-plan"> · Fatiga inicial media: {Math.round(result.managerFatigueAtKickoff)}%</span>
                    ) : null}
                    {result.managerTraining && result.managerTraining !== 'standard' ? (
                      <span className="chess-football-entry__used-plan"> · Entreno: {FOOTBALL_TRAINING_PLANS.find((plan) => plan.id === result.managerTraining)?.label}</span>
                    ) : null}
                    {result.managerTactic ? (
                      <span className="chess-football-entry__used-plan">
                        {' · Plan: '}{FOOTBALL_MANAGER_TACTICS.find((plan) => plan.id === result.managerTactic)?.label}
                      </span>
                    ) : null}
                  </p>
                ))}
              </div>
            ) : null}
            <button
              type="button"
              className="chess-football-entry__manager-return"
              disabled={!season || season.currentRound >= season.rounds.length}
              onClick={simulateNextRound}
            >
              {season?.currentRound >= season?.rounds.length ? 'Liga completada' : 'Simular siguiente jornada'}
            </button>
          </section>
        )}
      </div>
      <ReleaseUpdateNotice deferReload={view !== 'welcome'} />
    </main>
  );
}
