#!/bin/sh
set -eu

if [ "$#" -ne 0 ]; then
    echo "Usage: $0" >&2
    exit 2
fi

example=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$example/../common.sh"
create_example_workdir "$example" snakemake
cp "$example/Snakefile" "$example/greeting.txt" "$work/"

if ! docker run --rm --pull=never --user "$(id -u):$(id -g)" \
    -v "$work:/work" snakemake --cores 1 > "$work/snakemake.out" 2>&1; then
    echo "Snakemake container failed:" >&2
    cat "$work/snakemake.out" >&2
    exit 1
fi
if [ ! -f "$work/output/greeting.txt" ] || [ ! -f "$work/output/uppercase.txt" ] ||
    [ "$(cat "$work/output/greeting.txt")" != "Hello World!" ] ||
    [ "$(cat "$work/output/uppercase.txt")" != "HELLO WORLD!" ]; then
    echo "Snakemake did not produce the expected greetings:" >&2
    cat "$work/snakemake.out" >&2
    exit 1
fi
echo "Snakemake completed."
