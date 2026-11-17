# Project instructions

- `docker-files/pymol/Dockerfile`, `docker-files/orca/Dockerfile`,
  `docker-files/openbabel/Dockerfile`, `docker-files/xtb/Dockerfile`,
  `docker-files/crest/Dockerfile`, `docker-files/censo/Dockerfile`,
  `docker-files/autodock-vina/Dockerfile`, `docker-files/gromacs/Dockerfile`,
  `docker-files/unigbsa/Dockerfile`, and `docker-files/nextflow/Dockerfile`
  build separate Ubuntu-based images.
  Other tools in the software inventory are candidates.
- `build.sh` builds each direct image directory using its name as the tag.
- For image changes, build and run the headless smoke test in [readme.md](readme.md);
  report explicitly if Docker or a daemon is unavailable.
- Keep [software-list.txt](software-list.txt) and [readme.md](readme.md)
  consistent when adding or removing entries.
- Preserve existing user files; document verification for any new container
  build or runtime behavior.
