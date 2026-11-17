FROM condaforge/miniforge3:latest AS build

RUN conda create -y -p /opt/gromacs -c conda-forge --strict-channel-priority "gromacs=2026.3=nompi_h*" \
    && conda clean -afy

FROM ubuntu:26.04

COPY --from=build /opt/gromacs /opt/gromacs
ENV PATH="/opt/gromacs/bin:${PATH}"
WORKDIR /work
ENTRYPOINT ["gmx"]
CMD ["--help"]