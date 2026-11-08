import { describe, expect, it, vi } from 'vitest';
import {
  DEFAULT_CHESS_FOOTBALL_MANIFEST_URL,
  resolveChessFootballGodotUrl,
  validateChessFootballManifest,
} from './chessFootballGodotRuntime.js';

const VALID_MANIFEST = {
  version: 1,
  release: '0123456789abcdef',
  sourceSha: 'a'.repeat(40),
  index: 'https://assets.chess-studio.shadowops.dpdns.org/football-of-matthias/staging/releases/0123456789abcdef/index.html',
};

describe('Chess Football Godot runtime', () => {
  it('accepts a release pinned to the Chess Football R2 namespace', () => {
    expect(validateChessFootballManifest(VALID_MANIFEST)).toMatchObject({
      release: VALID_MANIFEST.release,
      index: VALID_MANIFEST.index,
      sourceSha: VALID_MANIFEST.sourceSha,
    });
  });

  it('does not present malformed or placeholder source SHAs as verified releases', () => {
    for (const sourceSha of ['not-a-commit', '0'.repeat(40), 'a'.repeat(41)]) {
      expect(validateChessFootballManifest({ ...VALID_MANIFEST, sourceSha }).sourceSha).toBe('');
    }
  });

  it('rejects an index outside the expected release path', () => {
    expect(() => validateChessFootballManifest({
      ...VALID_MANIFEST,
      index: 'https://assets.chess-studio.shadowops.dpdns.org/pawn-slug-godot/releases/0123456789abcdef/index.html',
    })).toThrow(/fuera del release esperado/);
  });

  it('prefers an explicit runtime override', async () => {
    const fetchImpl = vi.fn();
    await expect(resolveChessFootballGodotUrl({
      env: { VITE_CHESS_FOOTBALL_GODOT_URL: 'https://example.test/football/index.html' },
      fetchImpl,
    })).resolves.toEqual({
      url: 'https://example.test/football/index.html',
      source: 'override',
      release: '',
      sourceSha: '',
    });
    expect(fetchImpl).not.toHaveBeenCalled();
  });

  it('resolves the protected runtime manifest with its same-origin session and no cache', async () => {
    const fetchImpl = vi.fn(async () => ({
      ok: true,
      json: async () => VALID_MANIFEST,
    }));
    await expect(resolveChessFootballGodotUrl({ fetchImpl, now: () => 42 })).resolves.toEqual({
      url: VALID_MANIFEST.index,
      source: 'r2',
      release: VALID_MANIFEST.release,
      sourceSha: VALID_MANIFEST.sourceSha,
    });
    expect(fetchImpl).toHaveBeenCalledWith(
      `${DEFAULT_CHESS_FOOTBALL_MANIFEST_URL}?v=42`,
      expect.objectContaining({ cache: 'no-store', credentials: 'same-origin' }),
    );
  });

  it('fails closed when no published runtime is available', async () => {
    const fetchImpl = vi.fn(async () => ({ ok: false, status: 404 }));
    await expect(resolveChessFootballGodotUrl({ fetchImpl })).resolves.toMatchObject({
      url: '',
      source: 'fallback',
      release: '',
    });
  });
});
