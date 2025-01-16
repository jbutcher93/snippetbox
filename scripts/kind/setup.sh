#!/bin/sh
set -o errexit

# 1. Create registry container unless it already exists
reg_name='kind-registry'
reg_port='5001'
if [ "$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)" != 'true' ]; then
  docker run \
    -d --restart=always -p "127.0.0.1:${reg_port}:5000" --network bridge --name "${reg_name}" \
    registry:2
fi

# 2. Create clusters with containerd registry config dir enabled

CLUSTERS=("config" "worker1" "worker2")

for cluster in ${CLUSTERS[@]}; do
{
cat <<EOF | kind create cluster --config=-
kind: Cluster
name: ${cluster}
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry]
    config_path = "/etc/containerd/certs.d"
EOF
} || true
done

kubectl create namespace argocd --context kind-config
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --context kind-config
kubectl apply -f kubernetes/apps/snippetbox.yaml --context kind-config

# 2b. Create argocd token and apply worker-rbac
kubectl apply -f kubernetes/config/worker-rbac.yaml --context kind-worker1
TOKEN=$(kubectl create token argocd --context kind-worker1)
sed "s/placeholder/${TOKEN}"/ kubernetes/config/worker1.yaml | kubectl apply --context kind-config -f -

kubectl apply -f kubernetes/config/worker-rbac.yaml --context kind-worker2
TOKEN=$(kubectl create token argocd --context kind-worker2)
sed "s/placeholder/${TOKEN}"/ kubernetes/config/worker2.yaml | kubectl apply --context kind-config -f -

# 3. Add the registry config to the nodes
#
# This is necessary because localhost resolves to loopback addresses that are
# network-namespace local.
# In other words: localhost in the container is not localhost on the host.
#
# We want a consistent name that works from both ends, so we tell containerd to
# alias localhost:${reg_port} to the registry container when pulling images
REGISTRY_DIR="/etc/containerd/certs.d/localhost:${reg_port}"
for node in $(kind get nodes --all-clusters); do
  docker exec "${node}" mkdir -p "${REGISTRY_DIR}"
  cat <<EOF | docker exec -i "${node}" cp /dev/stdin "${REGISTRY_DIR}/hosts.toml"
[host."http://${reg_name}:5000"]
EOF
done

# 4. Connect the registry to the cluster network if not already connected
# This allows kind to bootstrap the network but ensures they're on the same network
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${reg_name}")" = 'null' ]; then
  docker network connect "kind" "${reg_name}"
fi

# 5. Document the local registry
# https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
for cluster in $(kind get clusters); do
  cat <<EOF | kubectl apply --context kind-${cluster} -f -
  apiVersion: v1
  kind: ConfigMap
  metadata:
    name: local-registry-hosting
    namespace: kube-public
  data:
    localRegistryHosting.v1: |
      host: "localhost:${reg_port}"
      help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

# delete() {
#   CLUSTERS=$(kind get clusters)
#   for cluster in ${CLUSTERS[@]}; do 
#     kind delete cluster --name $cluster
#   done
# }