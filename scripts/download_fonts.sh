#!/usr/bin/env sh
set -eu
mkdir -p assets/fonts
FONT_URL="https://raw.githubusercontent.com/google/fonts/main/ofl/tajawal/Tajawal%5Bwght%5D.ttf"
curl -fL "$FONT_URL" -o assets/fonts/Tajawal-Variable.ttf
test -s assets/fonts/Tajawal-Variable.ttf
echo "Tajawal variable font installed locally."
