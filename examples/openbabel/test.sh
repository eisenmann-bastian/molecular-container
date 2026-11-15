#!/bin/sh
set -eu

if [ "$#" -ne 0 ]; then
    echo "Usage: $0" >&2
    exit 2
fi

example=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$example/../common.sh"
create_example_workdir "$example" openbabel
cp "$example/ethanol.smi" "$work/"

if ! docker run --rm --pull=never --user "$(id -u):$(id -g)" \
    -v "$work:/work" openbabel -ismi /work/ethanol.smi -osdf --gen2d -O /work/ethanol.sdf \
    > "$work/openbabel.out" 2>&1; then
    echo "Open Babel container failed:" >&2
    cat "$work/openbabel.out" >&2
    exit 1
fi
if [ ! -s "$work/ethanol.sdf" ]; then
    echo "Open Babel did not produce ethanol.sdf." >&2
    exit 1
fi
echo "Open Babel completed."
