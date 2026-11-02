# ShadowOps ID staging session

Football is a staging-only consumer of `https://id-staging.shadowops.dpdns.org`, audience `football`, at `https://staging.football.shadowops.dpdns.org`. The login return is pinned by the IdP and contains no token. There is no guest mode.

The Pages `_worker.js` verifies Ed25519 signatures, issuer/audience, UUID and the two-minute JWT lifetime, then checks live account/session/token freshness through the authenticated IdP RPC for protected HTTP requests. The `soc1_` proof is a server-only Pages secret named `SHADOWOPS_FOOTBALL_SERVICE_CREDENTIAL`; it is provisioned from Infra custody. Missing configuration, revocation or an unavailable IdP deny access. Neither a browser assertion nor a JWT signature alone grants entry.

The bootstrap requests an audience-bound token from the central host-only cookie, keeps it only during the HTTPS exchange, and obtains a separate Secure/HttpOnly/host-only Football cookie. Credentials never enter URLs, localStorage, logs or artifacts. Pages aliases deny access and do not create another origin. The signed release metadata remains public for delivery inspection.

Before mounting the game, the frontend asks its same-origin authenticated session endpoint for the verified UUID. It renews through Identity while visible and rechecks on focus. Switching identities unmounts the old game. Global logout is reported only after Identity commits revocation. The account's game career remains on this device under its UUID; cloud synchronization is not claimed. Earlier unclaimed saves are preserved for explicit export/import, never auto-linked to a new account.

CI edge tests use ephemeral Ed25519 keys and a synthetic freshness server; UI captures use an explicit local server session fixture. Neither is a real account or production proof. Infra owns actual consumer activation, deployment bindings and the public anonymous/authenticated/revocation journey. Game source and static distributable art are public open-source material, not account data.

Unavailable session API responses expose only a fixed `X-Football-Identity-Error` stage (`edge_configuration`, `identity_keys`, `identity_freshness`, `edge_runtime` or generic `session`) for operator diagnosis. They never expose a credential, subject, JWT, upstream body or transport exception; denied credentials remain generic.

The default HTTPS transport calls `globalThis.fetch` as a method, preserving the receiver required by workerd. A regression test exercises the default transport with that same receiver requirement through both JWKS and freshness, alongside the injected cryptographic authority tests. See the [Workers invocation contract](https://developers.cloudflare.com/workers/observability/errors/#illegal-invocation-errors).
