{{/*
The object name. NOT .Chart.Name: when this chart is a dependency with an alias (hubble-observer uses
alias: policyVerdictsDashboard), .Chart.Name is the alias, and a camelCase alias is not a valid Kubernetes
name (measured: UPGRADE FAILED, metadata.name: Invalid value "policyVerdictsDashboard"). A fixed, lowercase
default; nameOverride when the user wants another.
*/}}
{{- define "hubble-policy-verdicts.name" -}}
{{- default "hubble-policy-verdicts" .Values.nameOverride | lower | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- define "hubble-policy-verdicts.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "hubble-policy-verdicts.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: dashboard
app.kubernetes.io/part-of: hubble
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.dashboard.labels }}
{{ toYaml . }}
{{- end }}
{{- end }}
