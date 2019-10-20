#!/usr/bin/env bash

set -o errexit

DIR=${1}
IGNORE_VALUES=${2-false}
KUBE_VER=${3-master}
HELM_VER=${4-v2}
HRVAL="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/hrval.sh"

if test -f "${DIR}"; then
  ${HRVAL} ${DIR} ${IGNORE_VALUES} ${KUBE_VER} ${HELM_VER}
  exit 0
fi

if [ ! -d "$DIR" ]; then
  echo "\"${DIR}\" directory not found!"
  exit 1
fi

function isHelmRelease {
  KIND=$(yq r ${1} kind)
  if [[ ${KIND} == "HelmRelease" ]]; then
      echo true
  else
    echo false
  fi
}

DIR_PATH=$(echo ${DIR} | sed "s/^\///;s/\/$//")
for f in ${DIR_PATH}/*.yaml; do
  if [[ $(isHelmRelease ${f}) == "true" ]]; then
    ${HRVAL} ${f} ${IGNORE_VALUES} ${KUBE_VER} ${HELM_VER}
  else
    echo "Ignoring ${f} not a HelmRelease"
  fi
done
