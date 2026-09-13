{{/*
The dashboard JSON, assembled at render time (E7): the base dashboard, plus — when lokiRow.enabled — the
Loki-backed dropped-flow table whose Flow UUID column carries the cf2cnp actions, and its DS_LOKI variable.
The row file carries two placeholders substituted from values before it is parsed.
*/}}
{{- define "hubble-policy-verdicts.dashboardJSON" -}}
{{- $d := .Files.Get "dashboards/hubble-policy-verdicts.json" | fromJson -}}
{{- if .Values.lokiRow.enabled -}}
{{- $raw := .Files.Get "dashboards/loki-row.json" | replace "__CF2CNP_URL__" .Values.lokiRow.cf2cnpURL | replace "__OBSERVER_NAMESPACE__" .Values.lokiRow.observerNamespace -}}
{{- $row := $raw | fromJson -}}
{{- $_ := set $d "panels" (concat $d.panels $row.panels) -}}
{{- $_ := set $d.templating "list" (concat $d.templating.list $row.templating.list) -}}
{{- end -}}
{{- $d | toPrettyJson -}}
{{- end -}}
