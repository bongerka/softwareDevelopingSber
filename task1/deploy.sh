#!/bin/bash

set -e

echo "Installing Istio in the cluster..."
istioctl install --set profile=demo -y

echo "Enabling Istio injection for the default namespace..."
kubectl label namespace default istio-injection=enabled --overwrite

echo "Installing Prometheus stack..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false

echo "Building Docker image"
docker build -t logging-app:latest ./app

echo "Applying Kubernetes configurations"
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/daemonset.yaml
kubectl apply -f k8s/cronjob.yaml
kubectl apply -f k8s/prometheus-servicemonitor.yaml

echo "Applying Istio configurations"
kubectl apply -f k8s/istio/gateway.yaml
kubectl apply -f k8s/istio/virtualservice.yaml
kubectl apply -f k8s/istio/destinationrule.yaml

kubectl rollout status deployment/logging-app

kubectl get gateway logging-gateway
kubectl get virtualservice logging-vs
kubectl get destinationrule logging-dr

echo "Getting Istio Ingress Gateway IP"
export INGRESS_IP=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$INGRESS_IP" ]; then
    echo "Warning: Could not get Ingress IP"
else
    echo "Deployment complete. The application is accessible at http://$INGRESS_IP"
    echo "Prometheus is available at http://$INGRESS_IP:9090"
fi