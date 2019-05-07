#!/bin/bash

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
  echo "** Exited"
  [ -f "${FILENAME}.qcow2" ] && rm "${FILENAME}.qcow2"
  [ -f "${FILENAME}.qcow2.bz2" ] && rm "${FILENAME}.qcow2.bz2"
  [ -f "${FILENAME}.qcow2.bz2" ] && rm "${FILENAME}.bz2"
  exit 1
}

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
if [[ "$2" == "" ]]; then
  ALPINE_VERSION="v3.9"
else
  ALPINE_VERSION="v$2"
fi

if [[ "$3" == "" ]] || [[ ! -d "$3" ]]; then
  OUTPUT_DIR="$DIR"
else
  OUTPUT_DIR="$3"
fi

FILENAME="alpine-${ALPINE_VERSION}-do-virt-$(date +%Y-%m-%d-%k%M)"
REPOSITORIES="${DIR}/repositories-${ALPINE_VERSION}.txt"
# [Optional] Additional Packages List in packages.txt
PACKAGES="openssh e2fsprogs-extra"
PACKAGES="$PACKAGES `[ -f "${DIR}/packages.txt" ] && { cat "${DIR}/packages.txt" | sed "/^#/d" | tr $"\n" " " | sed 's/  */ /g';}`"

if [ "$CI" = "true" ]; then
  echo "Running under CI"
  echo $FILENAME > version
else
  echo "Building DigitalOcean Droplet Image"
  echo "Alpine Version $ALPINE_VERSION"
  echo "Installing Additional Packages: $PACKAGES"
  echo "Generating Output File ${FILENAME}.qcow2"
fi

# Check if Alpine Version Repository File Exists - If not then make it
if [ ! -f "$REPOSITORIES" ]; then
  cat > "$REPOSITORIES" <<EOF
https://nl.alpinelinux.org/alpine/${ALPINE_VERSION}/main
https://nl.alpinelinux.org/alpine/${ALPINE_VERSION}/community
EOF
fi

./alpine-make-vm-image/alpine-make-vm-image \
  --packages "$PACKAGES" \
  --repositories "$REPOSITORIES" \
  --script-chroot \
  --image-format qcow2 "${OUTPUT_DIR}/${FILENAME}.qcow2" \
  -- ./setup.sh
if [ $? == 0 ]; then
  bzip2 -z "${OUTPUT_DIR}/${FILENAME}.qcow2"
else
  [ -f "${FILENAME}.qcow2" ] && rm "${FILENAME}.qcow2"
fi
