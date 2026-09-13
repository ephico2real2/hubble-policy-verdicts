{{- define "hubble-policy-verdicts.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
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
