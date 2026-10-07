#!/bin/bash
# Setup Godot 4.3 + Android SDK + export templates for BaskinArena APK build.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ANDROID_HOME=$HOME/.cache/android/sdk
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/jdk-11}"
export _JAVA_OPTIONS="-Djava.io.tmpdir=$HOME/.cache/android/tmp"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
DL="$HOME/.cache/android/dl"
GODOT_DIR="$HOME/.cache/godot"
mkdir -p "$DL" "$ANDROID_HOME" "$GODOT_DIR" "$HOME/.cache/android/tmp"
cd "$DL"

echo "[1/6] Godot 4.3 editor..."
if [ ! -x "$GODOT_DIR/godot" ]; then
  curl -fLsS --retry 3 -o godot43.zip "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip"
  unzip -q -o godot43.zip -d "$GODOT_DIR"
  mv "$GODOT_DIR/Godot_v4.3-stable_linux.x86_64" "$GODOT_DIR/godot"
  chmod +x "$GODOT_DIR/godot"
  rm -f godot43.zip
fi
"$GODOT_DIR/godot" --version

echo "[2/6] cmdline-tools (Java 11)..."
if [ ! -d "$ANDROID_HOME/cmdline-tools/latest/bin" ]; then
  rm -rf "$ANDROID_HOME/cmdline-tools"
  curl -fLsS --retry 3 -o cmdtools11.zip "https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip"
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  unzip -q -o cmdtools11.zip -d "$ANDROID_HOME/cmdline-tools"
  mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
  rm -f cmdtools11.zip
fi

echo "[3/6] SDK packages..."
yes | sdkmanager --sdk_root="$ANDROID_HOME" --licenses >/dev/null 2>&1 || true
sdkmanager --sdk_root="$ANDROID_HOME" "platform-tools" "build-tools;34.0.0" "platforms;android-34" 2>&1 | tail -2

echo "[4/6] export templates (~900MB)..."
TPL_DIR="$HOME/.local/share/godot/export_templates/4.3.stable"
if [ ! -f "$TPL_DIR/version.txt" ]; then
  if [ ! -f "$DL/templates.tpz" ]; then
    curl -fLsS --retry 3 -o templates.tpz "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz"
  fi
  mkdir -p "$DL/tplx" "$TPL_DIR"
  unzip -q -o "$DL/templates.tpz" -d "$DL/tplx"
  cp -r "$DL/tplx/templates/"* "$TPL_DIR/"
  rm -rf "$DL/tplx"
fi
ls "$TPL_DIR" | head -20

echo "[5/6] debug keystore check..."
"$JAVA_HOME/bin/keytool" -list -keystore "$ROOT/baskin_academy/keystore/debug.keystore" -storepass android -alias androiddebugkey

echo "[6/6] DONE - env ready"
