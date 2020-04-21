//import * as std from '@jkcfg/std';
import * as param from '@jkcfg/std/param';

const namespace = param.String("namespace") || "default"
const name = param.String("name") || "test-cluster"
const nodes = param.Number("nodes") || 2

const image = param.String("image") || "errordeveloper/kubeadm:ubuntu-18.04-1.18.1"

import { KubernetesCluster, runtimeClasses } from './cluster';

const cluster = new KubernetesCluster({
    namespace, name, image, nodes,
    runtime: {class: runtimeClasses.kataQemu},
})

let output: { value: any, file: string }[] = [
    { value: cluster.build(), file: `cluster-${namespace}-${name}.yaml` },
];

if (param.Boolean("sonobuoy")) {
    output.push({ value: cluster.sonobuoy("sonobuoy/sonobuoy:v0.18.0"), file: `cluster-${namespace}-${name}-sonobuoy-job.yaml` })
}

export default output
