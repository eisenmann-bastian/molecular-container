#!/bin/sh
set -eu

if [ "$#" -ne 0 ]; then
    echo "Usage: $0" >&2
    exit 2
fi

example=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$example/../common.sh"
create_example_workdir "$example" nextflow
cp "$example/main.nf" "$example/greetings.csv" "$work/"

if ! docker run --rm --pull=never --user "$(id -u):$(id -g)" \
    -e NXF_OFFLINE=true -v "$work:/work" nextflow run main.nf \
    > "$work/nextflow.out" 2>&1; then
    echo "Nextflow container failed:" >&2
    cat "$work/nextflow.out" >&2
    exit 1
fi
if [ ! -f "$work/output/greeting.txt" ] || [ ! -f "$work/output/uppercase.txt" ] ||
    [ "$(cat "$work/output/greeting.txt")" != "Hello World!" ] ||
    [ "$(cat "$work/output/uppercase.txt")" != "HELLO WORLD!" ]; then
    echo "Nextflow did not produce the expected greetings:" >&2
    cat "$work/nextflow.out" >&2
    exit 1
fi
echo "Nextflow completed."
