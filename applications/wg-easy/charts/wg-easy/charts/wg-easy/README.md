# wg-easy

## Helm chart

This is a helm chart for deploying [wg-easy](https://github.com/wg-easy/wg-easy) which describes itself as "You have found the easiest way to install & manage WireGuard on any Linux host!". This chart is not affiliated with the upstream project and bugs for this chart should not be filed against the upstream project.

## Installing the Chart

This chart exposes all of the wg-easy environment variables for configuration under the key `wireguard`. You can see the value available in the values.yaml file with this chart. Detailed instructions have not been written although the upstream project documents each of the environment variables.

## Releasing the chart

To release a new version of this chart simply set the version number in `Chart.yaml` as part of a pull request and once merged the new version will be released. Note that since this chart uses a `chart.lock` file the version in the lock file should match the version of the dependency listed in `Chart.yaml`, which should also be the version you tested your development changes against. Anytime you adjust the dependency version in `Chart.yaml` you should use `helm dependencies update` to fetch the new version and update the lock file to match. If your lock file and dependency version in the `Chart.yaml` file do not match you should update your dependencies and re-test to ensure your changes work with the version in the lock file.

## Contributing

This chart is functional and in use but lacks practices like more user friendly install instructions, explanation of how to configure values like `loadBalancerIP` on the vpn service, and a changelog to document changes in the versions. Contributions to add any of these items, to operate in a similar fashion to what's available in the library-chart that is used as a dependency would be greatly appreciated.
