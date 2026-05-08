#!/bin/bash

## Rewrite Mach-O install names so seaseis and modules find their .so deps
## without requiring DYLD_LIBRARY_PATH. Each lib gets an absolute install id;
## each consumer's LC_LOAD_DYLIB entries pointing at bare lib*.so / lib*.dylib
## names are rewritten to absolute paths.

LIBDIR="${1:?usage: fix_install_names.sh <libdir> <bindir>}"
BINDIR="${2:?usage: fix_install_names.sh <libdir> <bindir>}"

## prefer Apple's install_name_tool over any conda/homebrew shim
if [ -x /usr/bin/install_name_tool ]; then
    INT=/usr/bin/install_name_tool
elif command -v xcrun >/dev/null 2>&1; then
    INT=$(xcrun -f install_name_tool 2>/dev/null || echo install_name_tool)
else
    INT=install_name_tool
fi

abs_lib=$(cd "${LIBDIR}" && pwd)

echo "Fixing macOS install names in ${abs_lib} (using ${INT}) ..."

shopt -s nullglob
libs=( "${abs_lib}"/lib*.so "${abs_lib}"/lib*.so.* "${abs_lib}"/lib*.dylib )

## pass 1: set absolute install ids on every shared lib
for f in "${libs[@]}"; do
    [ -f "$f" ] || continue
    "$INT" -id "${abs_lib}/$(basename "$f")" "$f" 2>/dev/null || true
done

## pass 2: rewrite every consumer's LC_LOAD_DYLIB entries from bare names to absolute
consumers=( "${BINDIR}/seaseis" "${libs[@]}" )
for f in "${consumers[@]}"; do
    [ -f "$f" ] || continue
    deps=$(otool -L "$f" 2>/dev/null | tail -n +2 | awk '{print $1}')
    for dep in $deps; do
        base=$(basename "$dep")
        case "$base" in
            lib*.so|lib*.so.*|lib*.dylib) ;;
            *) continue ;;
        esac
        target="${abs_lib}/${base}"
        if [ -f "$target" ] && [ "$dep" != "$target" ]; then
            out=$("$INT" -change "$dep" "$target" "$f" 2>&1) || \
                echo "WARN: install_name_tool -change failed on $f: $out" >&2
        fi
    done
done

shopt -u nullglob
echo "Install name fixup done."
