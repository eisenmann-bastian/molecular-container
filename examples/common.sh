#!/bin/sh

create_example_workdir() {
    output_root=${EXAMPLE_OUTPUT_DIR:-"$1/results"}
    mkdir -p "$output_root"
    output_root=$(CDPATH= cd -- "$output_root" && pwd)
    work=$(mktemp -d "$output_root/$2.XXXXXXXX")
    printf 'Output directory: %s\n' "$work"
}
