#!/bin/bash
# Иконка и логотип приложения (ImageMagick на сервере GitHub)
set -e
mkdir -p assets/icon
SRC=assets/icon/icon.png
IM=$(command -v magick || command -v convert || true)
if [ -z "$IM" ]; then echo "::warning::ImageMagick не найден - остаётся стандартная иконка"; exit 0; fi

valid() { [ -s "$1" ] && head -c 4 "$1" | grep -aq PNG; }

if ! valid "$SRC"; then
  rm -f "$SRC"
  for U in "https://i.ibb.co/RGw0P1R4/pulse-logo-11.png" "https://i.ibb.co/gbKTwGkF/pulse-logo-11.png"; do
    curl -fsSL --retry 2 --max-time 60 -A "Mozilla/5.0" -e "https://ibb.co/" -o "$SRC" "$U" || true
    if valid "$SRC"; then echo "Логотип скачан: $U"; break; fi
    rm -f "$SRC"
  done
fi
if ! valid "$SRC"; then
  echo "::warning::Логотип не скачался - рисуем встроенную иконку-пульс"
  $IM -size 1024x1024 xc:"#16111D" -stroke "#FF7A9C" -strokewidth 64 -fill none \
    -draw "stroke-linecap round stroke-linejoin round polyline 150,540 370,540 450,290 570,780 660,470 710,540 874,540" "$SRC"
fi

RES=android/app/src/main/res
$IM "$SRC" -background "#16111D" -alpha remove -alpha off -resize 1024x1024 -gravity center -extent 1024x1024 /tmp/legacy.png
$IM "$SRC" -resize 300x300 -background none -gravity center -extent 432x432 /tmp/fg.png
$IM /tmp/legacy.png -resize 256x256 assets/icon/logo.png
for p in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  d="$RES/mipmap-${p%%:*}"
  s="${p##*:}"
  mkdir -p "$d"
  $IM /tmp/legacy.png -resize "${s}x${s}" "$d/ic_launcher.png"
done
mkdir -p "$RES/mipmap-anydpi-v26" "$RES/mipmap-xxxhdpi" "$RES/values"
cp /tmp/fg.png "$RES/mipmap-xxxhdpi/ic_launcher_foreground.png"
cat > "$RES/mipmap-anydpi-v26/ic_launcher.xml" << 'XML'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
XML
cat > "$RES/values/ic_launcher_background.xml" << 'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#16111D</color>
</resources>
XML
echo "Иконка и логотип установлены"
