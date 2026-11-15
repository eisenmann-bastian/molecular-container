#!/bin/sh
set -eu

if [ "$#" -ne 0 ]; then
    echo "Usage: $0" >&2
    exit 2
fi

example=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/orca-example.XXXXXXXX")
trap 'rm -rf "$work"' EXIT
trap 'exit 1' HUP INT TERM
cp "$example/water.inp" "$work/water.inp"

if ! docker run --rm --pull=never --user "$(id -u):$(id -g)" \
    -v "$work:/work" orca water.inp > "$work/water.out" 2>&1; then
    echo "ORCA container failed:" >&2
    cat "$work/water.out" >&2
    exit 1
fi
if ! grep -q 'ORCA TERMINATED NORMALLY' "$work/water.out"; then
    echo "ORCA did not terminate normally:" >&2
    cat "$work/water.out" >&2
    exit 1
fi
if ! grep -q 'Program running with 2 parallel MPI-processes' "$work/water.out"; then
    echo "ORCA did not report two MPI processes:" >&2
    cat "$work/water.out" >&2
    exit 1
fi
grep 'FINAL SINGLE POINT ENERGY' "$work/water.out"
echo "ORCA test passed."
