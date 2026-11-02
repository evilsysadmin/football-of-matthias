# Football of Matthias

Partido de fútbol Godot Web y carrera de mánager, extraídos de Chess Studio. Staging: **https://staging.football.shadowops.dpdns.org/**. Producción aún no se publica.

```sh
make install
make dev
make test
```

Node 22+; Godot 4.7.2 con templates Web para exportar el partido. `make export GODOT=/ruta/a/godot` crea el bundle y compila la interfaz. La CI fija y verifica los binarios de Godot, conserva los smoke tests y capturas del runtime original y arranca el WASM real en Chromium, además de probar la carrera y sus guardados.

La carrera del staging inicial se guarda en este navegador. En la entrada puedes exportarla o importar una copia estrictamente validada. El nuevo dominio no puede leer automáticamente el almacenamiento de Chess Studio. La migración no borra el guardado anterior ni importa perfiles/cuentas de ajedrez.

El origen exacto y los hashes de los ficheros trasladados están en `migration/source.json`; las dos imágenes PNG derivadas de los atlas canónicos se reconstruyen desde sus fuentes base64, sin cambiar los bytes aprobados. Los nombres de carpetas y mensajes `chess-football-godot` se conservan como identificadores del runtime; el repositorio ya es independiente.

Infra publica el frontend ligero en Pages y el WASM/PCK en un prefijo exclusivo del bucket R2 ya existente, con admisión de capacidad antes de subir. No requiere OCI, otra VM ni nuevas credenciales de usuario. Los artefactos de CI y `release.json` acreditan la revisión desplegada. Ver `docs/ci/football-required-merge-gate.md` y `docs/operations/chess-football-product.md` para aceptación de producto.

Staging requires ShadowOps ID. Its server edge checks signed Football tokens and live session freshness; no service proof is shipped to the browser. Careers are local to this device and scoped by the verified account UUID. Existing Chess or pre-Identity device saves are imported explicitly. See [the session contract](docs/shadowops-id.md).
