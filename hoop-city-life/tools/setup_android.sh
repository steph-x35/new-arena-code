#!/bin/bash
# Installa Android SDK + Godot 4.3 export templates (richiesti per l'APK).
set -e
export ANDROID_HOME=$HOME/.cache/android/sdk
mkdir -p "$ANDROID_HOME" "$HOME/.cache/android/dl"
cd "$HOME/.cache/android/dl"

# 1) cmdline-tools
if [ ! -d "$ANDROID_HOME/cmdline-tools/latest" ]; then
  echo "[1/4] cmdline-tools..."
  curl -sL -o cmdtools.zip "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  unzip -q -o cmdtools.zip -d "$ANDROID_HOME/cmdline-tools"
  mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
fi

export JAVA_HOME=/usr/lib/jvm/jdk-11
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

# 2) pacchetti SDK
echo "[2/4] SDK packages (platform-tools, build-tools, platform 34)..."
yes | sdkmanager --sdk_root="$ANDROID_HOME" --licenses >/dev/null 2>&1 || true
sdkmanager --sdk_root="$ANDROID_HOME" "platform-tools" "build-tools;34.0.0" "platforms;android-34" 2>&1 | tail -2

# 3) export templates Godot 4.3
TPL_DIR="$HOME/.local/share/godot/export_templates/4.3.stable"
if [ ! -f "$TPL_DIR/version.txt" ]; then
  echo "[3/4] Godot export templates (~900MB)..."
  curl -sL -o templates.tpz "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz"
  mkdir -p /tmp/tplx
  unzip -q -o templates.tpz -d /tmp/tplx
  mkdir -p "$TPL_DIR"
  cp -r /tmp/tplx/templates/* "$TPL_DIR/"
  rm -rf /tmp/tplx templates.tpz
fi
echo "[4/4] DONE"
