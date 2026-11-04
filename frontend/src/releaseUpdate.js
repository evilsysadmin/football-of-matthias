// A new deployment is identified by its exact published source commit, not a
// human-facing version label or the independently versioned Godot runtime.
const SOURCE_SHA = /^[a-f0-9]{40}$/;
export const RELEASE_CHECK_INTERVAL_MS = 60_000;
export const RELEASE_FETCH_TIMEOUT_MS = 7_000;

export function normalizeSourceSha(value) {
  return typeof value === 'string' && SOURCE_SHA.test(value) && !/^0+$/.test(value)
    ? value : null;
}

export const FOOTBALL_BUILD_ID = normalizeSourceSha(
  typeof __FOOTBALL_BUILD_ID__ !== 'undefined' ? __FOOTBALL_BUILD_ID__ : null,
);

export function publishedFootballBuild(payload) {
  if (!payload || typeof payload !== 'object' || payload.application !== 'football-of-matthias') return null;
  return normalizeSourceSha(payload.source_sha);
}

export function footballUpdateAvailable(latest, running = FOOTBALL_BUILD_ID) {
  return Boolean(normalizeSourceSha(latest) && normalizeSourceSha(running) && latest !== running);
}

export function footballReleaseUrl(base = '/', now = Date.now()) {
  const prefix = String(base || '/').endsWith('/') ? String(base || '/') : `${base}/`;
  return `${prefix}release.json?ts=${Math.max(0, Number(now) || 0)}`;
}

export async function fetchPublishedFootballBuild({
  fetchImpl = globalThis.fetch, base = '/', now = Date.now(), signal,
} = {}) {
  if (signal?.aborted) return null;
  const controller = new AbortController();
  const abort = () => controller.abort();
  signal?.addEventListener?.('abort', abort, { once: true });
  const timeout = setTimeout(abort, RELEASE_FETCH_TIMEOUT_MS);
  try {
    const response = await fetchImpl(footballReleaseUrl(base, now), {
      method: 'GET', cache: 'no-store', headers: { accept: 'application/json' },
      signal: controller.signal,
    });
    if (!response?.ok || controller.signal.aborted) return null;
    return publishedFootballBuild(await response.json());
  } catch {
    // Loss of network or invalid deployment metadata must not disturb play.
    return null;
  } finally {
    clearTimeout(timeout);
    signal?.removeEventListener?.('abort', abort);
  }
}
