#!/usr/bin/env bash

set -o errexit

curl -sL "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl

curl -sL https://github.com/mikefarah/yq/releases/download/3.4.1/yq_linux_amd64 -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq

curl -sSL https://get.helm.sh/helm-v2.17.0-linux-amd64.tar.gz | tar xz && mv linux-amd64/helm /bin/helm && rm -rf linux-amd64
helm init --client-only --kubeconfig="${HOME}/.kube/kubeconfig"

curl -sSL https://get.helm.sh/helm-v3.4.0-linux-amd64.tar.gz | tar xz && mv linux-amd64/helm /bin/helmv3 && rm -rf linux-amd64
helmv3 version
