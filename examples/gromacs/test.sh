#!/bin/sh
set -eu

if [ "$#" -ne 0 ]; then
    echo "Usage: $0" >&2
    exit 2
fi

example=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$example/../common.sh"
create_example_workdir "$example" gromacs

if ! docker run --rm --pull=never --user "$(id -u):$(id -g)" \
    -v "$work:/work" gromacs solvate \
    -cs spc216.gro -box 2 2 2 -o water.gro \
    > "$work/gromacs.out" 2>&1; then
    echo "GROMACS container failed:" >&2
    cat "$work/gromacs.out" >&2
    exit 1
fi
if [ ! -s "$work/water.gro" ]; then
    echo "GROMACS did not produce water.gro:" >&2
    cat "$work/gromacs.out" >&2
    exit 1
fi
echo "GROMACS completed."
