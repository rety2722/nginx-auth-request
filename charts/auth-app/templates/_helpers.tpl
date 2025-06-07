{{/*
Expand the name of the chart.
*/}}
{{- define "auth.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "auth.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "auth.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "auth.labels" -}}
helm.sh/chart: {{ include "auth.chart" . }}
{{ include "auth.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "auth.selectorLabels" -}}
app.kubernetes.io/name: {{ include "auth.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service reference for templates
*/}}
{{- define "auth.service" -}}
- name: {{ .Values.ingressRoute.service.name }}
  port: {{ .Values.ingressRoute.service.port }}
{{- end }}

{{/*
Internal IP ranges for ClientIP matching
*/}}
{{- define "auth.internalIPs" -}}
ClientIP(`10.0.0.0/8`)
{{- end }}

{{/*
Entry points template
*/}}
{{- define "auth.entryPoints" -}}
{{- range .Values.ingressRoute.entryPoints }}
- {{ . }}
{{- end }}
{{- end }}

{{/*
Error service configuration - points to error-pages chart
*/}}
{{- define "auth.errorService" -}}
name: {{ .Values.middlewares.errorPages.service.name }}
port: {{ .Values.middlewares.errorPages.service.port }}
{{- end }}

{{/*
Error query path
*/}}
{{- define "auth.errorQuery" -}}
{{ .Values.middlewares.errorPages.query }}
{{- end }}
