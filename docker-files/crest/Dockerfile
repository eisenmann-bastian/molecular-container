FROM condaforge/miniforge3:latest AS build

RUN conda create -y -p /opt/crest -c conda-forge --strict-channel-priority crest=3.0.2 xtb=6.7.1 \
    && conda clean -afy

FROM ubuntu:26.04

COPY --from=build /opt/crest /opt/crest
ENV PATH="/opt/crest/bin:${PATH}"
WORKDIR /work
ENTRYPOINT ["crest"]
CMD ["--help"]