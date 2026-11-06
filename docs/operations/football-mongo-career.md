# Football · carreras Mongo por ShadowOps ID (staging, pendiente de activación)

Esta iteración aporta el **contrato y el servicio**, no declara almacenamiento remoto desplegado. La carrera actual continúa siendo **local** hasta un segundo cambio de UI y una activación aprobada por Infra. No se eliminan ni reasignan los diarios locales.

## Datos y límites

- `shadowops_football_staging.careers` (MongoDB independiente del IdP y de Chess); clave `_id` = UUIDv4 verificado por ShadowOps ID; documento `{_id,revision,journal,updated_at}`.
- `journal` conserva sólo decisiones deterministas, no resultados inventados ni copia de las cuentas Identity. La API reutiliza `replayFootballCareer` para verificar que cada jugador, alineación, calendario, seed y temporada sean coherentes antes de persistir.
- `GET /api/football/career` devuelve `{status:'empty',revision:0}`, `{status:'available',revision,journal}` o `{status:'future',revision}`. Nunca reemplazar una versión futura o corrupta de forma silenciosa.
- `PUT /api/football/career` exige `{revision,journal}` y devuelve `{status:'saved',revision:+1}`. Revisión cero crea el registro; revisiones existentes usan compare-and-swap. Una escritura obsoleta retorna 409 y no sobrescribe.
- Límite: 20 KiB de solicitud, 16 KiB de JSON de carrera. No existe eliminación anónima, lista de usuarios ni subida masiva.

## Seguridad

La sesión y la frescura/revocación siguen verificadas por el **edge Pages** para cada GET/PUT. El navegador no envía UUID ni tokens de servicio; Pages proporciona `X-Football-Subject` desde la sesión validada y `Authorization: Bearer fsc1_...` con un secreto **distinto** del `soc1_` Identity. Los PUT exigen Origin exacto + Content-Type y no permiten query strings. El backend compara el token en tiempo constante antes de usar el subject. Mongo sólo es accesible desde el servicio interno, sin puerto Mongo público ni credenciales en frontend/Git/Pages.

## Activación separada (no realizada por esta PR)

1. Infra provisiona Mongo `shadowops_football_staging` con rol limitado a `careers`, TLS, índice único `_id` (integrado), backups/restore y credenciales de escritura separadas. No reutilizar el principal ni la DB de Identity.
2. Infra publica un contenedor inmutable del servicio `server/index.mjs` en la A1 existente, puerto interno 9275, sin exposición directa. Secretos: `FOOTBALL_MONGODB_URI` y `FOOTBALL_CAREER_SERVICE_CREDENTIAL` sólo en el servicio. El backend expone `/readyz`; vigilar índices/espacio/errores y asegurar el acceso al origin por el túnel.
3. Infra publica el origen HTTPS exclusivo `https://api-staging.football.shadowops.dpdns.org/api/career` y configura en Pages `FOOTBALL_CAREER_API_URL` (literal URL anterior), además del mismo `FOOTBALL_CAREER_SERVICE_CREDENTIAL` como **secret**. No habilitar un wildcard de destinos.
4. Antes de activar la UI cloud: pruebas de dos UUID reales de staging, aislamiento, revocación, 409 multisesión, F5, pérdida de red, errores de Mongo, versión futura, importación **explícita** desde copias locales, rollback y restauración desde backup. La UI vigente no usa todavía esta API, por lo que ningún guardado actual se publicita como Mongo.

En CI: `node --test server/career-api.test.mjs` y `node tests/identity-gate.test.mjs`. La API necesita `mongodb` sólo para arrancar el listener privado, no para las pruebas puras.
