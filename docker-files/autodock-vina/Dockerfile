FROM ubuntu:26.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends autodock-vina \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
ENTRYPOINT ["vina"]
CMD ["--help"]