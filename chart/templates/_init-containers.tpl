{{- define "vcluster.initContainers" -}}
{{- if eq (include "vcluster.distro" .) "k3s" -}}
{{ include "vcluster.k3s.initContainers" . }}
{{- else if eq (include "vcluster.distro" .) "k8s" -}}
{{ include "vcluster.k8s.initContainers" . }}
{{- else if eq (include "vcluster.distro" .) "k0s" -}}
{{ include "vcluster.k0s.initContainers" . }}
{{- end -}}
{{- end -}}

{{- define "vcluster.k8s.capabilities.version" -}}
{{/* We need to workaround here for unit tests because Capabilities.KubeVersion.Version is not supported, so we use .Chart.Version */}}
{{- if hasPrefix "test-" .Chart.Version -}}
{{- regexFind "^v[0-9]+\\.[0-9]+\\.[0-9]+" (trimPrefix "test-" .Chart.Version) -}}
{{- else -}}
{{- regexFind "^v[0-9]+\\.[0-9]+\\.[0-9]+" .Capabilities.KubeVersion.Version -}}
{{- end -}}
{{- end -}}

{{/* Bump $defaultTag value whenever k8s version is bumped */}}
{{- define "vcluster.k8s.image.tag" -}}
{{- $defaultTag := "v1.32.1" -}}
{{- if and (not (empty .Values.controlPlane.distro.k8s.version)) (eq .Values.controlPlane.distro.k8s.image.tag $defaultTag) -}}
{{ .Values.controlPlane.distro.k8s.version }}
{{- else -}}
{{- if not (eq .Values.controlPlane.distro.k8s.image.tag $defaultTag) -}}
{{ .Values.controlPlane.distro.k8s.image.tag }}
{{- else if not (empty (include "vcluster.k8s.capabilities.version" .)) -}}
{{ include "vcluster.k8s.capabilities.version" . }}
{{- else -}}
{{ .Values.controlPlane.distro.k8s.image.tag }}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "vcluster.k8s.initContainers" -}}
{{- include "vcluster.oldPlugins.initContainers" . }}
{{- include "vcluster.plugins.initContainers" . }}
- name: kubernetes
  image: "{{ include "vcluster.image" (dict "defaultImageRegistry" .Values.controlPlane.advanced.defaultImageRegistry "registry" .Values.controlPlane.distro.k8s.image.registry "repository" .Values.controlPlane.distro.k8s.image.repository "tag" (include "vcluster.k8s.image.tag" .)) }}"
  volumeMounts:
    - mountPath: /binaries
      name: binaries
  command:
    - cp
  args:
    - -a
    - /kubernetes/.
    - /binaries/
  {{- if .Values.controlPlane.distro.k8s.imagePullPolicy }}
  imagePullPolicy: {{ .Values.controlPlane.distro.k8s.imagePullPolicy }}
  {{- end }}
  securityContext:
{{ toYaml .Values.controlPlane.distro.k8s.securityContext | indent 4 }}
  resources:
{{ toYaml .Values.controlPlane.distro.k8s.resources | indent 4 }}
{{- end -}}

{{- define "vcluster.k3s.initContainers" -}}
{{- include "vcluster.oldPlugins.initContainers" . }}
{{- include "vcluster.plugins.initContainers" . }}
- name: vcluster
  image: "{{ include "vcluster.image" (dict "defaultImageRegistry" .Values.controlPlane.advanced.defaultImageRegistry "registry" .Values.controlPlane.distro.k3s.image.registry "repository" .Values.controlPlane.distro.k3s.image.repository "tag" .Values.controlPlane.distro.k3s.image.tag) }}"
  command:
    - /bin/sh
  args:
    - -c
    - "cp /bin/k3s /binaries/k3s"
  {{- if .Values.controlPlane.distro.k3s.imagePullPolicy }}
  imagePullPolicy: {{ .Values.controlPlane.distro.k3s.imagePullPolicy }}
  {{- end }}
  securityContext:
{{ toYaml .Values.controlPlane.distro.k3s.securityContext | indent 4 }}
  volumeMounts:
    - name: binaries
      mountPath: /binaries
  resources:
{{ toYaml .Values.controlPlane.distro.k3s.resources | indent 4 }}
{{- end -}}

{{- define "vcluster.k0s.initContainers" -}}
{{- include "vcluster.oldPlugins.initContainers" . }}
{{- include "vcluster.plugins.initContainers" . }}
- name: vcluster
  image: "{{ include "vcluster.image" (dict "defaultImageRegistry" .Values.controlPlane.advanced.defaultImageRegistry "registry" .Values.controlPlane.distro.k0s.image.registry "repository" .Values.controlPlane.distro.k0s.image.repository "tag" .Values.controlPlane.distro.k0s.image.tag) }}"
  command:
    - /bin/sh
  args:
    - -c
    - "cp /usr/local/bin/k0s /binaries/k0s"
  {{- if .Values.controlPlane.distro.k0s.imagePullPolicy }}
  imagePullPolicy: {{ .Values.controlPlane.distro.k0s.imagePullPolicy }}
  {{- end }}
  securityContext:
{{ toYaml .Values.controlPlane.distro.k0s.securityContext | indent 4 }}
  volumeMounts:
    - name: binaries
      mountPath: /binaries
  resources:
{{ toYaml .Values.controlPlane.distro.k0s.resources | indent 4 }}
{{- end -}}

{{/*
  Plugin init container definition
*/}}
{{- define "vcluster.plugins.initContainers" -}}
{{- range $key, $container := .Values.plugins }}
{{- if not $container.image }}
{{- continue }}
{{- end }}
- {{- if $.Values.controlPlane.advanced.defaultImageRegistry }}
  image: {{ $.Values.controlPlane.advanced.defaultImageRegistry }}/{{ $container.image }}
  {{- else }}
  image: {{ $container.image }}
  {{- end }}
  {{- if $container.name }}
  name: {{ $container.name | quote }}
  {{- else }}
  name: {{ $key | quote }}
  {{- end }}
  {{- if $container.imagePullPolicy }}
  imagePullPolicy: {{ $container.imagePullPolicy }}
  {{- end }}
  {{- if or $container.command $container.args }}
  {{- if $container.command }}
  command:
    {{- range $commandIndex, $command := $container.command }}
    - {{ $command | quote }}
    {{- end }}
  {{- end }}
  {{- if $container.args }}
  args:
    {{- range $argIndex, $arg := $container.args }}
    - {{ $arg | quote }}
    {{- end }}
  {{- end }}
  {{- else }}
  command: ["sh"]
  args: ["-c", "cp -r /plugin /plugins/{{ $key }}"]
  {{- end }}
  {{- if $container.securityContext }}
  securityContext:
{{ toYaml $container.securityContext | indent 4 }}
  {{- end }}
  {{- if $container.volumeMounts }}
  volumeMounts:
{{ toYaml $container.volumeMounts | indent 4 }}
  {{- else }}
  volumeMounts:
    - mountPath: /plugins
      name: plugins
  {{- end }}
  {{- if $container.resources }}
  resources:
{{ toYaml $container.resources | indent 4 }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
  Old Plugin init container definition
*/}}
{{- define "vcluster.oldPlugins.initContainers" -}}
{{- range $key, $container := .Values.plugin }}
{{- if or (ne $container.version "v2") (not $container.image) -}}
{{- continue -}}
{{- end -}}
- {{- if $.Values.controlPlane.advanced.defaultImageRegistry }}
  image: {{ $.Values.controlPlane.advanced.defaultImageRegistry }}/{{ $container.image }}
  {{- else }}
  image: {{ $container.image }}
  {{- end }}
  {{- if $container.name }}
  name: {{ $container.name | quote }}
  {{- else }}
  name: {{ $key | quote }}
  {{- end }}
  {{- if $container.imagePullPolicy }}
  imagePullPolicy: {{ $container.imagePullPolicy }}
  {{- end }}
  {{- if or $container.command $container.args }}
  {{- if $container.command }}
  command:
    {{- range $commandIndex, $command := $container.command }}
    - {{ $command | quote }}
    {{- end }}
  {{- end }}
  {{- if $container.args }}
  args:
    {{- range $argIndex, $arg := $container.args }}
    - {{ $arg | quote }}
    {{- end }}
  {{- end }}
  {{- else }}
  command: ["sh"]
  args: ["-c", "cp -r /plugin /plugins/{{ $key }}"]
  {{- end }}
  securityContext:
{{ toYaml $container.securityContext | indent 4 }}
  {{- if $container.volumeMounts }}
  volumeMounts:
{{ toYaml $container.volumeMounts | indent 4 }}
  {{- else }}
  volumeMounts:
    - mountPath: /plugins
      name: plugins
  {{- end }}
  {{- if $container.resources }}
  resources:
{{ toYaml $container.resources | indent 4 }}
  {{- end }}
{{- end }}
{{- end -}}
