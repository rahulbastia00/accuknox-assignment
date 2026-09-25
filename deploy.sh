#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="wisecow-cluster"

echo "=================================================="
echo "🚀 [1/8] Checking dependencies & installing Kind if needed..."
echo "=================================================="
if ! command -v kind &> /dev/null; then
  echo "Installing Kind..."
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
  chmod +x ./kind
  sudo mv ./kind /usr/local/bin/kind
fi

echo "=================================================="
echo "📦 [2/8] Creating Kind cluster with ingress port mappings..."
echo "=================================================="
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "Cluster '${CLUSTER_NAME}' already exists. Skipping creation."
else
  cat <<KIND_CONFIG > /tmp/kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
KIND_CONFIG

  kind create cluster --config /tmp/kind-config.yaml --name "${CLUSTER_NAME}"
fi

echo "=================================================="
echo "🌐 [3/8] Deploying and unblocking Ingress Controller..."
echo "=================================================="
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/kind/deploy.yaml

# Preload controller image directly into containerd to avoid digest pull failures
docker pull registry.k8s.io/ingress-nginx/controller:v1.10.0
docker save registry.k8s.io/ingress-nginx/controller:v1.10.0 | docker exec -i "${CLUSTER_NAME}-control-plane" ctr --namespace=k8s.io images import -

# Generate dummy admission secret to satisfy controller pod mount
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout /tmp/key.pem -out /tmp/cert.pem -days 365 \
  -subj "/CN=ingress-nginx-admission" > /dev/null 2>&1

kubectl create secret generic ingress-nginx-admission -n ingress-nginx \
  --from-file=cert=/tmp/cert.pem \
  --from-file=key=/tmp/key.pem \
  --dry-run=client -o yaml | kubectl apply -f -

# Clean up admission jobs and patch image to local offline tag
kubectl delete job -n ingress-nginx --all --ignore-not-found
kubectl delete validatingwebhookconfiguration ingress-nginx-admission --ignore-not-found
kubectl patch deployment ingress-nginx-controller -n ingress-nginx --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/image", "value": "registry.k8s.io/ingress-nginx/controller:v1.10.0"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/imagePullPolicy", "value": "Never"}
]'

echo "Waiting for Ingress controller to become ready..."
kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx --timeout=150s

echo "=================================================="
echo "🐳 [4/8] Building & injecting Wisecow container image..."
echo "=================================================="
docker build -t wisecow:latest .
docker save wisecow:latest | docker exec -i "${CLUSTER_NAME}-control-plane" ctr --namespace=k8s.io images import -

echo "=================================================="
echo "🔐 [5/8] Generating self-signed TLS certificates..."
echo "=================================================="
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/tls.key -out /tmp/tls.crt \
  -subj "/CN=wisecow.local/O=wisecow" > /dev/null 2>&1

kubectl create secret tls wisecow-tls-secret \
  --cert=/tmp/tls.crt \
  --key=/tmp/tls.key \
  --dry-run=client -o yaml | kubectl apply -f -

echo "=================================================="
echo "🚀 [6/8] Applying Kubernetes manifests..."
echo "=================================================="
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
if [ -f k8s/security/kubearmor-policy.yaml ]; then
  kubectl apply -f k8s/security/kubearmor-policy.yaml || true
fi

echo "Waiting for Wisecow deployment rollout..."
kubectl rollout status deployment/wisecow-deployment --timeout=120s

echo "=================================================="
echo "🧭 [7/8] Mapping DNS in /etc/hosts..."
echo "=================================================="
if ! grep -q "wisecow.local" /etc/hosts; then
  echo "127.0.0.1 wisecow.local" | sudo tee -a /etc/hosts > /dev/null
fi

echo "=================================================="
echo "✅ [8/8] Testing HTTPS URL & Printing Output..."
echo "=================================================="
sleep 3
echo "Sending GET request to https://wisecow.local :"
echo "--------------------------------------------------"
curl -k https://wisecow.local
echo "--------------------------------------------------"
echo "🎉 Wisecow application successfully deployed with TLS!"
