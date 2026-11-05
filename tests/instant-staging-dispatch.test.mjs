import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const workflow = readFileSync(new URL('../.github/workflows/chess-football-godot-poc.yml', import.meta.url), 'utf8')
const marker = '\n  notify_staging:\n'
assert.ok(workflow.includes(marker), 'main-only staging notification job must exist')
const notification = workflow.slice(workflow.indexOf(marker))
assert.match(notification, /needs: \[required_gate\]/, 'notification must depend on the final real visual gate')
assert.ok(notification.includes("github.event_name == 'push' && github.ref == 'refs/heads/main' && github.repository == 'evilsysadmin/football-of-matthias'"), 'never expose dispatch credentials to PR workflows')
assert.ok(notification.includes('GH_TOKEN: ${{ secrets.SHADOWOPS_INFRA_ACTIONS_TOKEN }}'), 'only a dedicated infra Actions dispatch token is permitted')
assert.ok(notification.includes('gh api -X POST repos/evilsysadmin/shadowops-infra/actions/workflows/football-pages-staging.yml/dispatches -f ref=main'), 'wake the existing trusted source admission, not a new privileged publisher')
assert.ok(notification.includes('if [[ -z "$GH_TOKEN" ]]'), 'missing token must retain the infra cron fallback')
assert.ok(notification.includes('if ! gh api'), 'transient wake-up errors must not invalidate the already-green source release artifact')
assert.doesNotMatch(notification, /FOOTBALL_INFRA_DISPATCH_TOKEN/, 'obsolete secret must never silently disable immediate delivery')
assert.doesNotMatch(notification, /CLOUDFLARE_API_TOKEN|FOOTBALL_R2_API_TOKEN/, 'never move cloud credentials into Football')
console.log('football main CI event-driven staging wake-up: OK')
