# Molecular container

This repository contains an Ubuntu 26.04-based PyMOL image and a
[software list](software-list.txt) for further molecular-computing container
work. The other tools in that list are candidates; they are not installed in
the PyMOL image.

## Contents

- [Build](#build) · [Usage](#usage) · [Contributing](#contributing) ·
  [Contact and support](#contact-and-support) · [License](#license)

## Build

With Docker installed and its daemon running, build every image from the
repository root:

```sh
./build.sh
```

The script examines each direct subdirectory of `docker-files/`, uses it as
the build context, and tags the image with the directory name (for example,
`pymol:latest`). It stops on the first failure. Every image directory must
contain a `Dockerfile` and have a name valid as a Docker image tag; Docker
reports invalid names. Run it from any working directory.

To build just PyMOL manually:

```sh
docker build -t pymol ./docker-files/pymol
```

Run the build-script tests without Docker using
`python3 -m unittest discover -s tests -v`.

The image installs Python and open-source PyMOL from Ubuntu 26.04's
repositories. Ubuntu 26.04 provides Python 3.14 rather than the newest Python
release. It does not include `pymol-utilities`, ORCA, xTB, or OpenBabel.

## Usage

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

## Contributing

Open an issue or submit a pull request to propose changes. Document and
validate any container build or runtime behavior introduced later.

## Contact and support

- GitHub: [@eisenmann-bastian](https://github.com/eisenmann-bastian)
- LinkedIn: [Bastian Eisenmann](https://www.linkedin.com/in/bastianeisenmann/)
- [Buy me a coffee](https://buymeacoffee.com/bastian.eisenmann)

## License

[BSD 3-Clause License](LICENSE).