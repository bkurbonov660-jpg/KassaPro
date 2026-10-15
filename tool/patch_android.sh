#!/bin/bash
# Патч Android-проекта: интернет, название, подпись release-ключом
set -e
APP=android/app
M=$APP/src/main/AndroidManifest.xml

if ! grep -q 'android.permission.INTERNET' "$M"; then
  sed -i 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' "$M"
fi
sed -i 's#android:label="[^"]*"#android:label="Дорама Пульс"#' "$M"

if [ -f "$APP/build.gradle.kts" ]; then
  F=$APP/build.gradle.kts
  if ! grep -q 'import java.util.Properties' "$F"; then
    sed -i '1i import java.util.Properties\nimport java.io.FileInputStream' "$F"
  fi
  if ! grep -q 'doramaRelease' "$F"; then
    sed -i 's|^android {|android {\n    signingConfigs {\n        create("doramaRelease") {\n            val kp = Properties()\n            kp.load(FileInputStream(rootProject.file("key.properties")))\n            keyAlias = kp.getProperty("keyAlias")\n            keyPassword = kp.getProperty("keyPassword")\n            storeFile = file(kp.getProperty("storeFile"))\n            storePassword = kp.getProperty("storePassword")\n        }\n    }|' "$F"
  fi
  sed -i 's|signingConfigs.getByName("debug")|signingConfigs.getByName("doramaRelease")|g' "$F"
  grep -q 'getByName("doramaRelease")' "$F" || echo "::warning::release-подпись не применилась (kts)"
elif [ -f "$APP/build.gradle" ]; then
  F=$APP/build.gradle
  if ! grep -q 'doramaRelease' "$F"; then
    sed -i 's|^android {|android {\n    signingConfigs {\n        doramaRelease {\n            def kp = new java.util.Properties()\n            kp.load(new java.io.FileInputStream(rootProject.file("key.properties")))\n            keyAlias kp.getProperty("keyAlias")\n            keyPassword kp.getProperty("keyPassword")\n            storeFile file(kp.getProperty("storeFile"))\n            storePassword kp.getProperty("storePassword")\n        }\n    }|' "$F"
  fi
  sed -i 's|signingConfig signingConfigs.debug|signingConfig signingConfigs.doramaRelease|g' "$F"
  grep -q 'signingConfigs.doramaRelease' "$F" || echo "::warning::release-подпись не применилась (groovy)"
else
  echo "::error::build.gradle не найден"; exit 1
fi
echo "Android patched"
