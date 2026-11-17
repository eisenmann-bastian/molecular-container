#!/bin/sh
set -eu

if [ "$#" -ne 0 ]; then
    echo "Usage: $0" >&2
    exit 2
fi

example=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$example/../common.sh"
create_example_workdir "$example" unigbsa
cp "$example/receptor.pdb" "$example/ligand.sdf" "$work/"

if ! docker run --rm --pull=never --user "$(id -u):$(id -g)" \
    -e OMP_NUM_THREADS=1 -v "$work:/work" unigbsa \
    -i receptor.pdb -l ligand.sdf -o BindingEnergy.csv -nt 1 --verbose \
    > "$work/unigbsa.out" 2>&1; then
    echo "Uni-GBSA container failed:" >&2
    cat "$work/unigbsa.out" >&2
    exit 1
fi
if [ ! -s "$work/BindingEnergy.csv" ] || ! awk -F, '
    NR == 1 {
        for (i = 1; i <= NF; i++) {
            sub(/\r$/, "", $i)
            column[$i] = i
        }
        next
    }
    NR == 2 && column["ligandName"] && column["status"] && column["mode"] && column["TOTAL"] {
        sub(/\r$/, "", $(column["status"]))
        if ($(column["ligandName"]) == "ligand" && $(column["status"]) == "S" &&
            $(column["mode"]) == "gb" &&
            $(column["TOTAL"]) ~ /^[-+]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][-+]?[0-9]+)?$/)
            valid = 1
        next
    }
    NR > 2 { valid = 0 }
    END { exit !valid }
' "$work/BindingEnergy.csv"; then
    echo "Uni-GBSA did not produce a successful GB result:" >&2
    cat "$work/unigbsa.out" >&2
    exit 1
fi
echo "Uni-GBSA completed."
