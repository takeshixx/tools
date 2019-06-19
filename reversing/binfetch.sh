#!/bin/sh
# Pack a binary and all it's required shared objects
# into a tarball. Useful to get all files required
# to execute a binary.
set -xo
if [ "$#" -eq 0 ];then
    echo "Usage: ${0} [outdir] [file] [file...]"
    exit 1
fi
outdir=$1
shift
if [ ! -d "$outdir" ];then
    echo "Output directory ${outdir} not found"
    exit 1
fi
tmpdir=$(mktemp -dt binfetch.XXXXXX)
trap "rm -rf $tmpdir" EXIT TERM
for target in "$@";do
    target_path="$(readlink -f "${target}")"
    if [ ! -f "$target_path" ];then
        echo "Invalid target ${target}"
        continue
    fi
    target=$(basename "$target")
    mkdir "${tmpdir}/${target}"
    cp "$target_path" "${tmpdir}/${target}"
    for dep in $(ldd "${target_path}" | grep "=> /" | awk '{print $3}');do
        if [ ! -f "$dep" ];then
            echo "Dependency ${dep} not found"
            continue
        fi
        cp "$dep" "${tmpdir}/${target}"
    done
    tar czvf "${tmpdir}/${target}.tgz" -C "${tmpdir}/${target}" .
    cp "${tmpdir}/${target}.tgz" "$outdir"
done