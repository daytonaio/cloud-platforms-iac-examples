resource "kubectl_manifest" "sysbox_sa" {
  yaml_body = <<YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sysbox-label-node
  namespace: kube-system
YAML
}

resource "kubectl_manifest" "sysbox_cluster_role" {
  yaml_body = <<YAML
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: sysbox-node-labeler
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "patch"]
YAML
}

resource "kubectl_manifest" "sysbox_clusterrolebinding" {
  yaml_body = <<YAML
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: sysbox-label-node-rb
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: sysbox-node-labeler
subjects:
- kind: ServiceAccount
  name: sysbox-label-node
  namespace: kube-system
YAML
}


resource "kubectl_manifest" "sysbox" {
  yaml_body = <<YAML
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: sysbox-deploy-k8s
  namespace: kube-system
spec:
  selector:
      matchLabels:
        sysbox-install: "yes"
  template:
    metadata:
        labels:
          sysbox-install: "yes"
    spec:
      serviceAccountName: sysbox-label-node
      nodeSelector:
        sysbox-install: "yes"
      tolerations:
      - key: "sysbox-runtime"
        operator: "Equal"
        value: "not-running"
        effect: "NoSchedule"
      - key: "daytona.io/node-role"
        operator: "Equal"
        value: "workload"
        effect: "NoSchedule"
      containers:
      - name: sysbox-deploy-k8s
        image: registry.nestybox.com/nestybox/sysbox-deploy-k8s:v0.6.4
        imagePullPolicy: Always
        command: [ "bash", "-c", "/opt/sysbox/scripts/sysbox-deploy-k8s.sh ce install" ]
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        securityContext:
          privileged: true
        volumeMounts:
        - name: host-etc
          mountPath: /mnt/host/etc
        - name: host-osrelease
          mountPath: /mnt/host/os-release
        - name: host-dbus
          mountPath: /var/run/dbus
        - name: host-run-systemd
          mountPath: /run/systemd
        - name: host-lib-systemd
          mountPath: /mnt/host/lib/systemd/system
        - name: host-etc-systemd
          mountPath: /mnt/host/etc/systemd/system
        - name: host-lib-sysctl
          mountPath: /mnt/host/lib/sysctl.d
        - name: host-opt-lib-sysctl
          mountPath: /mnt/host/opt/lib/sysctl.d
        - name: host-usr-bin
          mountPath: /mnt/host/usr/bin
        - name: host-opt-bin
          mountPath: /mnt/host/opt/bin
        - name: host-usr-local-bin
          mountPath: /mnt/host/usr/local/bin
        - name: host-opt-local-bin
          mountPath: /mnt/host/opt/local/bin
        - name: host-usr-lib-mod-load
          mountPath: /mnt/host/usr/lib/modules-load.d
        - name: host-opt-lib-mod-load
          mountPath: /mnt/host/opt/lib/modules-load.d
        - name: host-run
          mountPath: /mnt/host/run
        - name: host-var-lib
          mountPath: /mnt/host/var/lib
      volumes:
        - name: host-etc
          hostPath:
            path: /etc
        - name: host-osrelease
          hostPath:
            path: /etc/os-release
        - name: host-dbus
          hostPath:
            path: /var/run/dbus
        - name: host-run-systemd
          hostPath:
            path: /run/systemd
        - name: host-lib-systemd
          hostPath:
            path: /lib/systemd/system
        - name: host-etc-systemd
          hostPath:
            path: /etc/systemd/system
        - name: host-lib-sysctl
          hostPath:
            path: /lib/sysctl.d
        - name: host-opt-lib-sysctl
          hostPath:
            path: /opt/lib/sysctl.d
        - name: host-usr-bin
          hostPath:
            path: /usr/bin/
        - name: host-opt-bin
          hostPath:
            path: /opt/bin/
        - name: host-usr-local-bin
          hostPath:
            path: /usr/local/bin/
        - name: host-opt-local-bin
          hostPath:
            path: /opt/local/bin/
        - name: host-usr-lib-mod-load
          hostPath:
            path: /usr/lib/modules-load.d
        - name: host-opt-lib-mod-load
          hostPath:
            path: /opt/lib/modules-load.d
        - name: host-run
          hostPath:
            path: /run
        - name: host-var-lib
          hostPath:
            path: /var/lib
  updateStrategy:
    rollingUpdate:
      maxUnavailable: 1
    type: RollingUpdate
YAML
}

resource "kubectl_manifest" "sysbox_runtimeclass" {
  yaml_body = <<YAML
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: sysbox-runc
handler: sysbox-runc
YAML

  depends_on = [kubectl_manifest.sysbox]
}
