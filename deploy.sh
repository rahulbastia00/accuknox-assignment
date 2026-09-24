#!/usr/bin/env bash
set -euo pipefail

echo "==> 1. Starting Minikube cluster and enabling ingress..."
minikube start --driver=docker
minikube addons enable ingress

echo "==> 2. Installing cert-manager for TLS..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml

echo "==> Waiting for cert-manager components to be fully ready..."
kubectl wait --namespace cert-manager --for=condition=available deployment/cert-manager --timeout=180s
kubectl wait --namespace cert-manager --for=condition=available deployment/cert-manager-cainjector --timeout=180s
kubectl wait --namespace cert-manager --for=condition=available deployment/cert-manager-webhook --timeout=180s

echo "==> 3. Applying application manifests..."
kubectl apply -f k8s/cert-issuer.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml

echo "==> Waiting for wisecow deployment to finish rollout..."
kubectl rollout status deployment/wisecow-deployment --timeout=120s

echo "==> 4. Installing KubeArmor..."
helm repo add kubearmor https://kubearmor.github.io/charts
helm repo update
helm upgrade --install kubearmor-operator kubearmor/kubearmor-operator \
  --namespace kubearmor \
  --create-namespace

kubectl apply -f https://raw.githubusercontent.com/kubearmor/KubeArmor/main/pkg/KubeArmorOperator/config/samples/operator_v1_kubearmor.yaml

echo "==> Waiting for KubeArmor operator deployment..."
kubectl wait --namespace kubearmor --for=condition=available deployment/kubearmor-operator --timeout=180s

echo "==> Applying KubeArmor security policy..."
kubectl apply -f k8s/security/kubearmor-policy.yaml

echo "==> 5. Configuring local DNS mapping (/etc/hosts)..."
MINIKUBE_IP="$(minikube ip)"
HOST_ENTRY="${MINIKUBE_IP} wisecow.local"

if grep -q "wisecow.local" /etc/hosts; then
  sudo sed -i.bak "s/.*wisecow.local/${HOST_ENTRY}/" /etc/hosts
else
  echo "${HOST_ENTRY}" | sudo tee -a /etc/hosts > /dev/null
fi

echo "==> 6. Testing TLS connectivity..."
curl -k -v https://wisecow.local