#!/bin/sh
set -eu

if [ "$#" -ne 0 ]; then
    echo "Usage: $0" >&2
    exit 2
fi

example=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/pymol-example.XXXXXXXX")
trap 'rm -rf "$work"' EXIT
trap 'exit 1' HUP INT TERM
cp "$example/render.py" "$example/molecule.sdf" "$work/"

docker run --rm --pull=never --user "$(id -u):$(id -g)" \
    -v "$work:/work" --entrypoint python3 pymol /work/render.py
docker run --rm --pull=never --user "$(id -u):$(id -g)" \
    -v "$work:/work:ro" --entrypoint python3 pymol -c '
import struct
from pathlib import Path

header = Path("/work/molecule.png").read_bytes()[:24]
if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
    raise SystemExit("PyMOL did not produce a valid PNG header")
if struct.unpack(">II", header[16:24]) != (1200, 900):
    raise SystemExit("PyMOL output does not have the expected dimensions")
print("PyMOL test passed: 1200x900 PNG.")
'
