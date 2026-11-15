# Molecular container

This repository contains Ubuntu 26.04-based PyMOL, ORCA, Open Babel, xTB,
CREST and CENSO images and a
[software list](software-list.txt) for further molecular-computing container
work. The other tools in that list are candidates; they are not installed in
the PyMOL image.

## Contents

- [Build](#build) · [Usage](#usage) · [Contributing](#contributing) ·
  [Contact and support](#contact-and-support) · [License](#license)

## Build

With Docker installed and its daemon running, first prepare the ORCA inputs
described below, then build every image from the repository root:

```sh
./build.sh
```

The script examines each direct subdirectory of `docker-files/`, uses it as
the build context, and tags the image with the directory name (for example,
`pymol:latest`). It stops on the first failure. Every image directory must
contain a `Dockerfile` and have a name valid as a Docker image tag; Docker
reports invalid names. It builds ORCA before CENSO because CENSO uses the ORCA
image as its base. Run it from any working directory.

### ORCA build prerequisites

The ORCA image uses the ARM64 ORCA 6.1 archive built for Open MPI 4.1.8.
Obtain it separately from ORCA and place the `.tar.xz` archive in
`../binaries/orca/arm64/`. ORCA is distributed under its own license; do not
commit or redistribute its archive or image without checking its terms.

Ubuntu 26.04 supplies Open MPI 5, not the required 4.1.8. Build the matching
standalone binary archive using the adjacent `../openmpi-build` project on an
ARM64 Linux machine compatible with Ubuntu 26.04:

```sh
../openmpi-build/build.sh
```

The native build creates
`../binaries/openmpi/arm64/openmpi-4.1.8-linux-arm64.tar.gz`. Transfer the
archive to that directory on the Docker build host if necessary. The
`openmpi-build` project does not build Linux binaries on macOS.
Override the input directories with `ORCA_BINARY_DIR` and
`OPENMPI_BINARY_DIR`, respectively. For example:

```sh
ORCA_BINARY_DIR=/path/to/orca/arm64 OPENMPI_BINARY_DIR=/path/to/openmpi/arm64 ./build.sh
```

Optionally select filenames within those directories with `ORCA_ARCHIVE` and
`OPENMPI_ARCHIVE`:

```sh
ORCA_ARCHIVE=orca_6_1_1_linux_arm64_shared_openmpi418.tar.xz \
OPENMPI_ARCHIVE=openmpi-4.1.8-linux-arm64.tar.gz ./build.sh
```

By default, the script requires exactly one ORCA archive matching
`orca_*_linux_arm64_shared_openmpi418.tar.xz` and uses
`openmpi-4.1.8-linux-arm64.tar.gz`. The filename overrides select files, not
versions or architectures: the ORCA archive must still be a compatible ARM64
build for Open MPI 4.1.8, and the Open MPI archive must contain the ARM64
4.1.8 binary distribution produced by `openmpi-build`. The image's MPI
installation path and target platform remain fixed.

The build requires Docker BuildKit named contexts; the external directories
are not copied into this repository. An ARM64 Docker host is recommended;
other hosts need ARM64 emulation enabled in Docker.

To build just PyMOL manually:

```sh
docker build -t pymol ./docker-files/pymol
```

Run the build-script tests without Docker using
`python3 -m unittest discover -s tests -v`.

The image installs Python and open-source PyMOL from Ubuntu 26.04's
repositories. Ubuntu 26.04 provides Python 3.14 rather than the newest Python
release. It does not include `pymol-utilities`, ORCA, xTB, or OpenBabel.

To build Open Babel on its own:

```sh
docker build -t openbabel ./docker-files/openbabel
```

The image installs Python 3 and the unofficial `openbabel-wheel` distribution
with pip in a virtual environment. Its command-line entrypoint is `obabel`;
its Python API is available by overriding the entrypoint with `python3`.

To build xTB on its own:

```sh
docker build -t xtb ./docker-files/xtb
```

The xTB image uses conda to install xTB 6.7.1 from conda-forge into an
isolated environment, which is copied into the Ubuntu runtime image.

To build CREST on its own:

```sh
docker build -t crest ./docker-files/crest
```

The CREST image installs CREST 3.0.2 and xTB 6.7.1 from conda-forge into an
isolated environment, which is copied into the Ubuntu runtime image.

To build CENSO on its own, first build the `orca:latest` image as described
below, then run:

```sh
docker build --platform linux/arm64 -t censo ./docker-files/censo
```

The CENSO image installs xTB 6.7.1 from conda-forge and CENSO 3.0.8 from
PyPI in a conda environment on top of the ORCA image, which supplies ORCA and
Open MPI. It does not include Turbomole or COSMO-RS. ORCA's licensing terms
also apply to the CENSO image.

To build only ORCA manually, provide both named contexts:

```sh
docker build --platform linux/arm64 \
  --build-context orca_binaries=../binaries/orca/arm64 \
  --build-context mpi_binaries=../binaries/openmpi/arm64 \
  --build-arg ORCA_ARCHIVE=orca_6_1_1_linux_arm64_shared_openmpi418.tar.xz \
  --build-arg OPENMPI_ARCHIVE=openmpi-4.1.8-linux-arm64.tar.gz \
  -t orca ./docker-files/orca
```

These arguments are optional for a manual build: omitting `ORCA_ARCHIVE`
enables the same automatic archive selection, and omitting `OPENMPI_ARCHIVE`
uses the default archive filename above. Previous `OPENMPI_DEB_DIR` and
`OPENMPI_DEB` options are no longer used.

## Usage

Each `examples/<image>/test.sh` is a runnable example using the local image.
It prints its output directory before starting and keeps all results, including
logs from failed runs. Every invocation creates a separate directory under
`examples/<image>/results/`, so it will not overwrite earlier runs. These
directories are ignored by Git and can be removed when no longer needed.
Set `EXAMPLE_OUTPUT_DIR` to use a different writable directory accessible to
Docker, for example:

```sh
EXAMPLE_OUTPUT_DIR="$HOME/molecular-results" ./examples/xtb/test.sh
```

The scripts can be run from any working directory and require Docker and the
corresponding local image. Edit the example inputs and scripts to experiment.

The default container command launches PyMOL in quiet, headless mode and exits
when its commands are complete. To run a smoke test:

```sh
docker run --rm pymol -cq -d 'print(cmd.get_version()); quit'
```

To render a local structure, put a PyMOL script and input files in a directory
and mount it at `/work`. For example, with `render.pml`:

```text
load /work/molecule.pdb, molecule
hide everything
show cartoon, molecule
color teal, molecule
bg_color white
orient molecule
zoom molecule, 3
png /work/molecule.png, 1200, 900, 150, 1
quit
```

```sh
docker run --rm --user "$(id -u):$(id -g)" \
  -v "$PWD:/work" pymol -cq /work/render.pml
```

Input files must be available inside the container. `--user` keeps the
generated image owned by the invoking host user on typical Linux hosts. The
image is configured for headless use; a graphical PyMOL window requires
additional host display integration and is not configured here.

### Python API example

The [PyMOL example](examples/pymol/) uses the Python API to render the
included ethanol SDF. After building the image, run this from the repository
root:

```sh
docker run --rm --user "$(id -u):$(id -g)" \
  -v "$PWD/examples/pymol:/work" \
  --entrypoint python3 pymol /work/render.py
```

The output is `examples/pymol/molecule.png`. Running the example again
overwrites that file. The script runs inside the container; PyMOL does not
need to be installed in the host's Python environment. The `examples/`
subdirectories correspond to the image directories in `docker-files/`.

To run the example in a separate output directory, use:

```sh
./examples/pymol/test.sh
```

### ORCA example

The [ORCA example](examples/orca/water.inp) runs a two-process Hartree–Fock
calculation on water. From the repository root:

```sh
docker run --rm --user "$(id -u):$(id -g)" \
  -v "$PWD/examples/orca:/work" orca water.inp > examples/orca/water.out 2>&1
```

ORCA writes calculation files into the mounted directory; the output file and
other generated files may be overwritten. Use a writable copy of the input
directory for separate runs. Run the ORCA driver directly, not through
`mpirun`; it starts MPI itself. The non-root user is required for Open MPI's
default root-safety check. Check the output for `ORCA TERMINATED NORMALLY`:
some ORCA errors can return a successful process exit status.

To run the example in a separate output directory, use:

```sh
./examples/orca/test.sh
```

Run the ORCA example as a non-root user because Open MPI refuses root by default.

### Open Babel example

Convert the included [ethanol SMILES](examples/openbabel/ethanol.smi) to SDF
with 2D coordinates from the repository root:

```sh
docker run --rm --user "$(id -u):$(id -g)" \
  -v "$PWD/examples/openbabel:/work" openbabel \
  -ismi /work/ethanol.smi -osdf --gen2d -O /work/ethanol.sdf
```

This overwrites `examples/openbabel/ethanol.sdf` if it already exists.
To run the conversion in a separate output directory:

```sh
./examples/openbabel/test.sh
```

### xTB example

Run a GFN2-xTB single-point calculation on the included
[water geometry](examples/xtb/water.xyz) from the repository root:

```sh
docker run --rm --user "$(id -u):$(id -g)" -e OMP_NUM_THREADS=1 \
  -v "$PWD/examples/xtb:/work" xtb water.xyz --gfn 2
```

xTB may write or overwrite calculation files in the mounted directory. Use a
separate writable copy for repeated or concurrent runs. To run the example in
a separate output directory:

```sh
./examples/xtb/test.sh
```

### CREST example

Run a reduced-settings CREST conformer search on the included
[water geometry](examples/crest/water.xyz) from the repository root:

```sh
docker run --rm --user "$(id -u):$(id -g)" -e OMP_NUM_THREADS=1 \
  -v "$PWD/examples/crest:/work" crest water.xyz -T 1 -mquick
```

CREST writes files including `crest_conformers.xyz` into the mounted
directory and may overwrite existing results. Use a separate writable copy
for repeated or concurrent runs. Water keeps this smoke example fast; the
`-mquick` reduced search is not a substitute for a production-quality search.

To run the example in a separate output directory:

```sh
./examples/crest/test.sh
```

### CENSO example

Run the complete ORCA-supported workflow on the included two-geometry water
ensemble:

```sh
./examples/censo/test.sh
```

The [workflow configuration](examples/censo/workflow.ini) enables
prescreening, screening, optimization, refinement, NMR and UV/Vis. It uses
ORCA and GFN2-xTB with water solvation. The example uses small basis sets and
two similar water geometries for a quick demonstration, not a scientifically
meaningful conformer study. Adjust the settings and input for real work.
CENSO 3.0.8 supports optical rotation only with Turbomole, which is not
included in this image, so that stage is not enabled.

The separate [prescreening configuration](examples/censo/prescreening.ini)
can still be used with CENSO's `--prescreening` flag. Prescreening uses
xTB/ALPB for the water-solvation contribution and ORCA PBE-D3/def2-SV(P) for
the DFT single-point energy; xTB alone is not a supported prescreening backend.

To generate a starter configuration from the repository root:

```sh
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/work \
  -v "$PWD/examples/censo:/work" censo --new-config
```

This writes `censo2rc_NEW` and `censo.log` in the mounted directory and may
overwrite existing files. The generated defaults refer to external DFT
programs such as Turbomole that are not included. Review the configuration and
select ORCA or provide the appropriate external programs before running a
refinement.

## Contributing

Open an issue or submit a pull request to propose changes. Document and
validate any container build or runtime behavior introduced later.

## Contact and support

- GitHub: [@eisenmann-bastian](https://github.com/eisenmann-bastian)
- LinkedIn: [Bastian Eisenmann](https://www.linkedin.com/in/bastianeisenmann/)
- [Buy me a coffee](https://buymeacoffee.com/bastian.eisenmann)

## License

[BSD 3-Clause License](LICENSE).