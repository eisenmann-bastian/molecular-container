#!/bin/sh
set -eu

if [ "$#" -ne 0 ]; then
    echo "Usage: $0" >&2
    exit 2
fi

example=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$example/../common.sh"
create_example_workdir "$example" autodock-vina
cp "$example/receptor.pdbqt" "$example/ligand.pdbqt" "$example/receptor.box.txt" "$work/"

if ! docker run --rm --pull=never --user "$(id -u):$(id -g)" \
    -v "$work:/work" autodock-vina \
    --receptor receptor.pdbqt --ligand ligand.pdbqt \
    --config receptor.box.txt \
    --exhaustiveness 1 --cpu 1 --seed 42 --out docked.pdbqt \
    > "$work/vina.out" 2>&1; then
    echo "AutoDock Vina container failed:" >&2
    cat "$work/vina.out" >&2
    exit 1
fi
if [ ! -s "$work/docked.pdbqt" ]; then
    echo "AutoDock Vina did not produce docked.pdbqt:" >&2
    cat "$work/vina.out" >&2
    exit 1
fi
echo "AutoDock Vina completed."
