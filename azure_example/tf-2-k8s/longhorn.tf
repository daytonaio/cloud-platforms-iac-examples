# daemonset that runs on longhorn node pool in order to create Raid0 of all SSD disks
# and create mountpoint (path) which will be used by Longhorn for disk storage
resource "kubectl_manifest" "aks_raid_disks" {
  yaml_body = <<YAML
apiVersion: apps/v1
kind: DaemonSet
metadata:
  namespace: ${kubernetes_namespace.longhorn-system.metadata[0].name}
  name: aks-nvme-ssd-mount
  labels:
    app: aks-nvme-ssd-mount
spec:
  selector:
    matchLabels:
      name: aks-nvme-ssd-mount
  template:
    metadata:
      labels:
        name: aks-nvme-ssd-mount
    spec:
      automountServiceAccountToken: false
      hostPID: true
      nodeSelector:
        aks-local-ssd: "true"
      tolerations:
        - key: "longhorn-node"
          operator: "Equal"
          value: "true"
          effect: "NoSchedule"
      priorityClassName: system-node-critical
      containers:
        - name: aks-nvme-ssd-mount
          image: zzorica/aks-nvme-ssd-mount:v0.0.2
          imagePullPolicy: Always
          securityContext:
            privileged: true
          volumeMounts:
            - mountPath: /nvme
              name: local-storage
              mountPropagation: "Bidirectional"
      volumes:
        - name: local-storage
          hostPath:
            path: /nvme
YAML
}

resource "kubectl_manifest" "longhorn_priority_class" {
  yaml_body = <<YAML
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: custom-node-critical
value: 1000000000
globalDefault: false
description: "Custom PriorityClass for longhorn pods"
YAML
}

resource "kubectl_manifest" "longhorn_iscsi" {
  yaml_body = <<YAML
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: longhorn-iscsi-installation
  namespace: ${kubernetes_namespace.longhorn-system.metadata[0].name}
  labels:
    app: longhorn-iscsi-installation
  annotations:
    command: &cmd OS=$(grep -E "^ID_LIKE=" /etc/os-release | cut -d '=' -f 2); if [[ -z "$${OS}" ]]; then OS=$(grep -E "^ID=" /etc/os-release | cut -d '=' -f 2); fi; if [[ "$${OS}" == *"debian"* ]]; then sudo apt-get update -q -y && sudo apt-get install -q -y open-iscsi && sudo systemctl -q enable iscsid && sudo systemctl start iscsid && sudo modprobe iscsi_tcp; elif [[ "$${OS}" == *"suse"* ]]; then sudo zypper --gpg-auto-import-keys -q refresh && sudo zypper --gpg-auto-import-keys -q install -y open-iscsi && sudo systemctl -q enable iscsid && sudo systemctl start iscsid && sudo modprobe iscsi_tcp; else sudo yum makecache -q -y && sudo yum --setopt=tsflags=noscripts install -q -y iscsi-initiator-utils && echo "InitiatorName=$(/sbin/iscsi-iname)" > /etc/iscsi/initiatorname.iscsi && sudo systemctl -q enable iscsid && sudo systemctl start iscsid && sudo modprobe iscsi_tcp; fi && if [ $? -eq 0 ]; then echo "iscsi install successfully"; else echo "iscsi install failed error code $?"; fi
spec:
  selector:
    matchLabels:
      app: longhorn-iscsi-installation
  template:
    metadata:
      labels:
        app: longhorn-iscsi-installation
    spec:
      hostNetwork: true
      hostPID: true
      nodeSelector:
        aks-local-ssd: "true"
      tolerations:
      - key: "longhorn-node"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"
      initContainers:
      - name: iscsi-installation
        command:
          - nsenter
          - --mount=/proc/1/ns/mnt
          - --
          - bash
          - -c
          - *cmd
        image: alpine:3.17
        securityContext:
          privileged: true
      containers:
      - name: sleep
        image: registry.k8s.io/pause:3.1
  updateStrategy:
    type: RollingUpdate
YAML

  depends_on = [
    kubectl_manifest.aks_raid_disks,
  ]

}

resource "helm_release" "longhorn" {
  name             = "longhorn"
  repository       = "https://charts.longhorn.io"
  chart            = "longhorn"
  version          = "1.5.3"
  create_namespace = false
  namespace        = kubernetes_namespace.longhorn-system.metadata[0].name
  timeout          = 300
  atomic           = true
  wait             = true

  values = [
    <<EOF
persistence:
  defaultClass: false
  defaultClassReplicaCount: 3
csi:
  kubeletRootDir: /var/lib/kubelet
defaultSettings:
  deletingConfirmationFlag: true
  createDefaultDiskLabeledNodes: true
  defaultDataPath: /nvme/disk
  kubernetesClusterAutoscalerEnabled: true
  replicaAutoBalance: best-effort
  replica-replenishment-wait-interval: 0
  storageOverProvisioningPercentage: 500
  storageMinimalAvailablePercentage: 10
  storageReservedPercentageForDefaultDisk: 15
  taintToleration: "longhorn-node=true:NoSchedule;workernode=true:NoSchedule"
  priorityClass: system-node-critical
  guaranteedInstanceManagerCPU: 15
longhornManager:
  priorityClass: system-node-critical
  tolerations:
    - key: "longhorn-node"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"
    - key: "workernode"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"
longhornDriver:
  priorityClass: system-node-critical
  tolerations:
    - key: "longhorn-node"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"
    - key: "workernode"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"
  EOF
  ]

  depends_on = [
    kubectl_manifest.aks_raid_disks,
    kubectl_manifest.longhorn_iscsi,
    kubectl_manifest.longhorn_priority_class,
  ]
}
