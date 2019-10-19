# hrval-action

![CI](https://github.com/stefanprodan/hrval-action/workflows/CI/badge.svg)

This GitHub action validates a Flux 
[Helm Release](https://docs.fluxcd.io/projects/helm-operator/en/latest/references/helmrelease-custom-resource.html)
Kubernetes custom resource with [kubeval](https://github.com/instrumenta/kubeval).

Steps:
* installs kubectl, helm, yq and kubeval
* extracts the chart source with yq
* downloads the chart from the Helm or Git repository
* extracts the Helm Release values with yq
* runs helm template for the extracted values
* validates the YAMLs using kubeval strict mode

## Usage

Validate Helm release custom resources:

```yaml
name: CI

on: [push]

jobs:
  hrval:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v1
      - name: Validate Helm Release from Helm Repo
        uses: stefanprodan/hrval-action@v1.0.0
        with:
          helmRelease: test/flagger.yaml
          kubernetesVersion: 1.16.0
      - name: Validate Helm Release from Git Repo
        uses: stefanprodan/hrval-action@v1.0.0
        with:
          helmRelease: test/podinfo.yaml
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
