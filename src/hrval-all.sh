#!/usr/bin/env bash

set -o errexit

DIRS=${1}
IGNORE_VALUES=${2-false}
KUBE_VER=${3-master}
HELM_VER=${4-v2}
HRVAL="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/hrval.sh"
AWS_S3_REPO=${5-false}
AWS_S3_REPO_NAME=${6-""}
AWS_S3_PLUGIN="${7-""}"
GCS_REPO=${8-false}
GCS_REPO_NAME=${9-""}
GCS_BUCKET=${10-""}
GCS_PLUGIN=${11-""}
HELM_SOURCES_CACHE_ENABLED=${12-""}

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

if [[ ${GCS_REPO} == true ]]; then
    helmv3 plugin install "${GCS_PLUGIN}"
    # helm repo add "${GCS_REPO_NAME}" "gs://${GCS_BUCKET}/charts"
    # helm repo update
fi

function validate {
  DIR=${1}
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
  TMPDIR=$(mktemp -d)
  kustomize build ${DIR} -o ${TMPDIR}

  FILES_TESTED=0
  declare -a FOUND_FILES=()
  while read -r file; do
      FOUND_FILES+=( "$file" )
  done < <(find "${TMPDIR}" -type f -name '*.yaml' -o -name '*.yml')

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
}

IFS=',' read -r -a array <<< "$DIRS"
for dir in "${array[@]}"; do
    echo "Validating $dir"
    validate "${dir}"
done