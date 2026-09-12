#!/usr/bin/env bash
# Copy realm-server GameData XML over the Flash client's embedded .dat files.
# Server XML is the source of truth; run this after any GameData edit and
# rebuild the SWF. Client-only XML tweaks must be ported to the server first.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/realm-server/Resources/GameData"
DST="$ROOT/realm-client/src/kabam/rotmg/assets"

if [ ! -d "$SRC" ] || [ ! -d "$DST" ]; then
  echo "sync-gamedata: expected $SRC and $DST" >&2
  exit 1
fi

copied=0
for f in "$SRC"/*.xml; do
  base="$(basename "$f" .xml)"
  cp "$f" "$DST/${base}.dat"
  copied=$((copied + 1))
done

mismatched=0
for f in "$SRC"/*.xml; do
  base="$(basename "$f" .xml)"
  if ! cmp -s "$f" "$DST/${base}.dat"; then
    echo "MISMATCH ${base}" >&2
    mismatched=$((mismatched + 1))
  fi
done

echo "sync-gamedata: copied ${copied} files from GameData to client assets"
if [ "$mismatched" -ne 0 ]; then
  echo "sync-gamedata: ${mismatched} files still differ" >&2
  exit 1
fi
