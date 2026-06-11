{{- define "api-service.name" -}}
api-service
{{- end -}}

{{- define "api-service.fullname" -}}
api-service
{{- end -}}

{{- define "api-service.labels" -}}
app.kubernetes.io/name: api-service
app.kubernetes.io/part-of: platform
app.kubernetes.io/managed-by: Helm
{{- end -}}
