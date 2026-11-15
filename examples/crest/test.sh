#!/bin/sh
set -eu

if [ "$#" -ne 0 ]; then
    echo "Usage: $0" >&2
    exit 2
fi

example=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/crest-example.XXXXXXXX")
trap 'rm -rf "$work"' EXIT
trap 'exit 1' HUP INT TERM
cp "$example/water.xyz" "$work/"

if ! docker run --rm --pull=never --user "$(id -u):$(id -g)" \
    -e OMP_NUM_THREADS=1 -v "$work:/work" crest water.xyz -T 1 -mquick \
    > "$work/crest.out" 2>&1; then
    echo "CREST container failed:" >&2
    cat "$work/crest.out" >&2
    exit 1
fi
if ! grep -q 'CREST terminated normally' "$work/crest.out"; then
    echo "CREST did not terminate normally:" >&2
    cat "$work/crest.out" >&2
    exit 1
fi
if [ ! -s "$work/crest_conformers.xyz" ]; then
    echo "CREST did not produce a conformer ensemble:" >&2
    cat "$work/crest.out" >&2
    exit 1
fi
if ! awk 'NR == 1 { exit !($1 == 3 && NF == 1) }' "$work/crest_conformers.xyz"; then
    echo "CREST conformer ensemble does not contain the expected water geometry." >&2
    exit 1
fi
echo "CREST test passed: water conformer ensemble generated."
