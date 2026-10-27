#!/bin/bash
set -e
mkdir -p assets/icon
IM=$(command -v magick || command -v convert || true)
if [ -z "$IM" ]; then exit 0; fi

$IM -size 1024x1024 xc:"#16111D" \
  -stroke "#5FD9B4" -strokewidth 54 -fill none \
  -draw "roundrectangle 140,140 884,884 200,200" \
  -stroke "#FF7A9C" -strokewidth 48 -fill none \
  -draw "stroke-linecap round stroke-linejoin round polyline 250,530 400,530 465,320 555,730 630,460 774,460" \
  /tmp/aegis_icon.png

cp /tmp/aegis_icon.png assets/icon/logo.png
RES=android/app/src/main/res
for p in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  d="$RES/mipmap-${p%%:*}"
  s="${p##*:}"
  mkdir -p "$d"
  $IM /tmp/aegis_icon.png -resize "${s}x${s}" "$d/ic_launcher.png"
done
