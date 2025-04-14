#!/bin/bash

# Exit on error
set -e

echo "Building Docker image..."
docker build -t logging-app:latest ./app

echo "Applying Kubernetes configurations..."
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/daemonset.yaml
kubectl apply -f k8s/cronjob.yaml

echo "Waiting for deployment to be ready..."
kubectl rollout status deployment/logging-app

echo "Setting up port forwarding..."
kubectl port-forward service/logging-app-service 8080:80 &

echo "Deployment complete! The application is accessible at http://localhost:8080"
echo "To test the application, try:"
echo "  curl http://localhost:8080"
echo "  curl http://localhost:8080/status"
echo "  curl -X POST http://localhost:8080/log -d '{\"message\": \"test log\"}'"
echo "  curl http://localhost:8080/logs"

echo -e "\nTo verify CronJob operation:"
echo "1. Check CronJob status:"
echo "   kubectl get cronjobs"
echo "2. Check Jobs created by CronJob:"
echo "   kubectl get jobs"
echo "3. Check logs of the latest Job:"
echo "   kubectl logs \$(kubectl get jobs --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')"
echo "4. List archived logs:"
echo "   kubectl exec \$(kubectl get pods -l job-name=\$(kubectl get jobs --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}') -o jsonpath='{.items[0].metadata.name}') -- ls -l /archive" 