#!/bin/sh
set -eu

if [ "$#" -ne 0 ]; then
    echo "Usage: $0" >&2
    exit 2
fi

example=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$example/../common.sh"
create_example_workdir "$example" pymol
cp "$example/render.py" "$example/molecule.sdf" "$work/"

if ! docker run --rm --pull=never --user "$(id -u):$(id -g)" \
    -v "$work:/work" --entrypoint python3 pymol /work/render.py \
    > "$work/pymol.out" 2>&1; then
    echo "PyMOL container failed:" >&2
    cat "$work/pymol.out" >&2
    exit 1
fi
if [ ! -s "$work/molecule.png" ]; then
    echo "PyMOL did not produce molecule.png." >&2
    exit 1
fi
echo "PyMOL completed."
