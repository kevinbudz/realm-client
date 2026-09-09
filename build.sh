#!/bin/sh
# Build WebMain.swf with the local AIR SDK.
# Usage: ./build.sh
# Env overrides: AIR_SDK (default ~/Desktop/AIRSDK_Linux), JAVA_HOME (default ~/.local/share/air-jdk)
set -e
cd "$(dirname "$0")"
AIR_SDK="${AIR_SDK:-$HOME/Desktop/AIRSDK_Linux}"
JAVA_HOME="${JAVA_HOME:-$HOME/.local/share/air-jdk}"
export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"
mkdir -p bin-debug
LIBS=""
for f in libs/*.swc; do
  LIBS="$LIBS -library-path+=$f"
done
# shellcheck disable=SC2086
"$AIR_SDK/bin/mxmlc" +configname=air \
  -source-path+=src \
  $LIBS \
  -output bin-debug/WebMain.swf \
  -locale en_US \
  -default-size 800 600 \
  -default-frame-rate 60 \
  -default-background-color "#000000" \
  -optimize=true \
  -use-direct-blit=true \
  -keep-as3-metadata+=Inject \
  -keep-as3-metadata+=Embed \
  -keep-as3-metadata+=PostConstruct \
  -keep-as3-metadata+=ArrayElementType \
  -strict=true \
  -- src/WebMain.as
