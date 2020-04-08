# Kata Containers on EKS

This repo demostrates how to setup an EKS cluster with [Kata Containers](https://katacontainers.io/) as CRI (via containerd).

To create a cluster, run `eksctl`:

```
eksctl create cluster --config-file=cluster.yaml --without-nodegroup
```

This will create a cluster without a nodegroup to begin with (so VPC CNI can be replaced with Cilium).
Later a nodegroup will be added to the cluster.

Kata currently doesn't work with built-in VPC CNI, however it works perfectly with Cilium.
Before deploying Cilium, `kube-system:daemonset/aws-node` need to be deleted:

```
kubectl delete --namespace=kube-system daemonset aws-node
```

Deploy Cilium:

```
kubectl apply -f cilium-1.7-eks.yaml
```

The `eksctl` config file (`cluster-management.yaml`) has a custom bootstrap script that use a self-extracting
container image to deploy Kata components (see `images/extract` and `images/kata-installer` for details). 

The nodegroup uses `i3.metal` instance type (just one instance to save costs, of course, it can be scaled up).

Next, deploy runtimeclasses `kata-qemu` and `kata-fc`:

```
kubectl apply -f kata-runtimeclasses.yaml
```

Before adding a nodegroup, deploy a `kube-system:daemonset/kata-node-init`, it will ensure the node has latest
cutom VM image for use with Kata.

> *NOTE:* If you are only planning to use oficial Kata kernel and VM image, you don't need to have this daemonset.

```
kubectl apply -f kata-node-init.yaml
```

Next, add a nodegroup:
```
eksctl create nodegroup --config-file=management-cluster.yaml
```

Once `eksctl` exits, there should be one `i3.metal` node in this cluseter:

```
kubectl get nodes
```

Next, you may wish to observe `kube-system` namespace, once all pods are ready, the cluster should be ready to
run Kata pods/VMs and any workload in general.

```
kubectl get pods --namespace=kube-system
```

Now, you can try `kubectl apply -f podinfo.yaml` and just deploy a simple app with `runtimeClass: kata-qemu`.

# Work-in-progress: running Kubernetes

You might like to look at `images/kubeadm-ubuntu`, or just deploy the pods and take it from there:
```
kubectl apply -f test-cluster.yaml
```

The master pod should become 'Ready' once it ran `kubeadm init`.

To test the master pod, try `./kubectl-each-master.sh get nodes`.
