// TODO: import jk's kubernetes types
var roles;
(function (roles) {
    roles["master"] = "master";
    roles["node"] = "node";
})(roles || (roles = {}));
var secretNames;
(function (secretNames) {
    secretNames["joinToken"] = "join-token";
    secretNames["kubeconfig"] = "kubeconfig";
})(secretNames || (secretNames = {}));
var ports;
(function (ports) {
    ports[ports["kubernetesAPI"] = 6443] = "kubernetesAPI";
})(ports || (ports = {}));
var runtimeClasses;
(function (runtimeClasses) {
    runtimeClasses["kataQemu"] = "kata-qemu";
    runtimeClasses["kataFirecracker"] = "kata-fc";
})(runtimeClasses || (runtimeClasses = {}));
var kataConfigs;
(function (kataConfigs) {
    kataConfigs["qemu"] = "/opt/kata/share/defaults/kata-containers/configuration-qemu.toml";
    kataConfigs["qemuDebug"] = "/opt/kata/share/defaults/kata-containers/configuration-qemu-debug.toml";
    kataConfigs["default"] = "/opt/kata/share/defaults/kata-containers/configuration-qemu-debug.toml";
})(kataConfigs || (kataConfigs = {}));
var kataImages;
(function (kataImages) {
    kataImages["customUbuntu"] = "/var/lib/images/vm/kata-agent-ubuntu.img";
    kataImages["default"] = "/var/lib/images/vm/kata-agent-ubuntu.img";
})(kataImages || (kataImages = {}));
var kataKernels;
(function (kataKernels) {
    kataKernels["linuxkit_5_4_19"] = "/var/lib/images/kernel/linuxkit/vmlinuz-5.4.19-linuxkit";
    kataKernels["linuxkit_4_19_104"] = "/var/lib/images/kernel/linuxkit/vmlinuz-4.19.104-linuxkit";
    kataKernels["default"] = "/var/lib/images/kernel/linuxkit/vmlinuz-5.4.19-linuxkit";
})(kataKernels || (kataKernels = {}));
class KubernetesCluster {
    constructor(cluster) {
        this.cluster = cluster;
        this.items = [];
    }
    makeMetadata({ roleLabel, nameSuffix } = {}) {
        const meta = {
            namespace: this.cluster.namespace,
            labels: {
                cluster: this.cluster.name,
                role: roleLabel,
            },
        };
        if (nameSuffix) {
            return Object.assign({}, meta, { name: `${this.cluster.name}-${nameSuffix}` });
        }
        else {
            return Object.assign({}, meta, { name: this.cluster.name });
        }
    }
    makeKataAnnotations() {
        var _a, _b, _c, _d, _e, _f;
        const keyPrefix = "io.katacontainers.config";
        return {
            [`${keyPrefix}_path`]: ((_b = (_a = this.cluster.runtime) === null || _a === void 0 ? void 0 : _a.kata) === null || _b === void 0 ? void 0 : _b.config) || kataConfigs.default,
            [`${keyPrefix}.hypervisor.image`]: ((_d = (_c = this.cluster.runtime) === null || _c === void 0 ? void 0 : _c.kata) === null || _d === void 0 ? void 0 : _d.image) || kataImages.default,
            [`${keyPrefix}.hypervisor.kernel`]: ((_f = (_e = this.cluster.runtime) === null || _e === void 0 ? void 0 : _e.kata) === null || _f === void 0 ? void 0 : _f.kernel) || kataKernels.default,
            // TODO: check if CONFIG_MEMORY_HOTPLUG is set, as kata relies on that;
            // normally one should use container resource limits/request
            [`${keyPrefix}.hypervisor.default_memory`]: "4096",
            [`${keyPrefix}.hypervisor.default_vcpus`]: "2",
        };
    }
    makeAPIService() {
        const metadata = this.makeMetadata({ roleLabel: roles.master });
        this.items.push({
            apiVersion: "v1",
            kind: "Service",
            metadata,
            spec: {
                ports: [
                    {
                        port: ports.kubernetesAPI,
                        protocol: "TCP",
                        targetPort: ports.kubernetesAPI
                    }
                ],
                selector: metadata.labels,
                sessionAffinity: "None",
                type: "ClusterIP"
            }
        });
    }
    makeServiceAccount(role) {
        const metadata = this.makeMetadata({ roleLabel: role, nameSuffix: role });
        this.items.push({
            apiVersion: "v1",
            kind: "ServiceAccount",
            metadata,
        });
    }
    makeSecret(name) {
        const metadata = this.makeMetadata({ nameSuffix: name });
        this.items.push({
            apiVersion: "v1",
            kind: "Secret",
            metadata,
        });
    }
    makeMasterRoleAndBinding() {
        const metadata = this.makeMetadata({ roleLabel: roles.master, nameSuffix: roles.master });
        this.items.push({
            apiVersion: "rbac.authorization.k8s.io/v1",
            kind: "Role",
            metadata,
            rules: [
                {
                    apiGroups: [
                        ""
                    ],
                    resourceNames: [
                        `${this.cluster.name}-${secretNames.kubeconfig}`,
                        `${this.cluster.name}-${secretNames.joinToken}`,
                    ],
                    resources: [
                        "secrets"
                    ],
                    verbs: [
                        "get",
                        "patch"
                    ],
                }
            ]
        });
        this.items.push({
            apiVersion: "rbac.authorization.k8s.io/v1",
            kind: "RoleBinding",
            metadata,
            roleRef: {
                apiGroup: "rbac.authorization.k8s.io",
                kind: "Role",
                name: metadata.name,
            },
            subjects: [
                {
                    kind: "ServiceAccount",
                    name: metadata.name,
                }
            ]
        });
    }
    makeDeployment(role) {
        const metadata = this.makeMetadata({ roleLabel: role, nameSuffix: role });
        const spec = this.makeDeploymentSpec(metadata, role);
        this.items.push({
            apiVersion: "apps/v1",
            kind: "Deployment",
            metadata,
            spec,
        });
    }
    makeDeploymentSpec(metadata, role) {
        var _a;
        let replicas, kubeconfig, readinessProbe, volumes, volumeMounts;
        let annotations = {};
        let useKata = false;
        switch ((_a = this.cluster.runtime) === null || _a === void 0 ? void 0 : _a.class) {
            case runtimeClasses.kataFirecracker:
            case runtimeClasses.kataQemu:
                useKata = true;
                annotations = this.makeKataAnnotations();
                break;
        }
        const commonVolumes = [
            {
                // TODO consider adding initContainers to wait for /var/images to have the right files, or at least some file
                name: "images",
                hostPath: {
                    type: "Directory",
                    path: "/var/lib/images",
                },
            },
            {
                name: "bpf-maps",
                hostPath: {
                    type: "Directory",
                    path: "/sys/fs/bpf",
                },
            },
        ];
        // TODO: generate kubeadm configs here?
        // TODO: consider generating scripts and systemd units also, so image can be more static...
        const projectedVolumeBase = {
            name: "metadata",
            downwardAPI: {
                items: [
                    {
                        fieldRef: {
                            fieldPath: "metadata.labels"
                        },
                        path: "labels",
                    },
                    {
                        fieldRef: {
                            fieldPath: "metadata.namespace"
                        },
                        path: "namespace",
                    },
                ]
            }
        };
        const commonVolumeMounts = [
            {
                name: "images",
                mountPath: "/images",
            },
            {
                name: "bpf-maps",
                mountPath: "/sys/fs/bpf",
                mountPropagation: "Bidirectional",
            },
            {
                name: "metadata",
                mountPath: "/etc/kubeadm/metadata",
            },
        ];
        if (!useKata) {
            commonVolumes.push(...[
                {
                    name: "proc",
                    hostPath: {
                        type: "Directory",
                        path: "/proc",
                    },
                },
                {
                    name: "lib-modules",
                    hostPath: {
                        type: "Directory",
                        path: "/lib/modules",
                    },
                },
                {
                    name: "xtables-lock",
                    hostPath: {
                        type: "FileOrCreate",
                        path: "/run/xtables.lock",
                    },
                }
            ]);
            commonVolumeMounts.push(...[
                {
                    name: "proc",
                    mountPath: "/proc",
                },
                {
                    name: "lib-modules",
                    mountPath: "/lib/modules",
                    readOnly: true,
                },
                {
                    name: "xtables-lock",
                    mountPath: "/run/xtables.lock",
                },
            ]);
        }
        switch (role) {
            case roles.master:
                replicas = 1;
                kubeconfig = "/etc/kubernetes/admin.conf";
                readinessProbe = {
                    exec: {
                        command: [
                            "/usr/bin/is-master-ready.sh"
                        ]
                    },
                    failureThreshold: 500,
                    initialDelaySeconds: 30,
                    periodSeconds: 2,
                    successThreshold: 5,
                };
                volumes = [
                    ...commonVolumes,
                    projectedVolumeBase,
                    {
                        // TODO: make this part of the projected `/etc/kubeadm` volume
                        // also generate the contets of kubeconfig from here
                        name: "parent-management-cluster-service-account-token",
                        projected: {
                            sources: [
                                {
                                    serviceAccountToken: {
                                        path: "token"
                                    }
                                }
                            ]
                        }
                    },
                ];
                volumeMounts = [
                    ...commonVolumeMounts,
                    {
                        name: "parent-management-cluster-service-account-token",
                        mountPath: "/etc/parent-management-cluster/secrets",
                    },
                ];
                break;
            case roles.node:
                replicas = this.cluster.nodes || 2;
                kubeconfig = "/etc/kubernetes/kubelet.conf";
                readinessProbe = {
                    exec: {
                        command: [
                            "/usr/bin/is-node-ready.sh"
                        ]
                    },
                    failureThreshold: 500,
                    initialDelaySeconds: 30,
                    periodSeconds: 2,
                    successThreshold: 5,
                };
                volumes = [
                    ...commonVolumes,
                    projectedVolumeBase,
                    {
                        // TODO: make this part of the projected `/etc/kubeadm` volume
                        // also generate the contets of kubeconfig from here
                        name: "join-secret",
                        projected: {
                            sources: [
                                {
                                    secret: {
                                        name: "test-cluster-join-token",
                                        optional: false,
                                    }
                                }
                            ]
                        }
                    },
                ];
                volumeMounts = [
                    ...commonVolumeMounts,
                    {
                        name: "join-secret",
                        mountPath: "/etc/kubeadm/secrets",
                    },
                ];
                break;
        }
        const containers = [{
                name: "main",
                image: this.cluster.image,
                imagePullPolicy: "Always",
                command: [
                    "/lib/systemd/systemd",
                    `--unit=kubeadm@${role}.target`
                ],
                readinessProbe,
                env: [
                    {
                        name: "KUBECONFIG",
                        value: kubeconfig,
                    }
                ],
                volumeMounts,
                securityContext: {
                    privileged: true,
                },
                tty: true,
            }];
        return {
            replicas,
            selector: {
                matchLabels: metadata.labels,
            },
            template: {
                metadata: {
                    labels: metadata.labels,
                    annotations,
                },
                spec: {
                    // TODO: this should be parametrised
                    runtimeClassName: "kata-qemu",
                    serviceAccountName: `${metadata.labels.cluster}-${role}`,
                    // systemd shaddows /run/secrets, so serviceaccount secrts are mounted differently
                    automountServiceAccountToken: false,
                    containers,
                    volumes,
                }
            }
        };
    }
    makeList(items) {
        return {
            apiVersion: "v1",
            kind: "List",
            items,
        };
    }
    build() {
        this.makeAPIService();
        this.makeServiceAccount(roles.master);
        this.makeSecret(secretNames.kubeconfig);
        this.makeSecret(secretNames.joinToken);
        this.makeMasterRoleAndBinding();
        this.makeDeployment(roles.master);
        this.makeServiceAccount(roles.node);
        this.makeDeployment(roles.node);
        return this.makeList(this.items);
    }
}
const cluster = new KubernetesCluster({
    namespace: "default",
    name: "test-cluster",
    image: "errordeveloper/kubeadm:ubuntu-18.04-1.18.0@sha256:7d407b9929da20df6bfa606910b893ad87b81ede15f1e7f19b4875be2f56be55",
    nodes: 10,
    runtime: { class: runtimeClasses.kataQemu },
});
export default [
    { value: cluster.build(), file: `cluster.yaml` },
];
