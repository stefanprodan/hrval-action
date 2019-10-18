#!/usr/bin/env bash

set -o errexit

HELM_RELEASE=${HELM_RELEASE}
IGNORE_VALUES=${IGNORE_VALUES}

if test ! -f "${HELM_RELEASE}"; then
  echo "\"${HELM_RELEASE}\" file not found!"
  exit 1
fi

echo "Processing ${HELM_RELEASE}"

function download {
  CHART_REPO=$(yq r ${1} spec.chart.repository)
  CHART_NAME=$(yq r ${1} spec.chart.name)
  CHART_VERSION=$(yq r ${1} spec.chart.version)
  CHART_TAR="${2}/${CHART_NAME}-${CHART_VERSION}.tgz"
  URL=$(echo ${CHART_REPO} | sed "s/^\///;s/\/$//")
  curl -s ${URL}/${CHART_NAME}-${CHART_VERSION}.tgz > ${CHART_TAR}
  echo ${CHART_TAR}
}

function clone {
  ORIGIN=$(git rev-parse --show-toplevel)
  GIT_REPO=$(yq r ${1} spec.chart.git)
  GIT_REF=$(yq r ${1} spec.chart.ref)
  CHART_PATH=$(yq r ${1} spec.chart.path)
  cd ${2}
  git init -q
  git remote add origin ${GIT_REPO}
  git fetch -q origin
  git checkout -q ${GIT_REF}
  cd ${ORIGIN}
  echo ${2}/${CHART_PATH}
}

function validate {
  TMPDIR=$(mktemp -d)
  CHART_PATH=$(yq r ${HELM_RELEASE} spec.chart.path)

  if [ "${CHART_PATH}" == "null" ]; then
    echo "Downloading to ${TMPDIR}"
    CHART_TAR=$(download ${HELM_RELEASE} ${TMPDIR}| tail -n1)
  else
    echo "Cloning to ${TMPDIR}"
    CHART_TAR=$(clone ${HELM_RELEASE} ${TMPDIR}| tail -n1)
  fi

  HELM_RELEASE_NAME=$(yq r ${HELM_RELEASE} metadata.name)
  HELM_RELEASE_NAMESPACE=$(yq r ${HELM_RELEASE} metadata.namespace)

  echo "Extracting values to ${TMPDIR}/${HELM_RELEASE_NAME}.values.yaml"
  if [ ${IGNORE_VALUES} ]; then
    echo "" > ${TMPDIR}/${HELM_RELEASE_NAME}.values.yaml
  else
    yq r ${HELM_RELEASE} spec.values > ${TMPDIR}/${HELM_RELEASE_NAME}.values.yaml
  fi

  echo "Writing Helm release to ${TMPDIR}/${HELM_RELEASE_NAME}.release.yaml"
  helm template ${CHART_TAR} \
  --name ${HELM_RELEASE_NAME} \
  --namespace ${HELM_RELEASE_NAMESPACE} \
  -f ${TMPDIR}/${HELM_RELEASE_NAME}.values.yaml > ${TMPDIR}/${HELM_RELEASE_NAME}.release.yaml

  echo "Validating Helm release ${HELM_RELEASE_NAME}.${HELM_RELEASE_NAMESPACE}"
  kubeval --strict --ignore-missing-schemas ${TMPDIR}/${HELM_RELEASE_NAME}.release.yaml
}

validate