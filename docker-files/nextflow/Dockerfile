FROM ubuntu:26.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl openjdk-21-jre-headless \
    && curl -fsSL -o /tmp/install-nextflow https://get.nextflow.io \
    && cd /tmp \
    && NXF_HOME=/tmp/nextflow-home NXF_DIST=/opt/nextflow/framework bash < install-nextflow \
    && install -m 755 nextflow /usr/local/bin/nextflow \
    && chmod -R a+rX /opt/nextflow/framework \
    && rm -rf /tmp/install-nextflow /tmp/nextflow /tmp/nextflow-home \
    && rm -rf /var/lib/apt/lists/*

ENV NXF_DIST=/opt/nextflow/framework \
    NXF_HOME=/work/.nextflow-home
WORKDIR /work
ENTRYPOINT ["nextflow"]
CMD ["-help"]