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

function configurePrivateChartRepositories() {

  local tempDir
  tempDir="$(mktemp -d)"
  echo "$HTTP_PRIVATE_CHART_REPOS" > "$tempDir/repositories.json"
  local numberOfRepositories
  numberOfRepositories=$(yq r "$tempDir/repositories.json" --length repositories)

  for (( i = 0; i < numberOfRepositories; i++ )); do
      local url
      url=$(yq r "$tempDir/repositories.json" repositories[$i].url)
      local username
      username=$(yq r "$tempDir/repositories.json" repositories[$i].username)
      local password
      password=$(yq r "$tempDir/repositories.json" repositories[$i].password)
      local repoMD5
      repoMD5=$(/bin/echo "$url" | /usr/bin/md5sum | cut -f1 -d" ")

      >&2 echo "Adding Helm chart repository '$url'"
      if [[ ${HELM_VER} == "v3" ]]; then
        helmv3 repo add "$repoMD5" "${url}" --username "${username}" --password "${password}"
        helmv3 repo update
      else
        helm repo add "$repoMD5" "${url}" --username "${username}" --password "${password}"
        helm repo update
      fi
  done
}

if [[ -v HTTP_PRIVATE_CHART_REPOS ]]; then
  echo "Configuring Helm chart repositories"
  configurePrivateChartRepositories
fi

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
