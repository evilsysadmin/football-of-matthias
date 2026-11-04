import { readFileSync } from 'node:fs';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// prepare_staging.py writes the exact published source SHA before Vite builds
// the browser app. Reading that manifest avoids comparing against the
// unrelated GITHUB_SHA of an Infra workflow. Local builds have no build ID.
let publishedBuild = '';
try {
  const metadata = JSON.parse(readFileSync(new URL('./public/release.json', import.meta.url), 'utf8'));
  const sha = metadata?.application === 'football-of-matthias' ? metadata.source_sha : '';
  if (typeof sha === 'string' && /^[a-f0-9]{40}$/.test(sha) && !/^0+$/.test(sha)) publishedBuild = sha;
} catch { /* No deployment metadata during ordinary local development. */ }
// Source CI has no generated manifest, but names its exact checked-out commit.
// Do not fall back to GITHUB_SHA: infra deployments run in another repository.
if (!publishedBuild) {
  const sha = process.env.FOOTBALL_SOURCE_SHA || '';
  if (/^[a-f0-9]{40}$/.test(sha) && !/^0+$/.test(sha)) publishedBuild = sha;
}

export default defineConfig({
  define: { __FOOTBALL_BUILD_ID__: JSON.stringify(publishedBuild) },
  plugins: [react()],
  server: { host: '127.0.0.1' },
  preview: { host: '127.0.0.1' },
  build: { sourcemap: false },
  test: { setupFiles: ['./src/test-setup.js'], include: ['src/**/*.test.js'] },
});
