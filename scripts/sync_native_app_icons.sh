#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
V3="$ROOT/assets/icon/v3"
IOS_ASSETS="$ROOT/ios/Runner/Assets.xcassets"
ANDROID_RES="$ROOT/android/app/src/main/res"

VARIANTS="grafite_claro ic_launcher_grafite_claro
azul_nevoa ic_launcher_azul_nevoa
azul_oceano ic_launcher_azul_oceano
branco_cinza ic_launcher_branco_cinza
preto_grafite ic_launcher_preto_grafite"

DENSITIES="mipmap-mdpi:48
mipmap-hdpi:72
mipmap-xhdpi:96
mipmap-xxhdpi:144
mipmap-xxxhdpi:192"

while read -r variant mipmap; do
  src="$V3/${variant}_1024.png"
  [[ -f "$src" ]] || { echo "Missing $src" >&2; exit 1; }
  ios_set="$IOS_ASSETS/AppIcon-${variant}.appiconset"
  mkdir -p "$ios_set"
  sips -z 120 120 "$src" --out "$ios_set/${variant}-120.png" >/dev/null
  sips -z 180 180 "$src" --out "$ios_set/${variant}-180.png" >/dev/null
  while read -r entry; do
    folder="${entry%%:*}"; size="${entry##*:}"
    sips -z "$size" "$size" "$src" --out "$ANDROID_RES/$folder/${mipmap}.png" >/dev/null
  done <<< "$DENSITIES"
  echo "Synced $variant"
done <<< "$VARIANTS"

default="$V3/grafite_claro_1024.png"
while read -r entry; do
  folder="${entry%%:*}"; size="${entry##*:}"
  sips -z "$size" "$size" "$default" --out "$ANDROID_RES/$folder/ic_launcher.png" >/dev/null
done <<< "$DENSITIES"
echo "Done."
