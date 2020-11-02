#!/usr/bin/env bash

set -o errexit

DIR=${1}
IGNORE_VALUES=${2-false}
KUBE_VER=${3-master}
HELM_VER=${4-v2}
HRVAL="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/hrval.sh"
AWS_S3_REPO=${5-false}
AWS_S3_REPO_NAME=${6-""}
AWS_S3_PLUGIN="${7-""}"
HELM_SOURCES_CACHE_ENABLED=${8-""}

if [ "${HELM_SOURCES_CACHE_ENABLED}" == "true" ]; then
  CACHEDIR=$(mktemp -d)
else
  CACHEDIR="${CACHEDIR}"
fi

if [[ ${HELM_VER} == "v2" ]]; then
    helm init --client-only
fi

if [[ ${AWS_S3_REPO} == true ]]; then
    helm plugin install "${AWS_S3_PLUGIN}"
    helm repo add "${AWS_S3_REPO_NAME}" "s3:/${AWS_S3_REPO_NAME}/charts"
    helm repo update
fi

# If the path provided is actually a file, just run hrval against this one file
if test -f "${DIR}"; then
  ${HRVAL} "${DIR}" "${IGNORE_VALUES}" "${KUBE_VER}" "${HELM_VER}" "${CACHEDIR}"
  exit 0
fi

# If the path provided is not a directory, print error message and exit
if [ ! -d "$DIR" ]; then
  echo "\"${DIR}\" directory not found!"
  exit 1
fi

function isHelmRelease {
  KIND=$(yq r "${1}" kind)
  if [[ ${KIND} == "HelmRelease" ]]; then
      echo true
  else
    echo false
  fi
}

# Find yaml files in directory recursively
FILES_TESTED=0
declare -a FOUND_FILES=()
while read -r file; do
    FOUND_FILES+=( "$file" )
done < <(find "${DIR}" -type f -name '*.yaml' -o -name '*.yml')

for f in "${FOUND_FILES[@]}"; do
  if [[ $(isHelmRelease "${f}") == "true" ]]; then
    ${HRVAL} "${f}" "${IGNORE_VALUES}" "${KUBE_VER}" "${HELM_VER}" "${CACHEDIR}"
    FILES_TESTED=$(( FILES_TESTED+1 ))
  else
    echo "Ignoring ${f} not a HelmRelease"
  fi
done

# This will set the GitHub actions output 'numFilesTested'
echo "::set-output name=numFilesTested::${FILES_TESTED}"
