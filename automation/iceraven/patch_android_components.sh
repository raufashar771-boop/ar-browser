#!/usr/bin/env bash

shopt -s globstar

cp automation/iceraven/assets/*.xml android-components/components/feature/search/src/main/assets/searchplugins
cp -f automation/iceraven/assets/list.json android-components/components/feature/search/src/main/assets/search

search_engines=( startpage brave )
for engine in "${search_engines[@]}"
do
  sed -i "44i\    \"$engine\"," android-components/components/feature/search/src/main/java/mozilla/components/feature/search/storage/SearchEngineReader.kt
done

sed -i "s#gleanPythonEnvDir#// gleanPythonEnvDir#g" android-components/**/*.gradle
sed -i "s#\.\./\.\./\.\./\.\./\.\./gradle/libs.versions.toml#../../../gradle/libs.versions.toml#g" android-components/**/*.gradle

# De-telemetry: the Glean gradle plugin is no longer on the build classpath, so the
# `apply plugin: "org.mozilla.telemetry.glean-gradle-plugin"` lines and the
# `gleanNamespace = "mozilla.telemetry.glean"` lines must be removed or the build fails.
# NOTE: do NOT strip these from service/nimbus -- nimbus Kotlin code references the
# generated `GleanMetrics`/`Microsurvey` symbols, so the plugin MUST stay applied there.
GLEAN_FILES=(
  android-components/components/browser/engine-gecko/build.gradle
  android-components/components/lib/crash/build.gradle
  android-components/samples/glean/build.gradle
  android-components/samples/glean/samples-glean-library/build.gradle
)
for f in "${GLEAN_FILES[@]}"; do
  [ -f "$f" ] || continue
  sed -i '/apply plugin: "org.mozilla.telemetry.glean-gradle-plugin"/d' "$f"
  sed -i '/gleanNamespace = "mozilla.telemetry.glean"/d' "$f"
done

# Some library modules have no `release` publishing component; guard against that.
sed -i 's#from components.release#from components.findByName("release")#g' android-components/publish.gradle

sed -i 's#mobile/android/version.txt#version.txt#g' android-components/plugins/config/src/main/java/ConfigPlugin.kt
sed -i 's#mobile/android/##g' android-components/components/lib/crash/build.gradle

git -C android-components apply < automation/iceraven/patches/top_sites_no_most_visted_sites.patch
git -C android-components apply < automation/iceraven/patches/toolbar.patch

python automation/iceraven/toolkit/crashreporter/generate_crash_reporter_sources.py

mkdir -p netwerk/dns
version=$(sed 's/\./_/g' version.txt)
tag=FIREFOX-ANDROID_${version}_RELEASE
wget https://raw.githubusercontent.com/mozilla-firefox/firefox/refs/tags/${tag}/netwerk/dns/effective_tld_names.dat -O netwerk/dns/effective_tld_names.dat