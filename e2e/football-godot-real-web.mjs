#!/usr/bin/env node
// Exercise exported Godot WASM in Chromium, not a mocked iframe.
import { createServer } from 'node:http';
import { createReadStream, existsSync, mkdirSync, readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve, extname, sep } from 'node:path';
import { chromium } from 'playwright';

const root = resolve(process.argv[2] || 'games/chess-football-godot/build/web');
const output = resolve('.artifacts/football-web');
mkdirSync(output, { recursive: true });
if (!existsSync(resolve(root, 'index.html'))) throw new Error('Missing exported Godot index.html');
const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png', '.svg': 'image/svg+xml', '.json': 'application/json' };

// CI runs the actual WebAssembly game from an ephemeral 127.0.0.1 origin.
// The independent R2 bucket must allow the real staging HTTPS origin, not
// localhost with a random port. Verify BOTH real R2 responses, their staging
// CORS headers and SHA-256 on the Node side, then serve those identical bytes
// to the local-only browser through a narrowly scoped Playwright route.
// The normal CI R2 gate separately makes the same live-origin checks.
// Do not weaken Cloudflare's CORS policy or intercept other CDN requests.
async function bridgeVerifiedStagingKeeperR2(page) {
  if (process.env.CI !== 'true') {
    throw new Error('The R2 localhost bridge is only permitted in GitHub CI');
  }
  const meta = JSON.parse(readFileSync('games/chess-football-godot/optional_keeper_catch_v1.json', 'utf8'));
  if (!meta.enabled) return;
  const expectedBase = 'https://pub-cda6a24cd2f94f7eaaf4d112351bf526.r2.dev/atlases/v1';
  if (meta.bucket !== 'football' || meta.prefix !== 'atlases/v1/' || meta.cdn_base !== expectedBase) {
    throw new Error('Refusing unexpected keeper bucket, path or public origin');
  }
  const expected = new Map([
    ['fc_matthias', 'fc_matthias_keeper_catch_v1.webp'],
    ['real_enroque', 'real_enroque_keeper_catch_v1.webp']
  ]);
  if (!Array.isArray(meta.entries) || meta.entries.length !== expected.size) {
    throw new Error('Expected exactly two pinned keeper sheets');
  }
  const stagingOrigin = 'https://staging.football.shadowops.dpdns.org';
  for (const entry of meta.entries) {
    const filename = expected.get(entry.team);
    if (!filename || entry.file !== filename || !/^[a-f0-9]{64}$/.test(entry.sha256)) {
      throw new Error('Invalid keeper sheet entry in bundled manifest');
    }
    expected.delete(entry.team);
    const assetUrl = expectedBase + '/' + filename;
    const result = await fetch(assetUrl, {
      headers: { Origin: stagingOrigin, 'User-Agent': 'Football-CI-real-Web/1.0' },
      signal: AbortSignal.timeout(15000)
    });
    if (result.status !== 200 || !result.headers.get('content-type')?.toLowerCase().startsWith('image/webp')) {
      throw new Error('Public keeper WebP unavailable: ' + assetUrl + ' HTTP ' + result.status);
    }
    const cors = result.headers.get('access-control-allow-origin');
    if (cors !== '*' && cors !== stagingOrigin) {
      throw new Error('Staging R2 CORS missing for ' + filename + ': ' + JSON.stringify(cors));
    }
    const raw = Buffer.from(await result.arrayBuffer());
    if (!raw.length || raw.length > 4194304 ||
        raw.toString('ascii', 0, 4) !== 'RIFF' || raw.toString('ascii', 8, 12) !== 'WEBP' ||
        createHash('sha256').update(raw).digest('hex') !== entry.sha256) {
      throw new Error('Keeper R2 byte integrity mismatch for ' + filename);
    }
    await page.route(assetUrl, (route) => route.fulfill({
      status: 200,
      contentType: 'image/webp',
      headers: { 'Access-Control-Allow-Origin': '*', 'Cache-Control': 'no-store' },
      body: raw
    }));
    console.log('FOOTBALL_WEB_CI_KEEPER_R2_VERIFIED', entry.team,
      'bytes=' + raw.length, 'sha256=' + entry.sha256, 'staging_cors=' + cors);
  }
  if (expected.size !== 0) throw new Error('Missing a keeper R2 team');
}

const server = createServer((req, res) => {
  try {
    let path = resolve(root, '.' + decodeURIComponent(new URL(req.url, 'http://localhost').pathname));
    if (path !== root && !path.startsWith(root + sep)) throw new Error('Bad path');
    if (path === root) path = resolve(root, 'index.html');
    if (!existsSync(path)) { res.writeHead(404); res.end('Not found'); return; }
    res.writeHead(200, { 'Content-Type': types[extname(path)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
    createReadStream(path).pipe(res);
  } catch (error) { res.writeHead(400); res.end(String(error)); }
});
await new Promise((ok) => server.listen(0, '127.0.0.1', ok));
const port = server.address().port;
const messages = [];
const failures = [];
let browser;
let page;
try {
  browser = await chromium.launch({ headless: true, args: ['--enable-webgl', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  page = await browser.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
  if (process.env.FOOTBALL_CI_KEEPER_R2_BRIDGE === '1') await bridgeVerifiedStagingKeeperR2(page);
  await page.addInitScript(() => {
    window.__chessFootballWebReady = false;
    // Only the locally served CI release enables the in-game diagnostic.
    // Unlike Input.action_press smoke tests, these are actual browser events.
    window.__chessFootballInputProbe = true;
    window.__chessFootballInputSamples = [];
    window.addEventListener('message', (event) => {
      if (event.data?.source !== 'chess-football-godot') return;
      if (event.data.type === 'ready') window.__chessFootballWebReady = true;
      if (event.data.type === 'ci-keyboard-sample') {
        window.__chessFootballInputSamples.push(event.data);
        if (window.__chessFootballInputSamples.length > 400) {
          window.__chessFootballInputSamples.shift();
        }
      }
    });
  });
  page.on('console', (line) => {
    const msg = line.type() + ': ' + line.text();
    messages.push(msg);
    if (line.type() === 'error' && /null function|RuntimeError|abort\(/i.test(msg)) failures.push(msg);
  });
  page.on('pageerror', (error) => failures.push('PAGE ERROR: ' + (error.stack || error.message)));
  page.on('requestfailed', (request) => {
    const reason = request.failure()?.errorText || '';
    // Chromium may cancel the redundant streaming fetch when Godot has already
    // consumed the PCK. Only genuine transport failures are fatal here; no
    // successful scene bootstrap will occur if the PCK was actually missing.
    if (reason === 'net::ERR_ABORTED') return;
    failures.push('REQUEST FAILED: ' + request.url() + ' ' + reason);
  });
  const url = 'http://127.0.0.1:' + port + '/index.html';
  console.log('Launching actual Godot Web release:', url);
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForFunction(() => window.__chessFootballWebReady === true, null, { timeout: 60000 });
  await page.waitForTimeout(2500);
  if (failures.length) throw new Error('Web runtime errors: ' + failures.slice(0, 8).join('\n'));
  if (await page.locator('canvas').count() === 0) throw new Error('Godot reported ready without canvas');

  // Regression: browser-only arrow keys appeared in the exported InputMap
  // but did not control real matches. Focus Godot's canvas and test both
  // directions/layouts against the actual controlled player's world position.
  // The gameplay script reports these values only for local CI and never
  // alters input or player velocity.
  await page.locator('canvas').click({ position: { x: 500, y: 370 }, timeout: 10000 });
  await page.waitForFunction(
    () => window.__chessFootballInputSamples.some((sample) => sample.playable),
    null, { timeout: 30000 }
  );
  async function expectRealMovement(key, axis, sign) {
    const startLength = await page.evaluate(() => window.__chessFootballInputSamples.length);
    await page.keyboard.down(key);
    try {
      await page.waitForTimeout(580);
    } finally {
      await page.keyboard.up(key);
    }
    const samples = await page.evaluate(
      (index) => window.__chessFootballInputSamples.slice(index).filter((sample) => sample.playable),
      startLength
    );
    const directionKey = axis === 'x' ? 'dx' : 'dy';
    const keySamples = samples.filter((sample) => Number(sample[directionKey]) * sign >= 0.8);
    if (keySamples.length < 2) {
      throw new Error(`Real Godot Web key ${key} not recognized: ${JSON.stringify(samples.slice(-8))}`);
    }
    const distance = (Number(keySamples.at(-1)[axis]) - Number(keySamples[0][axis])) * sign;
    if (distance < 4) {
      throw new Error(`Real Godot Web key ${key} did not move player: ${distance.toFixed(2)} game units`);
    }
    console.log('FOOTBALL_REAL_WEB_KEY_MOVE_OK', key, axis, 'distance=' + distance.toFixed(2));
    await page.waitForTimeout(120);
  }
  await expectRealMovement('ArrowRight', 'x', 1);
  await expectRealMovement('d', 'x', 1);
  await expectRealMovement('ArrowUp', 'y', -1);
  await expectRealMovement('w', 'y', -1);

  // Software WebGL in hosted Chromium can stall indefinitely on readPixels.
  // A successful scene handshake and clean browser error log are the hard gate;
  // visual PNG evidence is already produced separately by Godot's capture job.
  await page.screenshot({ path: resolve(output, 'real-web-kickoff.png'), timeout: 4000 })
    .catch((error) => console.warn('Optional software-WebGL screenshot unavailable: ' + error.message));
  console.log('CHESS_FOOTBALL_REAL_WEB_READY OK');
} catch (error) {
  if (page) await page.screenshot({ path: resolve(output, 'real-web-failure.png'), timeout: 10000 }).catch(() => {});
  console.error('REAL GODOT WEB BOOT FAILURE:', String(error));
  console.error('Runtime errors:\n' + failures.slice(-25).join('\n'));
  console.error('Browser console:\n' + messages.slice(-60).join('\n'));
  process.exitCode = 1;
} finally {
  await browser?.close().catch(() => {});
  await new Promise((ok) => server.close(ok));
}
