# hrval-action

![CI](https://github.com/stefanprodan/hrval-action/workflows/CI/badge.svg)

This GitHub action validates a Flux 
[Helm Release](https://docs.fluxcd.io/projects/helm-operator/en/latest/references/helmrelease-custom-resource.html)
Kubernetes custom resources with [kubeval](https://github.com/instrumenta/kubeval).

Steps:
* installs kubectl, yq, kubeval, helm v2 and v3
* extracts the chart source with yq
* downloads the chart from the Helm or Git repository
* extracts the Helm Release values with yq
* runs helm template for the extracted values
* validates the YAMLs using kubeval strict mode

## Usage

Validate Helm release custom resources:

```yaml
name: CI

on: [push, pull_request]

jobs:
  hrval:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v1
      - name: Validate Helm Releases in test dir
        uses: stefanprodan/hrval-action@v2.2.0
        with:
          helmRelease: test/
      - name: Validate Helm Release from Helm Repo
        uses: stefanprodan/hrval-action@v2.2.0
        with:
          helmRelease: test/flagger.yaml
          helmVersion: v2
          kubernetesVersion: 1.16.0
      - name: Validate Helm Release from Git Repo
        uses: stefanprodan/hrval-action@v2.2.0
        with:
          helmRelease: test/podinfo.yaml
          helmVersion: v3
          kubernetesVersion: master
          ignoreValues: true
```

Output:

```text
Processing test/flagger.yaml
Downloading to /tmp/tmp.TuA4QzCOG7
Extracting values to /tmp/tmp.TuA4QzCOG7/flagger.values.yaml
Writing Helm release to /tmp/tmp.TuA4QzCOG7/flagger.release.yaml
Validating Helm release flagger.flagger-system against Kubernetes 1.16.0
WARN - Set to ignore missing schemas
PASS - flagger/templates/psp.yaml contains a valid PodSecurityPolicy
PASS - flagger/templates/psp.yaml contains a valid ClusterRole
PASS - flagger/templates/psp.yaml contains a valid RoleBinding
PASS - flagger/templates/account.yaml contains a valid ServiceAccount
WARN - flagger/templates/crd.yaml containing a CustomResourceDefinition was not validated against a schema
PASS - flagger/templates/prometheus.yaml contains a valid ClusterRole
PASS - flagger/templates/prometheus.yaml contains a valid ClusterRoleBinding
PASS - flagger/templates/prometheus.yaml contains a valid ServiceAccount
PASS - flagger/templates/prometheus.yaml contains a valid ConfigMap
PASS - flagger/templates/prometheus.yaml contains a valid Deployment
PASS - flagger/templates/prometheus.yaml contains a valid Service
PASS - flagger/templates/rbac.yaml contains a valid ClusterRole
PASS - flagger/templates/rbac.yaml contains a valid ClusterRoleBinding
PASS - flagger/templates/deployment.yaml contains a valid Deployment
```

## CI alternatives

The validation scripts can be used in any CI system. 

CircleCI example:

```yaml
version: 2.1
jobs:
  hrval:
    docker:
      - image: circleci/golang:1.13
    steps:
      - checkout
      - run:
          name: Install hrval
          command: |
            curl -sL https://raw.githubusercontent.com/stefanprodan/hrval-action/master/src/deps.sh | sudo bash
            sudo curl -sL https://raw.githubusercontent.com/stefanprodan/hrval-action/master/src/hrval.sh \
              -o /usr/local/bin/hrval.sh && sudo chmod +x /usr/local/bin/hrval.sh
            sudo curl -sL https://raw.githubusercontent.com/stefanprodan/hrval-action/master/src/hrval-all.sh \
              -o /usr/local/bin/hrval && sudo chmod +x /usr/local/bin/hrval
      - run:
          name: Validate Helm Releases in test dir
          command: |
            IGNORE_VALUES=false
            KUBE_VER=master
            HELM_VER=v2

            hrval test/ $IGNORE_VALUES $KUBE_VER $HELM_VER
```
