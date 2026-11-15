FROM ubuntu:26.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 python3-venv libx11-6 libxext6 libxrender1 \
    && python3 -m venv /opt/openbabel \
    && /opt/openbabel/bin/python -m pip install --no-cache-dir --only-binary=:all: openbabel-wheel==3.1.1.23 \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/openbabel/bin:${PATH}"
WORKDIR /work
ENTRYPOINT ["obabel"]
CMD ["-H"]
