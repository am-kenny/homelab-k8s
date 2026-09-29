{{/*
Expand the name of the chart.
*/}}
{{- define "overleaf.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "overleaf.fullname" -}}
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
{{- define "overleaf.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "overleaf.labels" -}}
helm.sh/chart: {{ include "overleaf.chart" . }}
{{ include "overleaf.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "overleaf.selectorLabels" -}}
app.kubernetes.io/name: {{ include "overleaf.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: overleaf
{{- end }}

{{/*
MongoDB names and labels
*/}}
{{- define "overleaf.mongodb.fullname" -}}
{{- printf "%s-mongodb" (include "overleaf.fullname" . | trunc 55 | trimSuffix "-") }}
{{- end }}

{{- define "overleaf.mongodb.labels" -}}
helm.sh/chart: {{ include "overleaf.chart" . }}
{{ include "overleaf.mongodb.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.mongodb.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "overleaf.mongodb.selectorLabels" -}}
app.kubernetes.io/name: {{ include "overleaf.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: mongodb
{{- end }}

{{/*
Stable DNS name of the single replica set member.
*/}}
{{- define "overleaf.mongodb.host" -}}
{{- printf "%s-0.%s.%s.svc.cluster.local" (include "overleaf.mongodb.fullname" .) (include "overleaf.mongodb.fullname" .) .Release.Namespace }}
{{- end }}

{{- define "overleaf.mongodb.url" -}}
{{- if .Values.mongodb.enabled }}
{{- printf "mongodb://%s:27017/%s?replicaSet=%s" (include "overleaf.mongodb.host" .) .Values.mongodb.database .Values.mongodb.replicaSetName }}
{{- else }}
{{- required "externalMongodb.url is required when mongodb.enabled is false" .Values.externalMongodb.url }}
{{- end }}
{{- end }}

{{/*
Redis names and labels
*/}}
{{- define "overleaf.redis.fullname" -}}
{{- printf "%s-redis" (include "overleaf.fullname" . | trunc 57 | trimSuffix "-") }}
{{- end }}

{{- define "overleaf.redis.labels" -}}
helm.sh/chart: {{ include "overleaf.chart" . }}
{{ include "overleaf.redis.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.redis.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "overleaf.redis.selectorLabels" -}}
app.kubernetes.io/name: {{ include "overleaf.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: redis
{{- end }}

{{- define "overleaf.redis.host" -}}
{{- if .Values.redis.enabled }}
{{- printf "%s.%s.svc.cluster.local" (include "overleaf.redis.fullname" .) .Release.Namespace }}
{{- else }}
{{- required "externalRedis.host is required when redis.enabled is false" .Values.externalRedis.host }}
{{- end }}
{{- end }}

{{- define "overleaf.redis.port" -}}
{{- if .Values.redis.enabled }}
{{- print "6379" }}
{{- else }}
{{- print .Values.externalRedis.port }}
{{- end }}
{{- end }}

{{/*
Name of the Secret holding the sensitive variables.
*/}}
{{- define "overleaf.secretName" -}}
{{- .Values.existingSecret | default (printf "%s-secrets" (include "overleaf.fullname" .)) }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "overleaf.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "overleaf.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
