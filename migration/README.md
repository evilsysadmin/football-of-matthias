# Procedencia y adaptaciones

`source.json` identifica el origen en Chess Studio. El runtime Godot, el arte y las herramientas de arte se conservan byte a byte; `scripts/check_migration.py` verifica sus hashes Git originales. Las imágenes PNG duplicadas se reconstruyen desde las fuentes base64 verificadas antes de importar/exportar Godot.

Las adaptaciones del host son explícitas: entrada React propia; salida a ShadowOps; selector de runtime fijado al prefijo R2 de Football y manifest del staging; storage limitado a la carrera de este origen; exportación/importación de un journal validado; CI y artefactos propios. No se copian perfiles, credenciales ni un backend de Chess. La carrera estadística y las reglas del partido no cambian.
