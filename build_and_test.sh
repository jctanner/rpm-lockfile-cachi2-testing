#!/bin/bash

set -e

#usage: rpm-lockfile-prototype [-h] [-f CONTAINERFILE | --image IMAGE | --local-system | --bare |
#                              --rpm-ostree-treefile RPM_OSTREE_TREEFILE] [--flatpak] [--debug] [--arch ARCH]
#                              [--pull {always,missing,never,newer}] [--outfile OUTFILE] [--print-schema] [--allowerasing]
#                              INPUT_FILE
#
#positional arguments:
#  INPUT_FILE
#
#options:
#  -h, --help            show this help message and exit
#  -f, --containerfile CONTAINERFILE
#               Load installed packages from base image specified in Containerfile and make them available during dependency
#               resolution.
#  --image IMAGE         Use rpmdb from the given image.
#  --local-system        Resolve dependencies for current system.
#  --bare                Resolve dependencies as if nothing is installed in the target system.
#  --rpm-ostree-treefile RPM_OSTREE_TREEFILE
#  --flatpak             Determine the set of packages from the flatpak: section of container.yaml.
#  --debug
#  --arch ARCH           Run the resolution for this architecture. Can be specified multiple times.
#  --pull {always,missing,never,newer}
#                        DEPRECATED
#  --outfile OUTFILE
#  --print-schema        Print schema for the input file to stdout.
#  --allowerasing        Allow erasing of installed packages to resolve dependencies.


WORKDIR=$(pwd)
LOCKFILE_TAG="jtanner/lockfile-prototype-test:latest"
LOCKFILE_RUNTIME_TAG="localhost/$LOCKFILE_TAG"
UBI_TAG="registry.access.redhat.com/ubi9/ubi:latest"
BUILDER_TAG="registry.access.redhat.com/ubi9/go-toolset:1.21@sha256:97e30a01caeece72ee967013e7c7af777ea4ee93840681ddcfe38a87eb4c084a"
CACHI2_TAG="localhost/jctanner/cachi2:latest"

# build the container with patches ...
cd rpm-lockfile-prototype
podman build -t $LOCKFILE_TAG -f Containerfile .
cd $WORKDIR

# use the container to generate the lockfile ...
podman run --rm -w /workdir -v $(pwd):/workdir \
    -it $LOCKFILE_RUNTIME_TAG --image=$UBI_TAG --outfile=/workdir/rpms-test-el9.lock.yaml --allowerasing rpms_el9.in.yaml

echo "----------------------------------"
echo "LOCK FILE PACKAGES"
echo "----------------------------------"
yq '.arches[].packages[].name' rpms-test-el9.lock.yaml

# make the cache with cachi2 ...
rm -rf cachi2.output
podman run --rm -it -v $(pwd):/workdir -w /workdir $CACHI2_TAG \
	--log-level=debug fetch-deps --source=/workdir --output=/workdir/cachi2.output --dev-package-managers rpm

echo "----------------------------------"
echo "CACHI2 FETCHED FILES"
echo "----------------------------------"
find cachi2.output


# create the repo files ...
podman run --rm -it -v $(pwd):/workdir -w /workdir $CACHI2_TAG \
	--log-level=debug inject-files --for-output-dir=/tmp/cachi2 /workdir/cachi2.output

echo "----------------------------------"
echo "CACHI2 INJECTED FILES"
echo "----------------------------------"
find cachi2.output

# test a dockerfile build ...
podman build \
    --no-cache \
    --security-opt seccomp=unconfined \
    --cap-add all \
    --target=builder \
    -v $(pwd)/cachi2.output:/tmp/cachi2 \
    -v $(pwd)/cachi2.output/deps/rpm/x86_64/repos.d:/etc/yum.repos.d \
    -f Dockerfile.el9.test .
