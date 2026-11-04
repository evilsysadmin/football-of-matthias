import { useEffect, useState } from 'react';
import {
  fetchPublishedFootballBuild, footballUpdateAvailable, FOOTBALL_BUILD_ID,
  RELEASE_CHECK_INTERVAL_MS,
} from '../releaseUpdate.js';
import './ReleaseUpdateNotice.css';

const DISMISS_PREFIX = 'football-release-dismissed:';

function wasDismissed(build) {
  try { return sessionStorage.getItem(DISMISS_PREFIX + build) === '1'; }
  catch { return false; }
}
function rememberDismissed(build) {
  try { sessionStorage.setItem(DISMISS_PREFIX + build, '1'); }
  catch { /* Session storage can be unavailable. */ }
}

// The match is a separate cross-origin Godot runtime. The parent never reloads
// it: this notice mounts only in the Football menus, and only the vestuario
// offers the actual refresh button.
export default function ReleaseUpdateNotice({ deferReload = true }) {
  const [latest, setLatest] = useState(null);
  const [dismissed, setDismissed] = useState(false);
  const [snoozed, setSnoozed] = useState(false);

  useEffect(() => {
    if (!FOOTBALL_BUILD_ID) return undefined;
    let active = true, pending = false, rerun = false;
    const controller = new AbortController();
    async function check() {
      if (document.visibilityState === 'hidden' || controller.signal.aborted) return;
      if (pending) { rerun = true; return; }
      pending = true;
      try {
        do {
          rerun = false;
          const published = await fetchPublishedFootballBuild({ signal: controller.signal });
          if (active && published) {
            setLatest(published);
            setDismissed(wasDismissed(published));
          }
        } while (active && !controller.signal.aborted && rerun);
      } finally { pending = false; }
    }
    const onFocus = () => { if (document.visibilityState !== 'hidden') void check(); };
    void check();
    const timer = window.setInterval(() => void check(), RELEASE_CHECK_INTERVAL_MS);
    document.addEventListener('visibilitychange', onFocus);
    window.addEventListener('focus', onFocus);
    window.addEventListener('online', onFocus);
    return () => {
      active = false; controller.abort(); window.clearInterval(timer);
      document.removeEventListener('visibilitychange', onFocus);
      window.removeEventListener('focus', onFocus);
      window.removeEventListener('online', onFocus);
    };
  }, []);

  useEffect(() => { setSnoozed(false); }, [latest]);
  if (!footballUpdateAvailable(latest) || dismissed || (deferReload && snoozed)) return null;

  const dismiss = () => {
    rememberDismissed(latest);
    setDismissed(true);
  };
  return (
    <aside className="football-release-notice" role="status" aria-live="polite" data-testid="football-release-notice">
      <div className="football-release-notice__copy">
        <strong>Nueva versión disponible</strong>
        <span>{deferReload
          ? 'Continúa con tu club. Vuelve al vestuario para actualizar.'
          : 'Hay mejoras nuevas listas para cargar.'}</span>
      </div>
      <div className="football-release-notice__actions">
        {deferReload ? (
          <button type="button" onClick={() => setSnoozed(true)}>Después</button>
        ) : (
          <>
            <button type="button" className="is-primary" onClick={() => window.location.reload()}>Actualizar</button>
            <button type="button" onClick={dismiss}>Ahora no</button>
          </>
        )}
      </div>
    </aside>
  );
}
