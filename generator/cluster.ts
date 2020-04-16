// TODO: import jk's kubernetes types

enum roles {
    master = "master",
    node = "node",
}

enum secretNames {
    joinToken = "join-token",
    kubeconfig = "kubeconfig",
}

enum ports {
    kubernetesAPI = 6443,
}

interface KubernetesClusterSpec {
    name: string
    namespace: string
    image: string
    nodes?: number
}

class KubernetesCluster {
    private cluster: KubernetesClusterSpec

    private items: object[]

    constructor(cluster: KubernetesClusterSpec) {
        this.cluster = cluster
        this.items = []
    }

    private makeMetadata({ roleLabel, nameSuffix }: { roleLabel?: roles; nameSuffix?: string } = {}) {
        const meta = {
            namespace: this.cluster.namespace,
            labels: {
                cluster: this.cluster.name,
                role: roleLabel,
            },
        }

        if (nameSuffix) {
            return Object.assign({}, meta, { name: `${this.cluster.name}-${nameSuffix}` })
        } else {
            return Object.assign({}, meta, { name: this.cluster.name })
        }
    }

    private makeAPIService(): void {
        const metadata = this.makeMetadata({roleLabel: roles.master})

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
        })
    }

    private makeServiceAccount(role: roles): void {
        const metadata = this.makeMetadata({roleLabel: role, nameSuffix: role})

        this.items.push({
            apiVersion: "v1",
            kind: "ServiceAccount",
            metadata,
        })
    }

    private makeSecret(name: string): void {
        const metadata = this.makeMetadata({nameSuffix: name})

        this.items.push({
            apiVersion: "v1",
            kind: "Secret",
            metadata,
        })
    }

    private makeMasterRoleAndBinding(): void {
        const metadata = this.makeMetadata({roleLabel: roles.master, nameSuffix: roles.master})

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
        })

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
        })
    }

    private makeDeployment(role: roles): void {
        const metadata = this.makeMetadata({roleLabel: role, nameSuffix: role})
        const spec = this.makeDeploymentSpec(metadata, role)

        this.items.push({
            apiVersion: "apps/v1",
            kind: "Deployment",
            metadata,
            spec,
        })
    }

    private makeDeploymentSpec(metadata: any, role: roles) {
        let replicas: number,
            kubeconfig: string,
            readinessProbe: object,
            volumes: object[],
            volumeMounts: object[]

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
        ]

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
        }

        const commonVolumeMounts = [
            {
                name: "images",
                mountPath: "/images",
            },
            {
                name: "bpf-maps",
                mountPath: "/sys/fs/bpf",
                mountPropagation: "Bidirectional", // required due to nesting, so that cilium pod can use
            },
            {
                name: "metadata",
                mountPath: "/etc/kubeadm/metadata",
            },
        ]

        // TODO: add top-level runtime class param or boolean virt param
        // const nonKataVolumes = [
        //     {
        //         name: "proc",
        //         hostPath: {
        //             type: "Directory",
        //             path: "/proc",
        //         },
        //     },
        //     {
        //         name: "lib-modules",
        //         hostPath: {
        //             type: "Directory",
        //             path: "/lib/modules",
        //         },
        //     },
        //     {
        //         name: "xtables-lock",
        //         hostPath: {
        //             type: "FileOrCreate",
        //             path: "/run/xtables.lock",
        //         },
        //     }
        // ]
        // const nonKataVolumeMounts = [
        //     {
        //         name: "proc",
        //         mountPath: "/proc",
        //     },
        //     {
        //         name: "lib-modules",
        //         mountPath: "/lib/modules",
        //         readOnly: true,
        //     },
        //     {
        //         name: "xtables-lock",
        //         mountPath: "/run/xtables.lock",
        //     },
        // ]

        switch (role) {
            case roles.master:
                replicas = 1

                kubeconfig = "/etc/kubernetes/admin.conf"

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
                }

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
                ]

                volumeMounts = [
                    ...commonVolumeMounts,
                    {
                        name: "parent-management-cluster-service-account-token",
                        mountPath: "/etc/parent-management-cluster/secrets",
                    },
                ]

                break;
            case roles.node:
                replicas = this.cluster.nodes||2

                kubeconfig = "/etc/kubernetes/kubelet.conf"

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
                }

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
                ]

                volumeMounts = [
                    ...commonVolumeMounts,
                    {
                        name: "join-secret",
                        mountPath: "/etc/kubeadm/secrets",
                    },
                ]

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
        }]


        return {
            replicas,
            selector: {
                matchLabels: metadata.labels,
            },
            template: {
                metadata: {
                    labels: metadata.labels,
                    annotations: {
                        // TODO: these should be parametrised
                        "io.katacontainers.config.hypervisor.image": "/var/lib/images/vm/kata-agent-ubuntu.img",
                        "io.katacontainers.config.hypervisor.kernel": "/var/lib/images/kernel/linuxkit/vmlinuz-5.4.19-linuxkit",
                        "io.katacontainers.config_path": "/opt/kata/share/defaults/kata-containers/configuration-qemu-debug.toml",
                        // TODO: check if CONFIG_MEMORY_HOTPLUG is set, as kata relies on that
                        "io.katacontainers.config.hypervisor.default_memory": "4096",
                        "io.katacontainers.config.hypervisor.default_vcpus": "2",
                    }
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
        }
    }

    private makeList(items: any[]) {
        return {
            apiVersion: "v1",
            kind: "List",
            items,
        }
    }

    build() {
        this.makeAPIService()
        this.makeServiceAccount(roles.master)
        this.makeSecret(secretNames.kubeconfig)
        this.makeSecret(secretNames.joinToken)
        this.makeMasterRoleAndBinding()
        this.makeDeployment(roles.master)
        this.makeServiceAccount(roles.node)
        this.makeDeployment(roles.node)

        return this.makeList(this.items)
    }
}

const cluster = new KubernetesCluster({namespace: "default", name: "test-cluster", image: "errordeveloper/kubeadm:ubuntu-18.04-1.18.0@sha256:7d407b9929da20df6bfa606910b893ad87b81ede15f1e7f19b4875be2f56be55", nodes: 10})

export default [
    { value: cluster.build(), file: `cluster.yaml` },
];
