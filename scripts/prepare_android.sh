#!/usr/bin/env bash
# Genera la carpeta android/ (no se versiona), fija el nombre visible y crea los íconos.
# Uso: bash scripts/prepare_android.sh
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -d android ]; then
  echo "▶ Generando la plataforma Android con flutter create…"
  flutter create --platforms=android --org pe.edu.emaf --project-name electroboard --no-overwrite .
  # flutter create agrega una prueba de ejemplo que no corresponde a esta app.
  rm -f test/widget_test.dart
fi

MANIFEST=android/app/src/main/AndroidManifest.xml
sed -i.bak 's/android:label="[^"]*"/android:label="ElectroBoard"/' "$MANIFEST" && rm -f "$MANIFEST.bak"

echo "▶ Generando los íconos del lanzador…"
dart run flutter_launcher_icons

echo "✔ Listo. Compila con: flutter build apk --release"
