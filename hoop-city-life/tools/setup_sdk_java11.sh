#!/bin/bash
# SDK Android con cmdline-tools compatibili Java 11 + estrazione template su disco.
set -e
export ANDROID_HOME=$HOME/.cache/android/sdk
export JAVA_HOME=/usr/lib/jvm/jdk-11
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
DL="$HOME/.cache/android/dl"
mkdir -p "$DL" "$ANDROID_HOME"
cd "$DL"

# 1) cmdline-tools 9.x (gira su Java 11)
if [ ! -d "$ANDROID_HOME/cmdline-tools/latest/bin" ]; then
  echo "[a] cmdline-tools 9477386 (Java 11)..."
  rm -rf "$ANDROID_HOME/cmdline-tools"
  curl -sL -o cmdtools11.zip "https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip"
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  unzip -q -o cmdtools11.zip -d "$ANDROID_HOME/cmdline-tools"
  mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
fi

echo "[b] licenze e pacchetti..."
yes | sdkmanager --sdk_root="$ANDROID_HOME" --licenses >/dev/null 2>&1 || true
sdkmanager --sdk_root="$ANDROID_HOME" "platform-tools" "build-tools;34.0.0" "platforms;android-34"

# 2) template: estrazione su DISCO (no /tmp, che e' un tmpfs da 1GB)
TPL_DIR="$HOME/.local/share/godot/export_templates/4.3.stable"
if [ ! -f "$TPL_DIR/version.txt" ]; then
  echo "[c] estrazione template su disco..."
  mkdir -p "$DL/tplx" "$TPL_DIR"
  unzip -q -o "$DL/templates.tpz" -d "$DL/tplx"
  cp -r "$DL/tplx/templates/"* "$TPL_DIR/"
  rm -rf "$DL/tplx"
fi
echo "[d] VERSIONI:"
sdkmanager --version
ls "$TPL_DIR" | head -20
echo "SDK_DONE"
