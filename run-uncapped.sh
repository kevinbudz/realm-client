#!/bin/sh
# Launch the realm client with uncapped FPS for personal testing.
# Routes through adl-uncapped (vblank_mode=0 = immediate presentation),
# since the AIR Linux runtime ignores the in-game VSync-off request.
# Rebuild first with ./build.sh after source changes.
# Usage: ./run-uncapped.sh [extra ADL args...]
set -e
cd "$(dirname "$0")"
exec adl-uncapped bin-debug/WebMain-app.xml bin-debug "$@"
