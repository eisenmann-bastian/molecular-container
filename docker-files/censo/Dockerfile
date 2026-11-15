FROM condaforge/miniforge3:latest AS build

RUN conda create -y -p /opt/censo -c conda-forge --strict-channel-priority python=3.12 pip xtb=6.7.1 \
    && /opt/censo/bin/python -m pip install --no-cache-dir censo==3.0.8 \
    && conda clean -afy

FROM orca:latest

COPY --from=build /opt/censo /opt/censo
ENV PATH="/opt/censo/bin:/opt/orca:/opt/openmpi/4.1.8/bin:${PATH}"
WORKDIR /work
ENTRYPOINT ["censo"]
CMD ["--help"]