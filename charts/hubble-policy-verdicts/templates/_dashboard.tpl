{{/*
The dashboard JSON, assembled at render time (E7): the base dashboard, plus — when lokiRow.enabled — the
Loki-backed dropped-flow table whose Flow UUID column carries the cf2cnp actions, and its Loki variables.
The row file carries placeholders substituted from values before it is parsed. The three stream-label values
are checked first: a value that is not a string (a YAML null, a number) or that breaks the JSON string it is
spliced into would otherwise fail with a Go type error or a nil-pointer deep in fromJson.
*/}}
{{- define "hubble-policy-verdicts.dashboardJSON" -}}
{{- $d := .Files.Get "dashboards/hubble-policy-verdicts.json" | fromJson -}}
{{- if .Values.lokiRow.enabled -}}
{{- $ns := printf "%v" .Values.lokiRow.observerNamespace -}}
{{- $container := printf "%v" .Values.lokiRow.containerName -}}
{{- $label := printf "%v" .Values.lokiRow.clusterLabel -}}
{{- if not (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" $ns) -}}
{{- fail (printf "lokiRow.observerNamespace must be a Kubernetes namespace name (RFC 1123 label), got %q" $ns) -}}
{{- end -}}
{{- if not (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" $container) -}}
{{- fail (printf "lokiRow.containerName must be a Kubernetes container name (RFC 1123 label), got %q" $container) -}}
{{- end -}}
{{- if not (regexMatch "^[a-zA-Z_][a-zA-Z0-9_]*$" $label) -}}
{{- fail (printf "lokiRow.clusterLabel must be a non-empty Loki label name, got %q" $label) -}}
{{- end -}}
{{- $raw := .Files.Get "dashboards/loki-row.json" | replace "__CF2CNP_URL__" .Values.lokiRow.cf2cnpURL | replace "__OBSERVER_NAMESPACE__" $ns | replace "__OBSERVER_CONTAINER__" $container | replace "__LOKI_CLUSTER_LABEL__" $label -}}
{{- $row := $raw | fromJson -}}
{{- $_ := set $d "panels" (concat $d.panels $row.panels) -}}
{{- $_ := set $d.templating "list" (concat $d.templating.list $row.templating.list) -}}
{{- end -}}
{{- $d | toPrettyJson -}}
{{- end -}}
