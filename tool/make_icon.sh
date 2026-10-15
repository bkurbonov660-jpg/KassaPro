#!/bin/bash
# Иконка приложения из assets/icon/icon.png (ImageMagick на сервере GitHub)
set -e
SRC=assets/icon/icon.png
if [ ! -s "$SRC" ]; then echo "Иконки нет — остаётся стандартная"; exit 0; fi
IM=$(command -v magick || command -v convert || true)
if [ -z "$IM" ]; then echo "ImageMagick не найден — остаётся стандартная иконка"; exit 0; fi
RES=android/app/src/main/res
BG="#16111D"
$IM "$SRC" -background "$BG" -alpha remove -alpha off -resize 1024x1024 -gravity center -extent 1024x1024 /tmp/legacy.png
$IM "$SRC" -resize 300x300 -background none -gravity center -extent 432x432 /tmp/fg.png
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
echo "Иконка установлена"
