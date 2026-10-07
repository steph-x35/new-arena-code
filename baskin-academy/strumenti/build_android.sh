#!/usr/bin/env bash
# Run after the release version has been updated in GameData and export presets.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/baskin_academy"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/jdk-11}"
export ANDROID_HOME="$HOME/.cache/android/sdk"
export PATH="$JAVA_HOME/bin:$HOME/.cache/godot:$ANDROID_HOME/platform-tools:$PATH"
bash "$ROOT/strumenti/setup_build_env.sh"
godot --headless --editor --path "$PROJECT" --quit
# Editor settings are environment-local: recreate paths after a workspace restore.
python3 - "$PROJECT" <<'PY'
from pathlib import Path
import os, re, sys
project=Path(sys.argv[1])
cfg=Path(os.environ.get('XDG_CONFIG_HOME',str(Path.home()/'.config')))/'godot/editor_settings-4.3.tres'
s=cfg.read_text()
for key, value in {
 'export/android/java_sdk_path': os.environ['JAVA_HOME'],
 'export/android/android_sdk_path': os.environ['ANDROID_HOME'],
}.items():
 line=f'{key} = "{value}"'
 if re.search(r'^'+re.escape(key)+r' = .*$',s,re.M):
  s=re.sub(r'^'+re.escape(key)+r' = .*$',lambda _:line,s,flags=re.M)
 else:
  s=s.replace('[resource]','[resource]\n'+line,1)
cfg.write_text(s)
game=(project/'src/core/GameData.gd').read_text()
presets=(project/'export_presets.cfg').read_text()
version=re.search(r'const VERSION := "([^"]+)"',game).group(1)
assert f'version/name="{version}"' in presets, 'Versioni non allineate'
assert int(re.search(r'version/code=(\d+)',presets).group(1)) > 17, 'Incrementare versionCode prima del rilascio'
PY
mkdir -p "$PROJECT/export/android"
godot --headless --path "$PROJECT" --export-release "Android"
APK="$PROJECT/export/android/BaskinAcademy.apk"
"$ANDROID_HOME/build-tools/34.0.0/apksigner" verify --verbose --print-certs "$APK"
"$ANDROID_HOME/build-tools/34.0.0/aapt" dump badging "$APK" | sed -n '1p'
sha256sum "$APK"
echo "APK generato: $APK"
