# replicated-library

![Version: 0.13.10](https://img.shields.io/badge/Version-0.13.10-informational?style=flat-square) ![Type: library](https://img.shields.io/badge/Type-library-informational?style=flat-square)

Replicated library chart

This is a library chart maintained by Replicated in order to keep the creation of helm charts dry when deploying third party commercial software

## Requirements

Kubernetes: `>=1.16.0-0`

## Releasing

Ensure the version number is set in `Chart.yaml` for the version you want to release.

Add your changes to the file `README_CHANGELOG.md.gotmpl`. The format for using this file is documented in the file itself.

You need to have [Helm Docs](https://github.com/norwoodj/helm-docs) installed. Then run the following command to update the README and README_CHANGELOG files.

```
helm-docs -t README.md.gotmpl -t README_CHANGELOG.md.gotmpl -t README_CONFIG.md.gotmpl
```

Check in the updated files as part of your PR.

## Installing the Chart

This is a [Helm Library Chart](https://helm.sh/docs/topics/library_charts/#helm).

**WARNING: THIS CHART IS NOT MEANT TO BE INSTALLED DIRECTLY**

## Using this library

Include the chart as a dependency in your `Chart.yaml`

```yaml
# Chart.yaml
dependencies:
- name: replicated-library
  repository: https://replicatedhq.github.io/helm-charts
  version: 0.13.10
```

You can see a full example of this library chart in use [here](https://github.com/replicatedhq/replicated-starter-helm)
To see an example of the available values see [values-example.yaml](values-example.yaml)

## Features

Below highlights some of the useful features available in this library

* [Dynamic App Reload on Configuration Changes](FEATURES.md#dynamic-app-reload-on-configuration-changes)
* [App, Service, and Ingress Association](FEATURES.md#app-service-and-ingress-association)

## Advanced Templating

[Examples of how you can advanced templating and build on top of this library chart](ADVANCED_TEMPLATING.md)

## Changelog

All notable changes to this library Helm chart will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

### [Unreleased]

### [0.13.10]

#### Fixed

- 121 - Fixed issue causing Readiness and Liveness probes from being rendering correctly for apps with multiple containers

### [0.13.9]

#### Fixed

- 110 - Fix examples for existingClaim and implement it in containers
- 109 - Trim "-" from serviceName
- 91 - cleaned up white spaces in Statefulset spec
- fixes serviceName not being set on Statefulsets

#### Added

Adds prefixes to configmaps in volumes like persistentVolumes
Use existingClaim in pods when set on persistence

### [0.13.8]

#### Fixed

- Fixed the README
- Clean up some whitespace formatting on deployments
- Updated the labels used for Troubleshoot secrets to match the new naming convention from v0.66.0

### [0.13.7]

#### Added

- Remove unused app.serviceAccount
- Setup app.serviceAccountName to configure which serviceAccount an app uses

### [0.13.5]

#### Added

- Adding support for native Kubernetes syntax for container environment variables. Supported formats are now:
    -  string in values.yaml example:
       foo: bar
    -  map in values.yaml with value example:
        - name: foo
          value: bar
    -  map in values.yaml with valueFrom example:
        - name: MYSQL_ROOT_PASSWORD  # Renders & installs statefulset with said environment variable.
          valueFrom:
            secretKeyRef:
              name: mysql-auth
              key: MYSQL_ROOT_PASSWORD

### [0.13.4]

#### Added

- Make RBAC for preflights optional

### [0.13.3]

#### Fixed

- Fixed issue where whitespace was being chomped and causing formatting issue with imagePullSecrets

### [0.13.2]

#### Added

- Add support for preflights specs

### [0.13.1]

#### Changed

- Rename `troubleshoot.support-bundle` to `troubleshoot.support-bundles`

### [0.13.0]

#### Added

- Add support for support bundle specs
- Added capability to override service name for ingress hosts (shortcut story - 71019)

### [0.12.2]

- Tidied up extra whitespace for pod and conatiner templates

### [0.12.1]

#### Fixed

- Fixed an issue when specifying multiple containers in a single app caused the chart to fail to render

### [0.12.0]

#### Added

- Added support for RBAC objects

### [0.11.1]

#### Fixed

- Fixed an issue in YAML formatting that was causing `imagePullSecrets` not to render properly in Pod spec
- Fixed an issue with the logic to automatically set Readiness and Liveness probes if ports.containerPort is defined

### [0.11.0]

#### Changed

- Apps using ConfigMaps and Secrets as volumes or env vars will now have their pods automatically re-deployed whenever the data in the configmap or secret changes
- **NOTE**: This only applies to `volumes` and `envFrom`. This feature has not yet been implementd for `env`

### [0.10.0]

#### Changed

- The `replicated-library.names.fullname` template will now trim a leading or trailing hyphen to prevent invalid names when the prefix is empty

#### Fixed

- Init containers now work as expected and follow the same format as containers

### [0.9.0]

#### Changed

- Adding Global "Context" dictionaries for values and names with unique subkeys per object type to prevent collisions
- Removing class directory and collapsing all templates into a single directory
- Altered helm-docs to generate documentation from values-example.yaml file.

### [0.8.0]

#### Changed

- Fixed volumeClaimTemplate loop in lib/_statefulset.tpl so metadata.name is rendered correctly.
- Added daemonset templates

### [0.7.1]
#### Changed

- Fix fullNameOverride to work with a null input rather than just an empty string.
- Remove configmap name override, fixes label errors when configmaps are included.

### [0.7.0]
#### Changed

- BREAKING: The `appName` key for services is now an optional list instead of a string. Charts using the previous implementation will need to convert the string into a single entry list which will work as before.
- Services `selector` now overrides selectors set by `appName`.
- If no `appName` or `selector` is defined, we try and match on the service name itself

### [0.6.1]
#### Changed

- Fixed automatic prefix on volumes

### [0.6.0]
#### Added

- Added Statefulsets template
- Added a prefix function

### [0.5.3]
#### Added

- Automatically add prefix to Statefulset volumes if it's a volume defined and enabled in the chart

### [0.5.2]
#### Added

- added capability to set type of secret.

### [0.5.1]
#### Changed

- fix spelling error in pod annotations
- fix label selector using chart name instead of app name

### [0.5.0]
#### Changed

- Add a unique prefix with global overrides to prevent multiple installs from conflicting.
- Update readme for Advanced Templating clarification

### [0.4.0]
#### Changed

- Livesness and Readiness probes are automatically generated if a container has ports defined
- All probe definitions moved to conatiner rather than "probes" sub-key.

### [0.3.0]
#### Changed

- Setting best practice defaults for imagePullPolicy, updateStrategy, and probes.
- Updated README to use .Chart.Version instead of hardcoding the chart version

#### Fixed
- Container image tags which were not strings failing to be templated correctly

[0.2.0]: #15
[0.1.1]: #9

## Support

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.11.0](https://github.com/norwoodj/helm-docs/releases/v1.11.0)
