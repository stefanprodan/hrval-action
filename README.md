# hrval-action

![CI](https://github.com/stefanprodan/hrval-action/workflows/CI/badge.svg)
[![Docker](https://img.shields.io/badge/Docker%20Hub-stefanprodan%2Fhrval-blue)](https://hub.docker.com/r/stefanprodan/hrval)
[![GitHub Super-Linter](https://github.com/stefanprodan/hrval-action/workflows/Lint%20Code%20Base/badge.svg)](https://github.com/marketplace/actions/super-linter)

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
        uses: stefanprodan/hrval-action@master
        with:
          helmRelease: test/
      - name: Validate Helm Release from Helm Repo
        uses: stefanprodan/hrval-action@master
        with:
          helmRelease: test/flagger.yaml
          helmVersion: v2
          kubernetesVersion: 1.17.0
      - name: Validate Helm Release from Git Repo
        uses: stefanprodan/hrval-action@master
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

## Usage with private charts repositories

To allow the action to be able to clone private charts repositories, you must [create a GitHub private access token](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line) and [add it as a secret](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/creating-and-using-encrypted-secrets#creating-encrypted-secrets) to the target repository. NOTE: secret names *cannot* start with `GITHUB_` as these are reserved.

You can then pass the secret (in this case, `GH_TOKEN`) into the action like so:
```yaml
name: CI

on: [push, pull_request]

jobs:
  hrval:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v1
      - name: Validate Helm Releases in test dir
        uses: stefanprodan/hrval-action@master
        with:
          helmRelease: test/
        env:
          GITHUB_TOKEN: ${{ secrets.GH_TOKEN }}
```

If you set `awsS3Repo: true`,  make sure you set the appropriate environment variables for helm s3 plugin to work.  Example:
```yaml
name: CI

on: [push, pull_request]

jobs:
  hrval:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v1
      - name: Validate Helm Releases in test dir
        uses: stefanprodan/hrval-action@master
        with:
          helmRelease: test/
          awsS3Repo: true
          awsS3RepoName: example-s3-helm-repo
          awsS3Plugin: https://github.com/hypnoglow/helm-s3.git
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: "us-east-1"

```

Gitlab CI Token is also possible using `GITLAB_CI_TOKEN`.

## Usage with pull requests containing changes of Helm chart source located in base repository branch

If a base repository branch of pull request is referenced in helm release,
you need to pass `HRVAL_BASE_BRANCH` and `HRVAL_HEAD_BRANCH` environment variables
to an action to make sure it will check out amended version of the chart
from a head repository branch.


```yaml
name: CI

on: [pull_request]

jobs:
  hrval:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v1
      - name: Validate Helm Releases in test dir
        uses: stefanprodan/hrval-action@master
        with:
          helmRelease: test/
        env:
          HRVAL_BASE_BRANCH: ${{ github.base_ref }}
          HRVAL_HEAD_BRANCH: ${{ github.head_ref }}
```

## Usage with Helm source caching enabled

Sometimes single Helm release might be referenced multiple times in a single Flux repository,
for example if staging branch of Helm chart repository is used as a release ref across all staging releases.
A property named `helmSourcesCacheEnabled` enables caching for such releases,
so a single Helm repository chart version or Git repository ref
will be retrieved only once, and cached version will be used for validation of another releases which reuse same sources.


```yaml
name: CI

on: [pull_request]

jobs:
  hrval:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v1
      - name: Validate Helm Releases in test dir
        uses: stefanprodan/hrval-action@master
        with:
          helmRelease: test/
          helmSourcesCacheEnabled: true
```


## CI alternatives

The validation scripts can be used in any CI system.

CircleCI example:

```yaml
version: 2.1
jobs:
  hrval:
    docker:
      - image: stefanprodan/hrval:latest
    steps:
      - checkout
      - run:
          name: Validate Helm Releases in test dir
          command: |
            IGNORE_VALUES=false
            KUBE_VER=master
            HELM_VER=v2

            hrval test/ $IGNORE_VALUES $KUBE_VER $HELM_VER
```
