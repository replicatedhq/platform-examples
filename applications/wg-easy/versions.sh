#!/bin/env bash
# Set versions for helmChart resources from their associated Chart.yaml files

set -euo pipefail

while read directory; do

  echo $directory
  parent=$(basename $(dirname $directory))

  helmChartName="helmChart-$parent.yaml"
  export version=$(yq -r '.version' $parent/Chart.yaml )

  yq '.spec.chart.chartVersion = strenv(version) | .spec.chart.chartVersion style="single"' $directory/$helmChartName | tee release/$helmChartName
  
done < <(find . -maxdepth 2 -mindepth 2 -type d -name replicated)
