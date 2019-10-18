# hrval-action

![CI](https://github.com/stefanprodan/hrval-action/workflows/CI/badge.svg)

This GitHub actions validates a Flux 
[Helm Release](https://docs.fluxcd.io/projects/helm-operator/en/latest/references/helmrelease-custom-resource.html)
Kubernetes custom resource with [kubeval](https://github.com/instrumenta/kubeval):
* downloads the chart from the Helm or Git repository
* extracts the Helm Release values
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
        uses: stefanprodan/hrval-action@master
        with:
          release: test/flagger.yaml
      - name: Validate Helm Release from Git Repo
        uses: stefanprodan/hrval-action@master
        with:
          release: test/podinfo.yaml
          ignore-values: true
```
