#!/bin/sh
set -eu

if [ "$#" -ne 0 ]; then
    echo "Usage: $0" >&2
    exit 2
fi

example=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$example/../common.sh"
create_example_workdir "$example" workflow
cp "$example/workflow.ini" "$example/water-ensemble.xyz" "$work/"

if ! docker run --rm --pull=never --user "$(id -u):$(id -g)" \
    -e HOME=/work -e OMP_NUM_THREADS=1 -v "$work:/work" censo \
    --prescreening --screening --optimization --refinement --nmr --uvvis \
    -i water-ensemble.xyz --inprc workflow.ini --maxcores 1 --omp-min 1 \
    > "$work/censo.out" 2>&1; then
    echo "CENSO workflow failed:" >&2
    cat "$work/censo.out" >&2
    exit 1
fi
if ! grep -Fq 'CENSO all done!' "$work/censo.out"; then
    echo "CENSO did not report normal completion:" >&2
    cat "$work/censo.out" >&2
    exit 1
fi
echo "CENSO workflow completed."
