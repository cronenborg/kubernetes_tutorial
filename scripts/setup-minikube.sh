#!/bin/bash

# Minikube Setup Script for Fastify CRUD API
# This script automates the deployment of the application to local Minikube

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="${IMAGE_NAME:-fastify-crud-api}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
K8S_NAMESPACE="${K8S_NAMESPACE:-default}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Minikube Setup Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command_exists minikube; then
    echo -e "${RED}✗ Minikube is not installed${NC}"
    echo "Install from: https://minikube.sigs.k8s.io/docs/start/"
    exit 1
fi

if ! command_exists kubectl; then
    echo -e "${RED}✗ kubectl is not installed${NC}"
    echo "Install from: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

if ! command_exists docker; then
    echo -e "${RED}✗ Docker is not installed${NC}"
    echo "Install from: https://docs.docker.com/get-docker/"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites are installed${NC}"
echo ""

# Check if Minikube is running
echo -e "${YELLOW}Checking Minikube status...${NC}"
if ! minikube status >/dev/null 2>&1; then
    echo -e "${YELLOW}Minikube is not running. Starting Minikube...${NC}"
    minikube start
    echo -e "${GREEN}✓ Minikube started successfully${NC}"
else
    echo -e "${GREEN}✓ Minikube is already running${NC}"
fi
echo ""

# Configure Docker to use Minikube's Docker daemon
echo -e "${YELLOW}Configuring Docker to use Minikube's daemon...${NC}"
eval $(minikube docker-env)
echo -e "${GREEN}✓ Docker configured to use Minikube's daemon${NC}"
echo ""

# Build Docker image
echo -e "${YELLOW}Building Docker image: ${IMAGE_NAME}:${IMAGE_TAG}${NC}"
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
echo -e "${GREEN}✓ Docker image built successfully${NC}"
echo ""

# Create namespace if it doesn't exist and it's not default
if [ "$K8S_NAMESPACE" != "default" ]; then
    echo -e "${YELLOW}Checking namespace: ${K8S_NAMESPACE}${NC}"
    if ! kubectl get namespace ${K8S_NAMESPACE} >/dev/null 2>&1; then
        echo -e "${YELLOW}Creating namespace: ${K8S_NAMESPACE}${NC}"
        kubectl create namespace ${K8S_NAMESPACE}
        echo -e "${GREEN}✓ Namespace created${NC}"
    else
        echo -e "${GREEN}✓ Namespace already exists${NC}"
    fi
    echo ""
fi

# Deploy to Kubernetes
echo -e "${YELLOW}Deploying to Minikube...${NC}"
if [ "$K8S_NAMESPACE" != "default" ]; then
    kubectl apply -f k8s/local/ -n ${K8S_NAMESPACE}
else
    kubectl apply -f k8s/local/
fi
echo -e "${GREEN}✓ Application deployed successfully${NC}"
echo ""

# Wait for deployment to be ready
echo -e "${YELLOW}Waiting for deployment to be ready...${NC}"
if [ "$K8S_NAMESPACE" != "default" ]; then
    kubectl wait --for=condition=available --timeout=120s deployment/fastify-crud-api -n ${K8S_NAMESPACE}
else
    kubectl wait --for=condition=available --timeout=120s deployment/fastify-crud-api
fi
echo -e "${GREEN}✓ Deployment is ready${NC}"
echo ""

# Display deployment information
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

if [ "$K8S_NAMESPACE" != "default" ]; then
    echo -e "${YELLOW}Pods:${NC}"
    kubectl get pods -n ${K8S_NAMESPACE} -l app=fastify-crud-api
    echo ""
    echo -e "${YELLOW}Services:${NC}"
    kubectl get services -n ${K8S_NAMESPACE} -l app=fastify-crud-api
else
    echo -e "${YELLOW}Pods:${NC}"
    kubectl get pods -l app=fastify-crud-api
    echo ""
    echo -e "${YELLOW}Services:${NC}"
    kubectl get services -l app=fastify-crud-api
fi
echo ""

# Get service URL
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Access Your Application${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Option 1: Using Minikube service${NC}"
echo "Run the following command to get the service URL:"
if [ "$K8S_NAMESPACE" != "default" ]; then
    echo -e "${GREEN}minikube service fastify-crud-api -n ${K8S_NAMESPACE} --url${NC}"
else
    echo -e "${GREEN}minikube service fastify-crud-api --url${NC}"
fi
echo ""
echo -e "${YELLOW}Option 2: Using port forwarding${NC}"
echo "Run the following command to forward port 3000:"
if [ "$K8S_NAMESPACE" != "default" ]; then
    echo -e "${GREEN}kubectl port-forward service/fastify-crud-api 3000:80 -n ${K8S_NAMESPACE}${NC}"
else
    echo -e "${GREEN}kubectl port-forward service/fastify-crud-api 3000:80${NC}"
fi
echo "Then access: http://localhost:3000"
echo ""

# Test endpoints
echo -e "${YELLOW}Test your API with:${NC}"
echo "curl http://localhost:3000/health"
echo "curl -X POST http://localhost:3000/items -H 'Content-Type: application/json' -d '{\"name\":\"Test Item\"}'"
echo "curl http://localhost:3000/items"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
