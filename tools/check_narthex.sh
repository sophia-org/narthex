#!/bin/sh
# Local policy/SDK tests require no Sophia source. Optional protected conformance
# uses explicit prebuilt hosts; this launcher never builds a server checkout.
set -eu
case "${1:-}" in
"") conformance=false ;;
--conformance) conformance=true ;;
*) echo "usage: check_narthex.sh [--conformance]" >&2; exit 2 ;;
esac
if "$conformance"; then
    for host in "${SOPHIA_DESCRIPTOR_HOST:-}" "${SOPHIA_LAUNCHER_HOST:-}"; do
        case "$host" in
        /*) [ -f "$host" ] && [ -x "$host" ] || exit 2 ;;
        *) echo "conformance requires absolute executable SOPHIA_DESCRIPTOR_HOST and SOPHIA_LAUNCHER_HOST" >&2; exit 2 ;;
        esac
    done
fi
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT HUP INT TERM
cd "$root"
for unit in tdesktop_sdk tshell_v1 tshell_tabs tshell_reference tshell_launcher; do
    nim c -r --hints:off --path:src \
        --nimcache:"$build_dir/cache-$unit" -o:"$build_dir/$unit" "tests/$unit.nim"
done
nim c --hints:off --path:src --nimcache:"$build_dir/cache-client" \
    -o:"$build_dir/narthex" src/narthex.nim
# Presence of the retired variable is an error, including an empty value.
if env SOPHIA_SHELL_SOCKET= SOPHIA_SHELL_9P_SOCKET=/nonexistent \
    "$build_dir/narthex" --serve >"$build_dir/retired.log" 2>&1; then
    echo "retired socket was accepted" >&2
    exit 1
fi
grep -q "SOPHIA_SHELL_SOCKET" "$build_dir/retired.log"
if "$conformance"; then
    for mode in --proof --bar-proof --serve; do
        timeout -s KILL 60 "$SOPHIA_DESCRIPTOR_HOST" "$build_dir/narthex" "$mode"
    done
    timeout -s KILL 60 "$SOPHIA_LAUNCHER_HOST" "$build_dir/narthex"
fi
