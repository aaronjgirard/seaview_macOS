#!/bin/bash

#********************************************************************************
# package_seaview_dmg.sh
#
# Package SeaView.app into a distributable .dmg with an ad-hoc codesign.
# Without the signature, Gatekeeper's "Open Anyway" clears the .app's quarantine
# bit but not the nested libcsJNIlib.dylib, so the JVM dies at startup trying
# to dlopen an unsigned library (symptom: Dock icon bounces, then disappears).
#
# Inputs (built earlier by make_seaseis_macos.sh and make_java.sh):
#   ${LIBDIR}/SeaView.jar
#   ${LIBDIR}/CSeisLib.jar
#   ${LIBDIR}/libcsJNIlib.dylib
#
# Output:
#   ${THISDIR}/dist/SeaView-${app_ver}.dmg
#
# Usage (run from repo root): bash src/make/macos/package_seaview_dmg.sh [app_ver]
#********************************************************************************

set -euo pipefail

source src/make/macos/set_environment.sh

app_ver="${1:-1.0}"
app_name="SeaView"
main_jar="SeaView.jar"
main_cls="cseis.seaview.SeaView"

dist_dir="${THISDIR}/dist"
stage_dir=$(mktemp -d -t seaview_stage.XXXXXX)
build_dir=$(mktemp -d -t seaview_build.XXXXXX)
trap 'rm -rf "${stage_dir}" "${build_dir}"' EXIT

mkdir -p "${dist_dir}"

## prefer Apple's codesign over any conda/homebrew shim
if [ -x /usr/bin/codesign ]; then
    CSIGN=/usr/bin/codesign
else
    CSIGN=codesign
fi

echo "Staging packaging inputs from ${LIBDIR} ..."
cp "${LIBDIR}/${main_jar}"       "${stage_dir}/"
cp "${LIBDIR}/CSeisLib.jar"      "${stage_dir}/"
cp "${LIBDIR}/libcsJNIlib.dylib" "${stage_dir}/"

## step 1: build the unsigned (or ad-hoc-by-jpackage-default) app-image
echo "Building app-image with jpackage ..."
jpackage \
    --type        app-image \
    --name        "${app_name}" \
    --app-version "${app_ver}" \
    --input       "${stage_dir}" \
    --main-jar    "${main_jar}" \
    --main-class  "${main_cls}" \
    --java-options '-Djava.library.path=$APPDIR' \
    --java-options '--enable-native-access=ALL-UNNAMED' \
    --dest        "${build_dir}"

app_path="${build_dir}/${app_name}.app"

## step 2: ad-hoc sign the bundle as a unit so the JVM trusts the JNI dylib
##         once the user clears Gatekeeper on the outer .app
echo "Ad-hoc signing ${app_path} ..."
"${CSIGN}" --force --deep --sign - "${app_path}"
"${CSIGN}" --verify --verbose=2 "${app_path}"

## step 3: wrap the signed app-image into a dmg (no resigning happens here)
echo "Packaging dmg from signed app-image ..."
rm -f "${dist_dir}/${app_name}-${app_ver}.dmg"
jpackage \
    --type        dmg \
    --name        "${app_name}" \
    --app-version "${app_ver}" \
    --app-image   "${app_path}" \
    --dest        "${dist_dir}"

echo "Done. Output: ${dist_dir}/${app_name}-${app_ver}.dmg"
