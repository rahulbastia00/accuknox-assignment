#!/usr/bin/env bash
set -uo pipefail

CLUSTER_NAME="wisecow-cluster"

echo "=================================================="
echo "🛑 [1/4] Deleting Kubernetes application resources..."
echo "=================================================="
kubectl delete -f k8s/ingress.yaml --ignore-not-found || true
kubectl delete -f k8s/service.yaml --ignore-not-found || true
kubectl delete -f k8s/deployment.yaml --ignore-not-found || true
kubectl delete secret wisecow-tls-secret --ignore-not-found || true
if [ -f k8s/security/kubearmor-policy.yaml ]; then
  kubectl delete -f k8s/security/kubearmor-policy.yaml --ignore-not-found || true
fi

echo "=================================================="
echo "💣 [2/4] Destroying Kind cluster '${CLUSTER_NAME}'..."
echo "=================================================="
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  kind delete cluster --name "${CLUSTER_NAME}"
  echo "Kind cluster deleted."
else
  echo "Cluster '${CLUSTER_NAME}' not found."
fi

echo "=================================================="
echo "🧹 [3/4] Cleaning /etc/hosts entry..."
echo "=================================================="
if grep -q "wisecow.local" /etc/hosts; then
  sudo sed -i '/wisecow.local/d' /etc/hosts
  echo "Removed wisecow.local from /etc/hosts."
fi

echo "=================================================="
echo "🗑️  [4/4] Removing temporary files..."
echo "=================================================="
rm -f /tmp/kind-config.yaml /tmp/tls.key /tmp/tls.crt /tmp/key.pem /tmp/cert.pem /tmp/system_health.log

echo "=================================================="
echo "✨ All resources completely destroyed and cleaned up!"
echo "=================================================="
