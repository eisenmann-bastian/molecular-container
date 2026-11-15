#!/bin/sh
set -eu

if [ "$#" -ne 0 ]; then
    echo "Usage: $0" >&2
    exit 2
fi

example=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/openbabel-example.XXXXXXXX")
trap 'rm -rf "$work"' EXIT
trap 'exit 1' HUP INT TERM
cp "$example/ethanol.smi" "$work/"

docker run --rm --pull=never --user "$(id -u):$(id -g)" \
    -v "$work:/work" openbabel -ismi /work/ethanol.smi -osdf --gen2d -O /work/ethanol.sdf
docker run --rm --pull=never --user "$(id -u):$(id -g)" \
    -v "$work:/work:ro" --entrypoint python3 openbabel -c '
from openbabel import pybel

molecules = list(pybel.readfile("sdf", "/work/ethanol.sdf"))
if len(molecules) != 1 or molecules[0].formula != "C2H6O":
    raise SystemExit("Open Babel output does not contain one ethanol molecule")
if molecules[0].dim != 2:
    raise SystemExit("Open Babel output does not contain 2D coordinates")
print("Open Babel test passed: ethanol converted to SDF.")
'
