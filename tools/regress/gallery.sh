#!/usr/bin/env bash
# tools/regress/gallery.sh — never again a surface that drifts out of the grammar (r27-17, "one
# design, one unit"): every surface opened as a person opens it, in both themes, the same box in
# dark and light and the box tools/regress/gallery-expect.json has (tools/gallery.sh --check). A
# surface redesigned on purpose is recorded anew with tools/gallery.sh --record.
#   bash tools/regress/gallery.sh [KIT OPTION…]
# Exit 0 held · 1 broken (each surface said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-gallery.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
rc=0; bash "$here/../gallery.sh" --check --out "$out/shots" "$@" >"$out/log" 2>&1 || rc=$?
((rc == 0)) && { echo "gallery: held — $(grep -c . "$here/gallery-expect.json") numbers, every surface the same box in both themes and as recorded"; exit 0; }
grep -E ' — the reference | ≠ ' "$out/log" >&2 || tail -n 4 "$out/log" >&2
((rc == 1)) && echo "gallery: $(grep -cE ' — the reference | ≠ ' "$out/log") differ from the record (redesigned on purpose: bash tools/gallery.sh --record, the same options)"
exit "$rc"
