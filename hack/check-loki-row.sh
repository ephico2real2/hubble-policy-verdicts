#!/usr/bin/env bash
# Additional 0.5.0 render contracts; run from the repository root.
set -euo pipefail
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
chart=charts/hubble-policy-verdicts
helm template t "$chart" --set lokiRow.enabled=true \
  --set lokiRow.cf2cnpURL=https://cf2cnp.test \
  --set lokiRow.observerNamespace=observability \
  --set lokiRow.containerName=flow-exporter \
  --set lokiRow.clusterLabel=collector_cluster \
  | awk '/hubble-policy-verdicts.json: \|-/{f=1;next} f' | sed 's/^    //' > "$work/custom.json"
python3 hack/check-dashboard.py "$work/custom.json" with-row observability flow-exporter collector_cluster
# Fail early, and by name, for a stream-label value that is not a label name, a Kubernetes name, or a string.
expect_fail() { # <values key> <--set or --set-string> <value> <expected message>
  if helm template t "$chart" --set lokiRow.enabled=true "$2" "$1=$3" > "$work/invalid.yaml" 2> "$work/error"; then
    echo "Expected invalid $1 to fail: [$3]" >&2
    exit 1
  fi
  grep -q "$4" "$work/error" || { echo "Expected '$4' for $1=[$3], got:" >&2; cat "$work/error" >&2; exit 1; }
}
for label in 'k8s.cluster.name' '9cluster' ''; do
  expect_fail lokiRow.clusterLabel --set-string "$label" 'lokiRow.clusterLabel must be a non-empty Loki label name'
done
expect_fail lokiRow.clusterLabel --set null 'lokiRow.clusterLabel must be a non-empty Loki label name'
expect_fail lokiRow.containerName --set-string 'Hubble Observer' 'lokiRow.containerName must be a Kubernetes container name'
expect_fail lokiRow.containerName --set null 'lokiRow.containerName must be a Kubernetes container name'
expect_fail lokiRow.observerNamespace --set-string 'a"b' 'lokiRow.observerNamespace must be a Kubernetes namespace name'
