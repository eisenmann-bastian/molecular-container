#!/bin/sh
set -eu

if [ "$#" -ne 0 ]; then
    echo "Usage: $0" >&2
    exit 2
fi

root=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
images="$root/docker-files"
orca_binaries=${ORCA_BINARY_DIR:-"$root/../binaries/orca/arm64"}
mpi_binaries=${OPENMPI_BINARY_DIR:-"$root/../binaries/openmpi/arm64"}
orca_archive=${ORCA_ARCHIVE:-}
mpi_archive=${OPENMPI_ARCHIVE:-openmpi-4.1.8-linux-arm64.tar.gz}
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
    if [ "${directory##*/}" = orca ]; then
        if [ ! -d "$orca_binaries" ] || [ ! -d "$mpi_binaries" ]; then
            echo "ORCA or Open MPI binary directory not found; set ORCA_BINARY_DIR and OPENMPI_BINARY_DIR." >&2
            exit 1
        fi
        if [ -z "$orca_archive" ]; then
            set -- "$orca_binaries"/orca_*_linux_arm64_shared_openmpi418.tar.xz
            if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
                echo "Expected exactly one ARM64 ORCA Open MPI 4.1.8 archive in $orca_binaries; set ORCA_ARCHIVE to select a file." >&2
                exit 1
            fi
            orca_archive=${1##*/}
        fi
        case "$orca_archive" in
            */*|.|..|''|*[!a-zA-Z0-9._+-]*)
                echo "ORCA_ARCHIVE must be a simple filename." >&2
                exit 1 ;;
        esac
        case "$orca_archive" in
            *.tar.xz) ;;
            *) echo "ORCA_ARCHIVE must be a .tar.xz file." >&2; exit 1 ;;
        esac
        case "$mpi_archive" in
            */*|.|..|''|*[!a-zA-Z0-9._+-]*)
                echo "OPENMPI_ARCHIVE must be a simple filename." >&2
                exit 1 ;;
        esac
        case "$mpi_archive" in
            *.tar.gz) ;;
            *) echo "OPENMPI_ARCHIVE must be a .tar.gz file." >&2; exit 1 ;;
        esac
        if [ ! -f "$orca_binaries/$orca_archive" ]; then
            echo "ORCA archive not found: $orca_binaries/$orca_archive" >&2
            exit 1
        fi
        if [ ! -f "$mpi_binaries/$mpi_archive" ]; then
            echo "Open MPI archive not found: $mpi_binaries/$mpi_archive" >&2
            exit 1
        fi
        orca_binaries=$(CDPATH= cd -- "$orca_binaries" && pwd)
        mpi_binaries=$(CDPATH= cd -- "$mpi_binaries" && pwd)
    fi
    count=$((count + 1))
done
if [ "$count" -eq 0 ]; then
    echo "No image directories found in $images" >&2
    exit 1
fi

build_image() {
    directory=$1
    name=${directory##*/}
    printf 'Building image %s from %s\n' "$name" "$directory"
    if [ "$name" = orca ]; then
        docker build --platform linux/arm64 \
            --build-context "orca_binaries=$orca_binaries" \
            --build-context "mpi_binaries=$mpi_binaries" \
            --build-arg "ORCA_ARCHIVE=$orca_archive" \
            --build-arg "OPENMPI_ARCHIVE=$mpi_archive" \
            -t "$name" "$directory"
    elif [ "$name" = censo ]; then
        docker build --platform linux/arm64 -t "$name" "$directory"
    else
        docker build -t "$name" "$directory"
    fi
}

if [ -d "$images/orca" ]; then
    build_image "$images/orca"
fi

for directory in "$images"/* "$images"/.[!.]* "$images"/..?*; do
    [ -d "$directory" ] || continue
    [ "${directory##*/}" != orca ] || continue
    build_image "$directory"
done
