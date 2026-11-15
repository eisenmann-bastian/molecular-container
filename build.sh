#!/bin/sh
set -eu

if [ "$#" -ne 0 ]; then
    echo "Usage: $0" >&2
    exit 2
fi

root=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
images="$root/docker-files"
if [ ! -d "$images" ]; then
    echo "Dockerfile directory not found: $images" >&2
    exit 1
fi
if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is required to build images." >&2
    exit 1
fi

count=0
for directory in "$images"/* "$images"/.[!.]* "$images"/..?*; do
    [ -d "$directory" ] || continue
    if [ ! -f "$directory/Dockerfile" ]; then
        echo "Missing Dockerfile in image directory: $directory" >&2
        exit 1
    fi
    count=$((count + 1))
done
if [ "$count" -eq 0 ]; then
    echo "No image directories found in $images" >&2
    exit 1
fi

for directory in "$images"/* "$images"/.[!.]* "$images"/..?*; do
    [ -d "$directory" ] || continue
    name=${directory##*/}
    printf 'Building image %s from %s\n' "$name" "$directory"
    docker build -t "$name" "$directory"
done
