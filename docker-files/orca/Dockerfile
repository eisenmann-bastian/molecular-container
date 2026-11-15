FROM ubuntu:26.04

ARG ORCA_ARCHIVE
ARG OPENMPI_ARCHIVE=openmpi-4.1.8-linux-arm64.tar.gz

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 xz-utils openssh-client \
    && rm -rf /var/lib/apt/lists/*

RUN --mount=type=bind,from=orca_binaries,target=/mnt/orca \
    if [ -z "$ORCA_ARCHIVE" ]; then \
        set -- /mnt/orca/orca_*_linux_arm64_shared_openmpi418.tar.xz; \
        if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then \
            echo "Expected exactly one matching ORCA archive; set ORCA_ARCHIVE to select a file" >&2; exit 1; \
        fi; \
        archive=$1; \
    else \
        case "$ORCA_ARCHIVE" in \
            */*|.|..|*[!a-zA-Z0-9._+-]*) echo "ORCA_ARCHIVE must be a simple filename" >&2; exit 1 ;; \
            *.tar.xz) archive="/mnt/orca/$ORCA_ARCHIVE" ;; \
            *) echo "ORCA_ARCHIVE must be a .tar.xz file" >&2; exit 1 ;; \
        esac; \
    fi; \
    test -f "$archive" || { echo "ORCA archive not found: $archive" >&2; exit 1; }; \
    mkdir -p /opt/orca \
    && tar -xJf "$archive" -C /opt/orca --strip-components=1 \
    && test -x /opt/orca/orca

RUN --mount=type=bind,from=mpi_binaries,target=/mnt/mpi \
    case "$OPENMPI_ARCHIVE" in \
        */*|.|..|''|*[!a-zA-Z0-9._+-]*) echo "OPENMPI_ARCHIVE must be a simple filename" >&2; exit 1 ;; \
        *.tar.gz) ;; \
        *) echo "OPENMPI_ARCHIVE must be a .tar.gz file" >&2; exit 1 ;; \
    esac; \
    test -f "/mnt/mpi/$OPENMPI_ARCHIVE" || { echo "Open MPI archive not found: $OPENMPI_ARCHIVE" >&2; exit 1; }; \
    mkdir -p /opt/openmpi/4.1.8 \
    && tar -xzf "/mnt/mpi/$OPENMPI_ARCHIVE" -C /opt/openmpi/4.1.8 \
    && version=$(LD_LIBRARY_PATH=/opt/openmpi/4.1.8/lib /opt/openmpi/4.1.8/bin/mpirun --version) \
    && printf '%s\n' "$version" | grep -Fx 'mpirun (Open MPI) 4.1.8'

ENV PATH="/opt/orca:/opt/openmpi/4.1.8/bin:${PATH}" \
    LD_LIBRARY_PATH="/opt/orca:/opt/openmpi/4.1.8/lib"

WORKDIR /work
ENTRYPOINT ["/opt/orca/orca"]