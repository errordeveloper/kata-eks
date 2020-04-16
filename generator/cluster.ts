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

function makeMetadata(namespace: string, cluster: string, role?: roles, nameSuffix?: string) {
    const labels = {
        cluster,
        role,
    }
    let name:string
    if (role) {
        name = `${cluster}-${role}`
    } else {
        name = cluster
    }
    if (nameSuffix) {
        name = `${name}-${nameSuffix}`
    }

    return { name, namespace, labels }
}

function makeAPIService(namespace: string, cluster: string) {
    const metadata = makeMetadata(namespace, cluster, roles.master)

    return {
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
    }
}

function makeServiceAccount(namespace: string, cluster: string, role: roles) {
    const metadata = makeMetadata(namespace, cluster, role)

    return {
        apiVersion: "v1",
        kind: "ServiceAccount",
        metadata,
        // systemd shaddows /run/secrets, so serviceaccount secrts are mounted differently
        automountServiceAccountToken: false,
    }
}

function makeSecret(namespace: string, cluster: string, name: string) {
    const metadata = makeMetadata(namespace, cluster, undefined, name)

    return {
        apiVersion: "v1",
        kind: "Secret",
        metadata,
    }
}

function makeMasterRoleAndBinding(namespace: string, cluster: string) {
    const metadata = makeMetadata(namespace, cluster, roles.master)

    return [
        {
            apiVersion: "rbac.authorization.k8s.io/v1",
            kind: "Role",
            metadata,
            rules: [
                {
                    apiGroups: [
                        ""
                    ],
                    resourceNames: [
                        `${cluster}-${secretNames.kubeconfig}`,
                        `${cluster}-${secretNames.joinToken}`,
                    ],
                    resources: [
                        "secrets"
                    ],
                    verbs: [
                        "get",
                        "patch"
                    ],
                },
            ]
        },
        {
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
        },
    ]
}

function makeDeployment(namespace: string, cluster: string, image: string, role: roles, nodes?: number) {
    const metadata = makeMetadata(namespace, cluster, roles.master)
    const spec = makeDeploymentSpec(metadata, image, role, nodes)

    return {
        apiVersion: "apps/v1",
        kind: "Deployment",
        metadata,
        spec,
    }
}

function makeDeploymentSpec(metadata: any, image: string, role: roles, nodes?: number) {
    let replicas: number,
        kubeconfig: string,
        readinessProbe: object,
        volumes: object[],
        volumeMounts: object[]

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
                {
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
                // TODO: generate kubeadm configs here?
                // TODO: consider generating scripts and systemd units also, so image can be more static...
                {
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
                },
            ]

            volumeMounts = [
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
                    name: "parent-management-cluster-service-account-token",
                    mountPath: "/etc/parent-management-cluster/secrets",
                },
                {
                    name: "metadata",
                    mountPath: "/etc/kubeadm/metadata",
                },
            ]

            break;
        case roles.node:
            replicas = nodes||2

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
                {
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
                // TODO: generate kubeadm configs here?
                // TODO: consider generating scrips and systemd units also, so image can be more static...
                {
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
                },
                // TODO: commonVolumes
                {
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
                }
            ]

            volumeMounts = [
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
                // TODO: commonVolumeMounts
                {
                    name: "join-secret",
                    mountPath: "/etc/kubeadm/secrets",
                },
            ]

            break;
    }
    
    const containers = [{
        name: "main",
        image,
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
                    "io.katacontainers.config.hypervisor.default_memory": "4096",
                    "io.katacontainers.config.hypervisor.default_vcpus": "2",
                    "io.katacontainers.config.hypervisor.image": "/var/lib/images/vm/kata-agent-ubuntu.img",
                    "io.katacontainers.config.hypervisor.kernel": "/var/lib/images/kernel/linuxkit/vmlinuz-5.4.19-linuxkit",
                    "io.katacontainers.config_path": "/opt/kata/share/defaults/kata-containers/configuration-qemu-debug.toml"
                }
            },
            spec: {
                // TODO: this should be parametrised
                runtimeClassName: "kata-qemu",
                serviceAccountName: `${metadata.labels.cluster}-${role}`,

                containers,
                volumes,
            }
        }
    }
}

const currentImage = "errordeveloper/kubeadm:ubuntu-18.04-1.18.0@sha256:7d407b9929da20df6bfa606910b893ad87b81ede15f1e7f19b4875be2f56be55"

// TODO these should be methods on a cluster object
const objects = [
    makeAPIService("test-1", "cluster-1"),
    makeServiceAccount("test-1", "cluster-1", roles.master),
    makeSecret("test-1", "cluster-1", secretNames.kubeconfig),
    makeSecret("test-1", "cluster-1", secretNames.joinToken),
    ...makeMasterRoleAndBinding("test-1", "cluster-1"),
    makeDeployment("test-1", "cluster-1", currentImage, roles.master),
    makeServiceAccount("test-1", "cluster-1", roles.node),
    makeDeployment("test-1", "cluster-1", currentImage, roles.node, 10),
];

function makeList(items: any[]) {
    return {
        apiVersion: "v1",
        kind: "List",
        items,
    }
}

export default [
    { value: makeList(objects), file: `cluster.yaml` },
];
