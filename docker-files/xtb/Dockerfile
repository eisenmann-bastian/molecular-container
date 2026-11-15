FROM condaforge/miniforge3:latest AS build

RUN conda create -y -p /opt/xtb -c conda-forge --strict-channel-priority xtb=6.7.1 \
    && conda clean -afy

FROM ubuntu:26.04

COPY --from=build /opt/xtb /opt/xtb
ENV PATH="/opt/xtb/bin:${PATH}"
WORKDIR /work
ENTRYPOINT ["xtb"]
CMD ["--help"]