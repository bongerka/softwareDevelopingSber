#!/bin/bash

set -e

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    exit 1
fi

# Install Istio if not already installed
if ! command -v istioctl &> /dev/null; then
    echo "Installing Istio..."
    curl -L https://istio.io/downloadIstio | sh -
    export PATH=$PWD/istio-1.20.0/bin:$PATH
fi

# Verify Istio version
ISTIO_VERSION=$(istioctl version --short)
echo "Using Istio version: $ISTIO_VERSION"

# Install Istio in the cluster
echo "Installing Istio in the cluster..."
istioctl install --set profile=demo -y

# Enable Istio injection for the default namespace
echo "Enabling Istio injection for the default namespace..."
kubectl label namespace default istio-injection=enabled --overwrite

echo "Building Docker image"
docker build -t logging-app:latest ./app

echo "Applying Kubernetes configurations"
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/daemonset.yaml
kubectl apply -f k8s/cronjob.yaml

echo "Applying Istio configurations"
kubectl apply -f k8s/istio/gateway.yaml
kubectl apply -f k8s/istio/virtualservice.yaml
kubectl apply -f k8s/istio/destinationrule.yaml

echo "Waiting for deployment to be ready"
kubectl rollout status deployment/logging-app

echo "Verifying Istio Gateway"
kubectl get gateway logging-gateway
kubectl get virtualservice logging-vs
kubectl get destinationrule logging-dr

echo "Getting Istio Ingress Gateway IP"
export INGRESS_IP=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$INGRESS_IP" ]; then
    echo "Warning: Could not get Ingress IP. If you're using minikube, you might need to run: minikube tunnel"
    echo "You can also try: kubectl -n istio-system get service istio-ingressgateway"
else
    echo "Deployment complete. The application is accessible at http://$INGRESS_IP"
fi