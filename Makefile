.DEFAULT_GOAL := help
GODOT ?= godot
.PHONY: help install dev test export
help:
	@printf '%s\n' 'Football of Matthias — staging independiente' 'make install | dev | test | export GODOT=/path/to/godot'
install:
	npm --prefix frontend install --no-audit --no-fund
dev:
	npm --prefix frontend run dev
test:
	node tests/identity-gate.test.mjs
	python3 scripts/check_migration.py
	python3 -m unittest discover -s scripts -p 'test_migration_provenance.py'
	python3 -S scripts/art/chess_football_sprite_forge.py verify --assets-dir games/chess-football-godot/assets/players
	npm --prefix frontend test
export:
	python3 scripts/materialize_canonical.py
	mkdir -p games/chess-football-godot/build/web
	$(GODOT) --headless --path games/chess-football-godot --editor --quit
	$(GODOT) --headless --path games/chess-football-godot --export-release Web build/web/index.html
	python3 scripts/prepare_staging.py
	npm --prefix frontend run build
