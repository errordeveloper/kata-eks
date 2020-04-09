#!/bin/bash -x

set -o errexit
set -o pipefail
set -o nounset

mkdir -p /etc/systemd/system /etc/containerd /etc/kubernetes/manifests /var/lib/kubelet /etc/cni/net.d

cat > /etc/sysctl.d/99-kubernetes-cri.conf << EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

cat > /etc/modules-load.d/99-containerd.conf << EOF
overlay
br_netfilter
EOF

cat > /etc/modules-load.d/99-cilium.conf << EOF
sch_ingress
EOF

cp /usr/share/systemd/tmp.mount /etc/systemd/system/

systemctl enable tmp.mount

cat > /etc/systemd/system/containerd.service << EOF
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Install]
WantedBy=multi-user.target

[Service]
ExecStart=/usr/bin/containerd
Delegate=yes
KillMode=process
Restart=always
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=1048576
# Comment TasksMax if your systemd version does not supports it.
# Only systemd 226 and above support this version.
TasksMax=infinity
OOMScoreAdjust=-999
EOF

systemctl enable containerd

cat > /etc/containerd/config.toml << EOF
version = 2
# use tmpfs in /run for both directories now, we may preserve root in the future,
# and possibly even preload it with images, but right now using /var/lib is broken
# in kata as it's on 9p filesystem that doesn't permit mknod
root = "/run/containerd/root"
state = "/run/containerd/state"
plugin_dir = ""
disabled_plugins = []
required_plugins = []
oom_score = 0

[grpc]
  address = "/run/containerd/containerd.sock"
  tcp_address = ""
  tcp_tls_cert = ""
  tcp_tls_key = ""
  uid = 0
  gid = 0
  max_recv_message_size = 16777216
  max_send_message_size = 16777216

[ttrpc]
  address = ""
  uid = 0
  gid = 0

[debug]
  address = ""
  uid = 0
  gid = 0
  level = ""

[metrics]
  address = ""
  grpc_histogram = false

[cgroup]
  path = ""

[timeouts]
  "io.containerd.timeout.shim.cleanup" = "5s"
  "io.containerd.timeout.shim.load" = "5s"
  "io.containerd.timeout.shim.shutdown" = "3s"
  "io.containerd.timeout.task.state" = "2s"

[plugins]
  [plugins."io.containerd.gc.v1.scheduler"]
    pause_threshold = 0.02
    deletion_threshold = 0
    mutation_threshold = 100
    schedule_delay = "0s"
    startup_delay = "100ms"
  [plugins."io.containerd.grpc.v1.cri"]
    disable_tcp_service = true
    stream_server_address = "127.0.0.1"
    stream_server_port = "0"
    stream_idle_timeout = "4h0m0s"
    enable_selinux = false
    sandbox_image = "k8s.gcr.io/pause:3.1"
    stats_collect_period = 10
    systemd_cgroup = false
    enable_tls_streaming = false
    max_container_log_line_size = 16384
    disable_cgroup = false
    disable_apparmor = false
    restrict_oom_score_adj = false
    max_concurrent_downloads = 3
    disable_proc_mount = false
    [plugins."io.containerd.grpc.v1.cri".containerd]
      snapshotter = "overlayfs"
      default_runtime_name = "runc"
      no_pivot = false
      [plugins."io.containerd.grpc.v1.cri".containerd.default_runtime]
        runtime_type = ""
        runtime_engine = ""
        runtime_root = ""
        privileged_without_host_devices = false
      [plugins."io.containerd.grpc.v1.cri".containerd.untrusted_workload_runtime]
        runtime_type = ""
        runtime_engine = ""
        runtime_root = ""
        privileged_without_host_devices = false
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v1"
          runtime_engine = ""
          runtime_root = ""
          privileged_without_host_devices = false
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = false
    [plugins."io.containerd.grpc.v1.cri".cni]
      bin_dir = "/opt/cni/bin"
      conf_dir = "/etc/cni/net.d"
      max_conf_num = 1
      conf_template = ""
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://registry-1.docker.io"]
    [plugins."io.containerd.grpc.v1.cri".x509_key_pair_streaming]
      tls_cert_file = ""
      tls_key_file = ""
  [plugins."io.containerd.internal.v1.opt"]
    path = "/opt/containerd"
  [plugins."io.containerd.internal.v1.restart"]
    interval = "10s"
  [plugins."io.containerd.metadata.v1.bolt"]
    content_sharing_policy = "shared"
  [plugins."io.containerd.monitor.v1.cgroups"]
    no_prometheus = false
  [plugins."io.containerd.runtime.v1.linux"]
    shim = "containerd-shim"
    runtime = "runc"
    runtime_root = ""
    no_shim = false
    shim_debug = false
  [plugins."io.containerd.runtime.v2.task"]
    platforms = ["linux/amd64"]
  [plugins."io.containerd.service.v1.diff-service"]
    default = ["walking"]
  [plugins."io.containerd.snapshotter.v1.devmapper"]
    root_path = ""
    pool_name = ""
    base_image_size = ""
EOF

cat > /etc/systemd/system/images.service << EOF
[Unit]
After=containerd.service
Requires=containerd.service

[Install]
WantedBy=multi-user.target

[Service]
Type=oneshot
EnvironmentFile=/etc/versions.env
ExecStart=/usr/bin/preload-images.sh
EOF

systemctl enable images


cat > /etc/systemd/system/kubeadm.target << EOF
[Unit]
Requires=multi-user.target
Conflicts=rescue.service rescue.target
After=multi-user.target basic.target rescue.service rescue.target
AllowIsolate=yes
EOF

cat > /etc/systemd/system/kubeadm.service << EOF
[Unit]
After=images.service
Requires=images.service

[Install]
WantedBy=kubeadm.target

[Service]
Type=oneshot
EnvironmentFile=/etc/versions.env
# it looks CPU detection doesn't work very well, and with 3 cores it still barks;
# --cri-socket is required also, as somehow autodetection is broken when
# this command runs in the context of this systemd unit
# TODO: detect if kata is in use and pass diffetent ignore-preflight-errors
#ExecStart=/usr/bin/kubeadm init --v=9 --kubernetes-version=\${KUBERNETES_VERSION} --ignore-preflight-errors=NumCPU --cri-socket=/var/run/containerd/containerd.sock
ExecStart=/usr/bin/kubeadm init --v=9 --kubernetes-version=\${KUBERNETES_VERSION} --ignore-preflight-errors=NumCPU,SystemVerification,FileContent--proc-sys-net-bridge-bridge-nf-call-iptables --cri-socket=/var/run/containerd/containerd.sock
ExecStart=/usr/bin/kubectl apply --filename=/etc/cilium.yaml --kubeconfig=/etc/kubernetes/admin.conf
EOF

systemctl enable kubeadm.service # TODO use a drop-in on nodes to override the command, or write a shell script wrapper

cat > /etc/systemd/system/kubelet.service << EOF
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/home/
Before=kubeadm.service

[Install]
WantedBy=kubeadm.target

[Service]
ExecStart=/usr/bin/kubelet \
  --config=/etc/kubernetes/kubelet.yaml \
  --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf \
  --container-runtime=remote --container-runtime-endpoint=unix:///run/containerd/containerd.sock
Delegate=yes
Restart=always
StartLimitInterval=0
RestartSec=5
EOF

cat > /etc/kubernetes/kubelet.yaml << EOF
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 0s
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 0s
    cacheUnauthorizedTTL: 0s
clusterDNS:
- 10.96.0.10
clusterDomain: cluster.local
cpuManagerReconcilePeriod: 0s
evictionPressureTransitionPeriod: 0s
fileCheckFrequency: 0s
healthzBindAddress: 127.0.0.1
healthzPort: 10248
httpCheckFrequency: 0s
imageMinimumGCAge: 0s
nodeStatusReportFrequency: 0s
nodeStatusUpdateFrequency: 0s
rotateCertificates: true
runtimeRequestTimeout: 0s
staticPodPath: /etc/kubernetes/manifests
streamingConnectionIdleTimeout: 0s
syncFrequency: 0s
volumeStatsAggPeriod: 0s
#cgroupDriver: systemd
resolvConf: /run/systemd/resolve/resolv.conf
EOF

systemctl enable kubelet

cat > /etc/kubernetes/parent.conf << EOF
apiVersion: v1
kind: Config
clusters:
  - name: parent-management-cluster
    cluster:
      server: https://kubernetes.default.svc:443
      certificate-authority: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
users:
  - name: child-cluster
    user:
      tokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
contexts:
  - name: parent-management-cluster-context
    context:
      cluster: parent-management-cluster
      user: child-cluster
current-context: parent-management-cluster-context
EOF
