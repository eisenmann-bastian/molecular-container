FROM condaforge/miniforge3:latest AS build

RUN conda create -y -p /opt/unigbsa -c conda-forge --strict-channel-priority \
        python=3.12 pip acpype gmx_mmpbsa=1.7.1 gromacs openmpi mpi4py rdkit \
    && conda clean -afy

RUN /opt/unigbsa/bin/python -m pip install --no-cache-dir --no-deps unigbsa==0.1.7 lickit==0.1.0

FROM ubuntu:26.04

COPY --from=build /opt/unigbsa /opt/unigbsa
ENV PATH="/opt/unigbsa/bin:${PATH}"
ENV AMBERHOME="/opt/unigbsa"
WORKDIR /work
ENTRYPOINT ["unigbsa-pipeline"]
CMD ["--help"]