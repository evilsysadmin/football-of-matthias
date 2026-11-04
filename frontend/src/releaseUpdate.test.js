import { describe, expect, it, vi } from 'vitest';
import {
  fetchPublishedFootballBuild, footballReleaseUrl, footballUpdateAvailable,
  normalizeSourceSha, publishedFootballBuild,
} from './releaseUpdate.js';

const OLD = 'a'.repeat(40), NEW = 'b'.repeat(40);
const manifest = (source_sha = NEW) => ({ application: 'football-of-matthias', environment: 'staging', source_sha });

describe('Football deployment notices', () => {
  it('compares exact source builds and never guesses a version from missing metadata', () => {
    expect(normalizeSourceSha(OLD)).toBe(OLD);
    expect(normalizeSourceSha('0'.repeat(40))).toBe(null);
    expect(footballUpdateAvailable(NEW, OLD)).toBe(true);
    expect(footballUpdateAvailable(OLD, OLD)).toBe(false);
    expect(footballUpdateAvailable(null, OLD)).toBe(false);
    expect(footballUpdateAvailable(NEW, null)).toBe(false);
    expect(footballUpdateAvailable('dev', OLD)).toBe(false);
    expect(publishedFootballBuild(manifest())).toBe(NEW);
    expect(publishedFootballBuild({ ...manifest(), application: 'another-game' })).toBe(null);
    expect(publishedFootballBuild({ ...manifest(), source_sha: '0'.repeat(40) })).toBe(null);
  });

  it('requests an uncached release manifest without exposing session credentials', async () => {
    const fetchImpl = vi.fn().mockResolvedValue({ ok: true, json: async () => manifest() });
    expect(await fetchPublishedFootballBuild({ fetchImpl, base: '/', now: 123 })).toBe(NEW);
    expect(footballReleaseUrl('/', 123)).toBe('/release.json?ts=123');
    expect(fetchImpl).toHaveBeenCalledWith('/release.json?ts=123', expect.objectContaining({
      method: 'GET', cache: 'no-store', headers: { accept: 'application/json' },
    }));
    expect(fetchImpl.mock.calls[0][1]).not.toHaveProperty('credentials');
    expect(fetchImpl.mock.calls[0][1].signal).toBeInstanceOf(AbortSignal);
  });

  it('fails quiet on 404, invalid JSON, offline and an aborted request', async () => {
    expect(await fetchPublishedFootballBuild({ fetchImpl: async () => ({ ok: false }) })).toBeNull();
    expect(await fetchPublishedFootballBuild({ fetchImpl: async () => ({ ok: true, json: async () => { throw Error('broken'); } }) })).toBeNull();
    expect(await fetchPublishedFootballBuild({ fetchImpl: async () => { throw Error('offline'); } })).toBeNull();
    const controller = new AbortController();
    controller.abort();
    const fetchImpl = vi.fn();
    expect(await fetchPublishedFootballBuild({ fetchImpl, signal: controller.signal })).toBeNull();
    expect(fetchImpl).not.toHaveBeenCalled();
  });
});
