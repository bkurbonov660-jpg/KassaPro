#!/bin/bash
set -e
flutter pub add --dev flutter_launcher_icons
cat >> pubspec.yaml << 'YAML'

flutter_launcher_icons:
  android: true
  image_path: "assets/icon/icon.png"
  adaptive_icon_background: "#16111D"
  adaptive_icon_foreground: "assets/icon/icon.png"
YAML
flutter pub get
dart run flutter_launcher_icons
