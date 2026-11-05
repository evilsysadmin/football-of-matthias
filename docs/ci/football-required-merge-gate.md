# Chess Football — mandatory merge gate

The stable GitHub Actions check is **`Football · required visual gate`** in
[`chess-football-godot-poc.yml`](../../.github/workflows/chess-football-godot-poc.yml).
The workflow appears as **`Football · filtro de cambios (Godot si aplica)`**
on every pull request so the check never disappears because of
`pull_request.paths`. This workflow title is informational; the mandatory
check is still **`Football · required visual gate`**.

## Behavior

- When a PR changes `games/chess-football-godot/**`, the canonical football art
  scripts, the Godot bundle publisher or the Football CI workflow, run **both**
  the Godot validation (including the camera/tonal capture) and real Chromium
  WebAssembly boot. Both must succeed.
- For unrelated PRs, the lightweight changed-file detector succeeds and
  Godot/Chromium are **skipped**; the stable final check is successful.
- On diff-discovery errors, truncated PR lists, cancelled, skipped, pending or
  failing Football tests, the final gate **fails closed**.

## Regla operativa de repositorio (sin exigir cambios de ruleset)

Por decisión de producto, este contrato se aplica como **regla explícita de
trabajo del repositorio**, en lugar de solicitar ahora nuevos checks obligatorios
en `Protect main`. El workflow y su check `Football · required visual gate`
se conservan porque ayudan a verificar las iteraciones, pero **si GitHub no
los exige en su ruleset, un fallo o un job pendiente NO bloquea por sí mismo
el merge**.

Para toda PR que afecte a Football, incluyendo scripts de arte canónico,
export o su workflow:

1. Empezar en **Draft**; no usar automerge prematuro ni fusionar manualmente
   mientras falten Godot `validate`, capturas visuales o arranque Chromium.
2. Esperar el resultado **success** del check estable
   `Football · required visual gate` sobre el SHA exacto que se fusionará.
   Si falla, se cancela, queda omitido inesperadamente o no aparece,
   corregir e iterar en la **misma PR**.
3. Inspeccionar los PNG de comparación y juzgar tamaño aparente,
   luminosidad entre orientaciones, alineación de botas/sombras y ausencia
   de regresión visual. No basta con un test verde.
4. Sólo entonces pasar a **Ready** y permitir el merge/automerge; comprobar
   el resultado después de fusionar. Un commit posterior invalida la revisión
   anterior y obliga a mirar los checks del nuevo SHA.
5. Una PR ajena a Football debe recibir el gate verde sin ejecutar Godot ni
   Chromium; no castigar otros productos por este criterio visual.

Estas instrucciones complementan
[`AGENTS.md`](../../AGENTS.md) y
[`docs/operations/chess-football-product.md`](../operations/chess-football-product.md).
**No afirmar protección automática del branch** donde no existe. La
incidencia histórica #5320 motivó el workflow, pero la preferencia actual
es calidad operacional documentada y no aumentar las condiciones del ruleset.

## Wake-up inmediato del staging (sin saltarse la admisión)

En cada `push` a `main`, **después** de superar `Football · required visual gate`,
el job `notify_staging` solicita por API una ejecución de
`evilsysadmin/shadowops-infra/.github/workflows/football-pages-staging.yml`.
El disparo no publica directamente desde Football: Infra exige además que el
workflow independiente XI esté verde, comprueba el SHA exacto de `main`,
el ZIP y sus hashes, los límites R2 y el gate de ShadowOps ID antes de
publicar. La ejecución se serializa con el resto de releases de Infra.

**Configuración una sola vez:** guardar como secret de Actions del repositorio
`evilsysadmin/football-of-matthias` un token GitHub de acceso específico
`FOOTBALL_INFRA_DISPATCH_TOKEN`. Debe ser un fine-grained personal access
token limitado exclusivamente a `evilsysadmin/shadowops-infra`, con
`Actions: Read and write` (y el permiso implícito `Metadata: Read`).
No conceder Contents write, ni introducir tokens de Cloudflare/R2 ni
permisos cloud en el repositorio Football. Rotar/revocar el token como una
credencial de automatización.

La notificación es **best effort**: si el secret falta, está revocado o la API
está temporalmente caída, el job deja un warning y devuelve éxito, de forma
que el workflow de origen pueda seguir siendo admitido por el reconciliador
programado de Infra. Este respaldo sigue ejecutándose en los minutos
`:13` y `:43`. Nunca interpretar `FOOTBALL_STAGING_WAKEUP_REQUESTED` como
prueba de despliegue: el recibo real sigue siendo
`FOOTBALL_STAGING_PUBLIC_VERIFIED source_sha=<sha>` desde Infra.
