import { useEffect, useRef, useState } from 'react';
import { resolveChessFootballGodotUrl } from '../chessFootballGodotRuntime.js';
import { footballQuickMatchUrl } from '../footballQuickDifficulty.js';
import { FOOTBALL_POSE_TEAMS, FOOTBALL_POSE_ACTIONS, FOOTBALL_POSE_TOTAL,
  footballPoseTeamCount, parseFootballPoseReceipt } from '../footballActionPoseStatus.js';
import { exitWarRoomBrowserFullscreen, requestWarRoomLandscapeFullscreen, unlockWarRoomOrientation } from './useWarRoomImmersive.js';
import './ChessFootballGodotHost.css';

function releaseChessFootballImmersiveMode() {
  const html = document.documentElement;
  if (html.dataset.chessFootballImmersive !== 'requested') return;

  delete html.dataset.chessFootballImmersive;
  unlockWarRoomOrientation();
  void exitWarRoomBrowserFullscreen();
}

function readMobileViewport() {
  if (typeof window === 'undefined') return { coarse: false, portrait: false };
  const coarse = typeof window.matchMedia === 'function'
    && window.matchMedia('(pointer: coarse)').matches;
  return {
    coarse,
    portrait: window.innerHeight > window.innerWidth,
  };
}

export default function ChessFootballGodotHost({ onExit, difficulty = 'normal' }) {
  const frameRef = useRef(null);
  const [attempt, setAttempt] = useState(0);
  const [runtimeReady, setRuntimeReady] = useState(false);
  const [poseInstalled, setPoseInstalled] = useState([]);
  const [poseScanFinished, setPoseScanFinished] = useState(false);
  const [bootFailed, setBootFailed] = useState(false);
  const [mobileViewport, setMobileViewport] = useState(readMobileViewport);
  const [runtime, setRuntime] = useState({
    url: '',
    source: 'resolving',
    release: '',
  });

  useEffect(() => {
    const refreshViewport = () => setMobileViewport(readMobileViewport());
    refreshViewport();
    window.addEventListener('resize', refreshViewport);
    window.addEventListener('orientationchange', refreshViewport);
    return () => {
      window.removeEventListener('resize', refreshViewport);
      window.removeEventListener('orientationchange', refreshViewport);
    };
  }, []);

  useEffect(() => {
    const html = document.documentElement;
    const body = document.body;
    const previousHtmlOverflow = html.style.overflow;
    const previousBodyOverflow = body.style.overflow;
    html.style.overflow = 'hidden';
    body.style.overflow = 'hidden';
    return () => {
      html.style.overflow = previousHtmlOverflow;
      body.style.overflow = previousBodyOverflow;

      // StrictMode can run an effect cleanup immediately after mount. Defer the
      // fallback release and only apply it if Football genuinely disappeared.
      window.setTimeout(() => {
        if (!document.querySelector('.chess-football-godot-host')) {
          releaseChessFootballImmersiveMode();
        }
      }, 0);
    };
  }, []);

  useEffect(() => {
    const handleRuntimeMessage = (event) => {
      if (event.source !== frameRef.current?.contentWindow) return;
      const message = event.data;
      if (!message || message.source !== 'chess-football-godot') return;
      if (message.type === 'ready') {
        // XI-only quick matches reject any legacy five-a-side handshake.
        if (message.team_size !== 11) {
          setRuntimeReady(false);
          setBootFailed(true);
          return;
        }
        setBootFailed(false);
        setRuntimeReady(true);
      } else if (message.type === 'action-poses-status') {
        // The iframe alone owns these installed SpriteFrames. Never infer
        // success from an HTTP 200, and never trust another frame/origin.
        if (event.origin !== 'https://assets.chess-studio.shadowops.dpdns.org') return;
        const installed = parseFootballPoseReceipt(message);
        if (installed) setPoseInstalled(installed);
      } else if (message.type === 'exit') {
        releaseChessFootballImmersiveMode();
        onExit?.();
      }
    };
    window.addEventListener('message', handleRuntimeMessage);
    return () => window.removeEventListener('message', handleRuntimeMessage);
  }, [onExit]);

  useEffect(() => {
    let cancelled = false;
    setRuntimeReady(false);
    setBootFailed(false);
    setPoseInstalled([]);
    setPoseScanFinished(false);
    setRuntime({ url: '', source: 'resolving', release: '' });
    resolveChessFootballGodotUrl().then((resolved) => {
      if (!cancelled) setRuntime(resolved);
    });
    return () => { cancelled = true; };
  }, [attempt]);

  // Each optional R2 sheet has an 8-second loader deadline. An absent
  // receipt is displayed as "not confirmed", never invented as a success.
  useEffect(() => {
    if (!runtimeReady) return undefined;
    const timer = window.setTimeout(() => setPoseScanFinished(true), 11000);
    return () => window.clearTimeout(timer);
  }, [runtimeReady, attempt]);

  // Godot is hosted in a cross-origin iframe. When it becomes ready,
  // keyboard focus must move into the game rather than remain on the
  // outer welcome-screen button. Leave touch/pointer focus unchanged.
  useEffect(() => {
    if (!runtimeReady || mobileViewport.coarse) return;
    const frame = frameRef.current;
    if (frame && document.activeElement !== frame) frame.focus({ preventScroll: true });
  }, [runtimeReady, mobileViewport.coarse]);

  useEffect(() => {
    if (!runtime.url || runtimeReady) return undefined;
    const timeout = window.setTimeout(() => setBootFailed(true), 20000);
    return () => window.clearTimeout(timeout);
  }, [runtime.url, runtimeReady]);

  const exitFootball = () => {
    releaseChessFootballImmersiveMode();
    onExit?.();
  };

  useEffect(() => {
    if (runtimeReady) return undefined;
    const escapeDuringBoot = (event) => {
      if (event.key === 'Escape') {
        event.stopImmediatePropagation();
        event.preventDefault();
        exitFootball();
      }
    };
    window.addEventListener('keydown', escapeDuringBoot, true);
    return () => window.removeEventListener('keydown', escapeDuringBoot, true);
  }, [runtimeReady, onExit]);

  const requestLandscape = () => {
    document.documentElement.dataset.chessFootballImmersive = 'requested';
    void requestWarRoomLandscapeFullscreen();
  };

  const mobilePortrait = mobileViewport.coarse && mobileViewport.portrait;
  const matchUrl = footballQuickMatchUrl(runtime.url, difficulty);


  const runtimeStatus = bootFailed
    ? 'Chess Football no ha podido arrancar'
    : runtimeReady
    ? 'Chess Football listo'
    : runtime.source === 'fallback'
      ? 'POC Web todavía no publicado'
      : runtime.source === 'resolving'
        ? 'Resolviendo runtime Godot…'
        : 'Arrancando Chess Football…';

  return (
    <div
      className="chess-football-godot-host"
      data-runtime-ready={runtimeReady ? 'true' : 'false'}
      data-mobile-portrait={mobilePortrait ? 'true' : 'false'}
    >
      {!mobilePortrait ? (
        <button
          type="button"
          className="chess-football-godot-host__mobile-exit"
          onClick={exitFootball}
          aria-label="Salir de Chess Football"
        >
          Salir
        </button>
      ) : null}

      {mobilePortrait ? (
        <div className="chess-football-godot-host__portrait-gate" role="dialog" aria-modal="true" aria-label="Chess Football necesita apaisado">
          <div className="chess-football-godot-host__portrait-card">
            <small>MÓVIL · APAISADO</small>
            <h2>Gira el móvil</h2>
            <p>Chess Football necesita el campo en horizontal. Puedes girarlo a mano o pedir al navegador que active el apaisado.</p>
            <div className="chess-football-godot-host__portrait-actions">
              <button type="button" onClick={requestLandscape}>Activar apaisado</button>
              <button type="button" className="is-secondary" onClick={exitFootball}>Salir de Chess Football</button>
            </div>
          </div>
        </div>
      ) : null}
      {runtimeReady ? (
        <details className="chess-football-godot-host__art-details">
          <summary aria-label="Comprobar sprites de regate y entradas">
            Arte R2 · {poseInstalled.length === FOOTBALL_POSE_TOTAL
              ? '8/8' : poseScanFinished ? `${poseInstalled.length}/8` : 'comprobando'}
          </summary>
          <div className="chess-football-godot-host__art-panel">
            <strong>Sprites en este partido</strong>
            <p>{poseInstalled.length === FOOTBALL_POSE_TOTAL
              ? 'Los ocho atlas verificados están instalados.'
              : poseScanFinished
                ? 'Los gestos sin confirmar mantienen su animación anterior.'
                : 'Comprobando descargas y texturas de ambos equipos…'}</p>
            <ul>
              {FOOTBALL_POSE_TEAMS.map((team) => (
                <li key={team.id}>
                  <strong>{team.label} · {footballPoseTeamCount(poseInstalled, team.id)}/4</strong>
                  <span>{FOOTBALL_POSE_ACTIONS.map((pose) => (
                    `${pose.label}: ${poseInstalled.includes(`${team.id}:${pose.id}`) ? 'R2' : poseScanFinished ? 'fallback' : '…'}`
                  )).join(' · ')}</span>
                </li>
              ))}
            </ul>
            <small>Solo lectura. No registra tu partida ni envía datos.</small>
          </div>
        </details>
      ) : null}
      {!runtimeReady ? (
        <div className="chess-football-godot-host__status" aria-live="polite">
          <span aria-hidden="true" />
          {runtimeStatus}
        </div>
      ) : null}

      {bootFailed ? (
        <div className="chess-football-godot-host__fallback" role="alert">
          <h2>Chess Football no ha arrancado</h2>
          <p>El juego no confirmó el arranque de un partido 11 contra 11. Puedes reintentar o salir sin quedar atrapado en una pantalla negra.</p>
          <button type="button" onClick={() => setAttempt((value) => value + 1)}>Reintentar</button>
          <button type="button" onClick={exitFootball}>Salir de Chess Football</button>
        </div>
      ) : null}
      {runtime.url && !bootFailed ? (
        <iframe
          ref={frameRef}
          key={matchUrl}
          className="chess-football-godot-host__frame"
          tabIndex={0}
          src={matchUrl}
          title="Chess Football Godot"
          referrerPolicy="origin"
          allow="autoplay; fullscreen; gamepad"
          allowFullScreen
          
        />
      ) : runtime.source === 'fallback' ? (
        <div className="chess-football-godot-host__fallback">
          <small>POC · GODOT WEB</small>
          <h2>Chess Football</h2>
          <p>El prototipo está cableado, pero el export Web aún no está publicado en el CDN.</p>
          <button type="button" className="secondary-btn" onClick={() => setAttempt((value) => value + 1)}>
            Reintentar
          </button>
        </div>
      ) : null}
    </div>
  );
}
