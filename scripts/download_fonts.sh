#!/usr/bin/env sh
set -eu
mkdir -p assets/fonts
BASE="https://raw.githubusercontent.com/google/fonts/main/ofl/tajawal"
for WEIGHT in Regular Medium Bold ExtraBold Black; do
  curl -fL "$BASE/Tajawal-$WEIGHT.ttf" -o "assets/fonts/Tajawal-$WEIGHT.ttf"
  test -s "assets/fonts/Tajawal-$WEIGHT.ttf"
done
echo "Bundled Tajawal Arabic font weights installed."
