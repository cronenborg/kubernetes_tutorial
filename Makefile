# Makefile for Kubernetes Tutorial Project

# Variables
CLUSTER_NAME ?= fastify-crud-cluster
AWS_REGION ?= us-east-1
ECR_REPOSITORY ?= fastify-crud-api
K8S_NAMESPACE ?= default
IMAGE_NAME ?= fastify-crud-api
IMAGE_TAG ?= latest

# Colors for output
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
RESET  := $(shell tput -Txterm sgr0)

.PHONY: help
help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  ${GREEN}%-20s${RESET} %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: install
install: ## Install dependencies
	@echo "${GREEN}Installing dependencies...${RESET}"
	npm install

.PHONY: dev
dev: ## Run application in development mode
	@echo "${GREEN}Starting development server...${RESET}"
	npm run dev

.PHONY: docker-build
docker-build: ## Build Docker image locally
	@echo "${GREEN}Building Docker image...${RESET}"
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

.PHONY: docker-run
docker-run: ## Run Docker container locally
	@echo "${GREEN}Running Docker container...${RESET}"
	docker run -p 3000:3000 $(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: check-tools
check-tools: ## Check if required tools are installed
	@echo "${GREEN}Checking required tools...${RESET}"
	@command -v aws >/dev/null 2>&1 || { echo "${YELLOW}AWS CLI not found. Install from: https://aws.amazon.com/cli/${RESET}"; exit 1; }
	@command -v eksctl >/dev/null 2>&1 || { echo "${YELLOW}eksctl not found. Install from: https://eksctl.io/${RESET}"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "${YELLOW}kubectl not found. Install from: https://kubernetes.io/docs/tasks/tools/${RESET}"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "${YELLOW}docker not found. Install from: https://docs.docker.com/get-docker/${RESET}"; exit 1; }
	@echo "${GREEN}✓ All required tools are installed${RESET}"

.PHONY: eks-setup
eks-setup: check-tools ## Setup EKS cluster (create if not exists)
	@echo "${GREEN}Setting up EKS cluster...${RESET}"
	@chmod +x scripts/setup-eks.sh
	EKS_CLUSTER_NAME=$(CLUSTER_NAME) \
	AWS_REGION=$(AWS_REGION) \
	ECR_REPOSITORY=$(ECR_REPOSITORY) \
	K8S_NAMESPACE=$(K8S_NAMESPACE) \
	./scripts/setup-eks.sh

.PHONY: eks-check
eks-check: ## Check if EKS cluster exists
	@echo "${GREEN}Checking EKS cluster...${RESET}"
	@aws eks describe-cluster --name $(CLUSTER_NAME) --region $(AWS_REGION) >/dev/null 2>&1 && \
		echo "${GREEN}✓ Cluster $(CLUSTER_NAME) exists${RESET}" || \
		echo "${YELLOW}✗ Cluster $(CLUSTER_NAME) does not exist${RESET}"

.PHONY: eks-delete
eks-delete: ## Delete EKS cluster
	@echo "${YELLOW}Deleting EKS cluster $(CLUSTER_NAME)...${RESET}"
	@read -p "Are you sure? This will delete all resources [y/N]: " confirm && \
		[ "$$confirm" = "y" ] || exit 1
	eksctl delete cluster --name $(CLUSTER_NAME) --region $(AWS_REGION)

.PHONY: ecr-login
ecr-login: ## Login to Amazon ECR
	@echo "${GREEN}Logging in to Amazon ECR...${RESET}"
	aws ecr get-login-password --region $(AWS_REGION) | \
		docker login --username AWS --password-stdin \
		$$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$(AWS_REGION).amazonaws.com

.PHONY: ecr-push
ecr-push: docker-build ecr-login ## Build and push image to ECR
	@echo "${GREEN}Pushing image to ECR...${RESET}"
	$(eval ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text))
	$(eval ECR_URI := $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPOSITORY))
	docker tag $(IMAGE_NAME):$(IMAGE_TAG) $(ECR_URI):$(IMAGE_TAG)
	docker push $(ECR_URI):$(IMAGE_TAG)

.PHONY: k8s-deploy-local
k8s-deploy-local: ## Deploy to local Minikube
	@echo "${GREEN}Deploying to Minikube...${RESET}"
	kubectl apply -f k8s/local/

.PHONY: k8s-deploy-eks
k8s-deploy-eks: ## Deploy to EKS
	@echo "${GREEN}Deploying to EKS...${RESET}"
	$(eval ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text))
	$(eval ECR_URI := $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPOSITORY):$(IMAGE_TAG))
	@sed "s|<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/fastify-crud-api:latest|$(ECR_URI)|g" k8s/eks/deployment.yaml | kubectl apply -f -
	kubectl apply -f k8s/eks/service.yaml

.PHONY: k8s-status
k8s-status: ## Show Kubernetes deployment status
	@echo "${GREEN}Deployment status:${RESET}"
	kubectl get deployments
	@echo ""
	@echo "${GREEN}Pods:${RESET}"
	kubectl get pods
	@echo ""
	@echo "${GREEN}Services:${RESET}"
	kubectl get services

.PHONY: k8s-logs
k8s-logs: ## Show logs from pods
	@echo "${GREEN}Fetching logs...${RESET}"
	kubectl logs -l app=$(IMAGE_NAME) --tail=100 -f

.PHONY: k8s-delete
k8s-delete: ## Delete Kubernetes resources
	@echo "${YELLOW}Deleting Kubernetes resources...${RESET}"
	kubectl delete -f k8s/eks/ 2>/dev/null || kubectl delete -f k8s/local/ 2>/dev/null || true

.PHONY: minikube-start
minikube-start: ## Start Minikube
	@echo "${GREEN}Starting Minikube...${RESET}"
	minikube start

.PHONY: minikube-build
minikube-build: ## Build Docker image in Minikube
	@echo "${GREEN}Building image in Minikube...${RESET}"
	eval $$(minikube docker-env) && docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

.PHONY: minikube-setup
minikube-setup: ## Full automated Minikube setup (start + build + deploy)
	@echo "${GREEN}Running automated Minikube setup...${RESET}"
	@chmod +x scripts/setup-minikube.sh
	IMAGE_NAME=$(IMAGE_NAME) \
	IMAGE_TAG=$(IMAGE_TAG) \
	K8S_NAMESPACE=$(K8S_NAMESPACE) \
	./scripts/setup-minikube.sh

.PHONY: minikube-deploy
minikube-deploy: minikube-build k8s-deploy-local ## Build and deploy to Minikube
	@echo "${GREEN}✓ Deployed to Minikube${RESET}"

.PHONY: minikube-url
minikube-url: ## Get Minikube service URL
	@echo "${GREEN}Service URL:${RESET}"
	minikube service $(IMAGE_NAME) --url

.PHONY: full-deploy-eks
full-deploy-eks: eks-setup ecr-push k8s-deploy-eks ## Full EKS deployment (setup + push + deploy)
	@echo "${GREEN}✓ Full deployment completed${RESET}"
	@echo ""
	@echo "${GREEN}Getting service URL...${RESET}"
	@sleep 10
	@kubectl get service $(IMAGE_NAME) -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || echo "LoadBalancer provisioning..."

.PHONY: test-api
test-api: ## Test API endpoints (requires PORT env var or uses :3000)
	@echo "${GREEN}Testing API endpoints...${RESET}"
	$(eval API_URL := $(or $(PORT),http://localhost:3000))
	@echo "Testing health endpoint..."
	curl -s $(API_URL)/health | jq .
	@echo "\nCreating item..."
	curl -s -X POST $(API_URL)/items -H "Content-Type: application/json" -d '{"name":"Test Item","description":"Created by test"}' | jq .
	@echo "\nGetting all items..."
	curl -s $(API_URL)/items | jq .

.PHONY: clean
clean: ## Clean up local Docker images and containers
	@echo "${YELLOW}Cleaning up...${RESET}"
	docker rmi $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
	docker system prune -f