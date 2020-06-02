#!/usr/bin/env bash

set -o errexit

HELM_RELEASE=${1}
IGNORE_VALUES=${2}
KUBE_VER=${3-master}
HELM_VER=${4-v2}

if test ! -f "${HELM_RELEASE}"; then
  echo "\"${HELM_RELEASE}\" Helm release file not found!"
  exit 1
fi

echo "Processing ${HELM_RELEASE}"

function isHelmRelease {
  KIND=$(yq r ${1} kind)
  if [[ ${KIND} == "HelmRelease" ]]; then
      echo true
  else
    echo false
  fi
}

function download {
  CHART_REPO=$(yq r ${1} spec.chart.repository)
  CHART_NAME=$(yq r ${1} spec.chart.name)
  CHART_VERSION=$(yq r ${1} spec.chart.version)
  CHART_DIR=${2}/${CHART_NAME}

  if [[ ${HELM_VER} == "v3" ]]; then
    helmv3 repo add ${CHART_NAME} ${CHART_REPO}
    helmv3 fetch --version ${CHART_VERSION} --untar ${CHART_NAME}/${CHART_NAME} --untardir ${2}
  else
    helm repo add ${CHART_NAME} ${CHART_REPO}
    helm fetch --version ${CHART_VERSION} --untar ${CHART_NAME}/${CHART_NAME} --untardir ${2}
  fi

  echo ${CHART_DIR}
}

function clone {
  ORIGIN=$(git rev-parse --show-toplevel)
  CHART_GIT_REPO=$(yq r ${1} spec.chart.git)
  RELEASE_GIT_REPO=$(git remote get-url origin)
  CHART_BASE_URL=$(echo "${CHART_GIT_REPO}" | sed -e 's/ssh:\/\///' -e 's/http:\/\///' -e 's/https:\/\///' -e 's/git@//' -e 's/:/\//')
  RELEASE_BASE_URL=$(echo "${RELEASE_GIT_REPO}" | sed -e 's/ssh:\/\///' -e 's/http:\/\///' -e 's/https:\/\///' -e 's/git@//' -e 's/:/\//')
  if [[ -n "${GITHUB_TOKEN}" ]]; then
    CHART_GIT_REPO="https://${GITHUB_TOKEN}:x-oauth-basic@${CHART_BASE_URL}"
  elif [[ -n "${GITLAB_CI_TOKEN}" ]]; then
    CHART_GIT_REPO="https://gitlab-ci-token:${GITLAB_CI_TOKEN}@${CHART_BASE_URL}"
  fi
  CHART_GIT_REF=$(yq r ${1} spec.chart.ref)
  RELEASE_GIT_REF=$(git rev-parse --abbrev-ref HEAD)
  CHART_PATH=$(yq r ${1} spec.chart.path)
  cd ${2}
  git init -q
  git remote add origin ${CHART_GIT_REPO}
  git fetch -q origin
  if [[ "${CHART_BASE_URL}" == "${RELEASE_BASE_URL}" ]]; then
    git checkout -q ${RELEASE_GIT_REF}
    echo "Checkout ${RELEASE_GIT_REF}"
  else
    git checkout -q ${CHART_GIT_REF}
    echo "Checkout ${CHART_GIT_REF}"
  fi
  cd ${ORIGIN}
  echo ${2}/${CHART_PATH}
}

function validate {
  if [[ $(isHelmRelease ${HELM_RELEASE}) == "false" ]]; then
    echo "\"${HELM_RELEASE}\" is not of kind HelmRelease!"
    exit 1
  fi

  TMPDIR=$(mktemp -d)
  CHART_PATH=$(yq r ${HELM_RELEASE} spec.chart.path)

  if [[ -z "${CHART_PATH}" ]]; then
    echo "Downloading to ${TMPDIR}"
    CHART_DIR=$(download ${HELM_RELEASE} ${TMPDIR}| tail -n1)
  else
    echo "Cloning to ${TMPDIR}"
    CHART_DIR=$(clone ${HELM_RELEASE} ${TMPDIR}| tail -n1)
  fi

  HELM_RELEASE_NAME=$(yq r ${HELM_RELEASE} metadata.name)
  HELM_RELEASE_NAMESPACE=$(yq r ${HELM_RELEASE} metadata.namespace)

  if [[ ${IGNORE_VALUES} == "true" ]]; then
    echo "Ingnoring Helm release values"
    echo "" > ${TMPDIR}/${HELM_RELEASE_NAME}.values.yaml
  else
    echo "Extracting values to ${TMPDIR}/${HELM_RELEASE_NAME}.values.yaml"
    yq r ${HELM_RELEASE} spec.values > ${TMPDIR}/${HELM_RELEASE_NAME}.values.yaml
  fi

  echo "Writing Helm release to ${TMPDIR}/${HELM_RELEASE_NAME}.release.yaml"
  if [[ ${HELM_VER} == "v3" ]]; then
    if [[ "${CHART_PATH}" ]]; then
      helmv3 dependency build ${CHART_DIR}
    fi
    helmv3 template ${HELM_RELEASE_NAME} ${CHART_DIR} \
      --namespace ${HELM_RELEASE_NAMESPACE} \
      --skip-crds=true \
      -f ${TMPDIR}/${HELM_RELEASE_NAME}.values.yaml > ${TMPDIR}/${HELM_RELEASE_NAME}.release.yaml
  else
    if [[ "${CHART_PATH}" ]]; then
      helm dependency build ${CHART_DIR}
    fi
    helm template ${CHART_DIR} \
      --name ${HELM_RELEASE_NAME} \
      --namespace ${HELM_RELEASE_NAMESPACE} \
      -f ${TMPDIR}/${HELM_RELEASE_NAME}.values.yaml > ${TMPDIR}/${HELM_RELEASE_NAME}.release.yaml
  fi

  echo "Validating Helm release ${HELM_RELEASE_NAME}.${HELM_RELEASE_NAMESPACE} against Kubernetes ${KUBE_VER}"
  kubeval --strict --ignore-missing-schemas --kubernetes-version ${KUBE_VER} ${TMPDIR}/${HELM_RELEASE_NAME}.release.yaml
}

validate
