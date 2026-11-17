# Molecular container

This repository contains Ubuntu 26.04-based PyMOL, ORCA, Open Babel, xTB,
CREST, CENSO, AutoDock Vina, GROMACS, Uni-GBSA and Nextflow images and a
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

To build AutoDock Vina on its own:

```sh
docker build -t autodock-vina ./docker-files/autodock-vina
```

The image installs Ubuntu's `autodock-vina` package and runs the `vina`
command by default. It contains the command-line tools, not Vina's separately
distributed Python bindings or receptor/ligand preparation tools.

To build and smoke-test GROMACS on its own:

```sh
docker build -t gromacs ./docker-files/gromacs
docker run --rm gromacs --version
docker run --rm gromacs help
```

The image installs the prebuilt GROMACS 2026.3 non-MPI package from
conda-forge. Its entrypoint is `gmx`. The tested ARM64 build uses mixed
precision, thread-MPI and OpenMP, and reports OpenCL support; GPU execution
requires a compatible OpenCL runtime and device and has not been tested.
Distributed MPI is not included. To run a command on local files, mount
their directory at `/work`, for example:

```sh
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/work" gromacs \
  grompp -f md.mdp -c system.gro -p topol.top -o run.tpr
```

This requires appropriately prepared inputs and writes `run.tpr` and any
other generated files to the mounted directory.

To build and smoke-test Uni-GBSA:

```sh
docker build -t unigbsa ./docker-files/unigbsa
docker run --rm unigbsa --help
```

The image installs Uni-GBSA 0.1.7 and Lickit from PyPI, with ACPYPE,
gmx_MMPBSA 1.7.1, AmberTools, GROMACS and other scientific dependencies from
conda-forge. Its entrypoint is `unigbsa-pipeline`. For example, with a prepared
protein PDB and ligand SDF in the current directory:

```sh
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/work" unigbsa \
  -i protein.pdb -l ligand.sdf -o BindingEnergy.csv -nt 1
```

The command writes results and intermediate files into the mounted directory;
use a dedicated working directory. The ARM64 image was tested with the
[upstream 1CEB example](https://github.com/dptech-corp/Uni-GBSA/tree/master/example/1ceb).
Review the input structures and calculation settings before scientific use.

To build and smoke-test Nextflow:

```sh
docker build -t nextflow ./docker-files/nextflow
docker run --rm nextflow -version
```

The image includes Java 21 and the current Nextflow release selected by the
[official self-install method](https://docs.seqera.io/nextflow/install) at
build time. To fetch a newer release later, rebuild with `docker build
--no-cache -t nextflow ./docker-files/nextflow`; an existing image does not
update automatically.
To run a local workflow from its directory:

```sh
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/work" nextflow run main.nf
```

The workflow, Nextflow cache, logs, and work directory are stored under the
mounted directory. This image runs local processes using tools available inside
the image; it does not include Docker, a container daemon, or molecular
applications. Workflows using container executors or external tools require
additional configuration and dependencies. Nextflow plugins and remotely
hosted workflows may require network access.

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

### Nextflow example

Build the Nextflow image as described above, then run:

```sh
./examples/nextflow/test.sh
```

Inspired by the [Seqera hello-world workflow](https://github.com/seqeralabs/nf-hello-world),
this example reads one greeting from a CSV file, writes it to a file, and runs
a second process to convert it to uppercase. The script prints the output
directory, which contains the copied workflow and CSV, `nextflow.out`, the
Nextflow work directory, and `output/greeting.txt` and `output/uppercase.txt`.
Set `EXAMPLE_OUTPUT_DIR` to change the parent directory. The example runs
offline and does not require additional software inside the container.

### Uni-GBSA example

Build the image as described above, then run:

```sh
./examples/unigbsa/test.sh
```

This calculates a GB binding-energy estimate for the 1IEP chain A receptor
and its STI ligand, the same source structure used in the Vina example.
Uni-GBSA requires a protein PDB and ligand SDF rather than Vina's PDBQT
files; the included files were extracted from the downloaded 1IEP structure
by the `molecular-docking` workflow. The ligand contains hydrogens added
without changing its existing protonation state. This uses the crystallographic
ligand coordinates, not a docked Vina pose.

The script prints the output directory, which retains the inputs,
`unigbsa.out`, `BindingEnergy.csv`, and intermediate files. Set
`EXAMPLE_OUTPUT_DIR` to change its parent. The default Uni-GBSA settings
perform energy minimization and a single-frame GB calculation; this is a
demonstration, not a scientifically validated binding-energy estimate.
Review protonation, preparation, force fields and sampling for real studies.

### GROMACS example

Build the image as described above, then run:

```sh
./examples/gromacs/test.sh
```

This uses `gmx solvate` and the packaged `spc216.gro` coordinates to create
a 2 × 2 × 2 nm water box. The printed output directory contains `water.gro`
and `gromacs.out`; set `EXAMPLE_OUTPUT_DIR` to change the parent directory.
This demonstrates system construction only, not a molecular dynamics
simulation or a validated production setup.

### AutoDock Vina example

Run a small docking demonstration using the local image:

```sh
./examples/autodock-vina/test.sh
```

The script docks the prepared 1IEP chain A receptor and its STI ligand using
the ligand-derived search box in `receptor.box.txt`. It prints the output
directory, which contains copies of the input PDBQT files and box configuration,
`vina.out`, and the docked poses in `docked.pdbqt`. It uses one CPU, a fixed
random seed, and low exhaustiveness to keep the run quick; the results are
for demonstration, not scientific validation. The receptor contains only
protein residues, and the ligand's existing protonation state is retained.
Review preparation and search parameters for scientific use.

For actual docking, prepare a receptor and ligand as PDBQT files using
appropriate preparation software, set a search box around the binding site,
and choose suitable search parameters. For example, from a directory
containing prepared `receptor.pdbqt` and `ligand.pdbqt`:

```sh
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/work" autodock-vina \
  --receptor receptor.pdbqt --ligand ligand.pdbqt \
  --center_x 0 --center_y 0 --center_z 0 \
  --size_x 20 --size_y 20 --size_z 20 --out docked.pdbqt
```

Replace the box coordinates and dimensions for the receptor. The command
writes `docked.pdbqt` in the mounted directory and may overwrite an existing
file. See the [Vina docking guide](https://autodock-vina.readthedocs.io/en/latest/docking_basic.html)
for preparation and docking details.

## Contributing

Open an issue or submit a pull request to propose changes. Document and
validate any container build or runtime behavior introduced later.

## Contact and support

- GitHub: [@eisenmann-bastian](https://github.com/eisenmann-bastian)
- LinkedIn: [Bastian Eisenmann](https://www.linkedin.com/in/bastianeisenmann/)
- [Buy me a coffee](https://buymeacoffee.com/bastian.eisenmann)

## License

[BSD 3-Clause License](LICENSE).