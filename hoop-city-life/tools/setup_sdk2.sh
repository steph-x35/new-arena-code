#!/bin/bash
export ANDROID_HOME=$HOME/.cache/android/sdk
export JAVA_HOME=/usr/lib/jvm/jdk-11
export _JAVA_OPTIONS="-Djava.io.tmpdir=$HOME/.cache/android/tmp"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
mkdir -p "$HOME/.cache/android/tmp"
echo "[licenses]"
yes | sdkmanager --sdk_root="$ANDROID_HOME" --licenses >/dev/null 2>&1 || true
echo "[packages]"
sdkmanager --sdk_root="$ANDROID_HOME" "platform-tools" "build-tools;34.0.0" "platforms;android-34"
echo "[templates extract]"
TPL_DIR="$HOME/.local/share/godot/export_templates/4.3.stable"
DL="$HOME/.cache/android/dl"
mkdir -p "$DL/tplx" "$TPL_DIR"
unzip -q -o "$DL/templates.tpz" -d "$DL/tplx"
cp -r "$DL/tplx/templates/"* "$TPL_DIR/"
rm -rf "$DL/tplx"
ls "$TPL_DIR" | head
echo "SDK_DONE"
