FROM ubuntu:26.04 AS build

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential ca-certificates python3 python3-dev python3-venv \
    && python3 -m venv /opt/snakemake \
    && /opt/snakemake/bin/python -m pip install --no-cache-dir snakemake \
    && /opt/snakemake/bin/python -m pip check \
    && rm -rf /var/lib/apt/lists/*

FROM ubuntu:26.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates python3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /opt/snakemake /opt/snakemake
ENV PATH="/opt/snakemake/bin:${PATH}" \
    HOME=/work \
    XDG_CACHE_HOME=/work/.cache \
    USER=snakemake
WORKDIR /work
ENTRYPOINT ["snakemake"]
CMD ["--help"]