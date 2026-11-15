#!/bin/sh
set -eu

if [ "$#" -ne 0 ]; then
    echo "Usage: $0" >&2
    exit 2
fi

example=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/xtb-example.XXXXXXXX")
trap 'rm -rf "$work"' EXIT
trap 'exit 1' HUP INT TERM
cp "$example/water.xyz" "$work/"

if ! docker run --rm --pull=never --user "$(id -u):$(id -g)" \
    -e OMP_NUM_THREADS=1 -v "$work:/work" xtb water.xyz --gfn 2 \
    > "$work/xtb.out" 2>&1; then
    echo "xTB container failed:" >&2
    cat "$work/xtb.out" >&2
    exit 1
fi
if ! grep -qi 'normal termination of xtb' "$work/xtb.out"; then
    echo "xTB did not terminate normally:" >&2
    cat "$work/xtb.out" >&2
    exit 1
fi
if ! grep -q 'TOTAL ENERGY' "$work/xtb.out"; then
    echo "xTB output did not contain a total energy:" >&2
    cat "$work/xtb.out" >&2
    exit 1
fi
grep 'TOTAL ENERGY' "$work/xtb.out" | tail -1
echo "xTB test passed."
