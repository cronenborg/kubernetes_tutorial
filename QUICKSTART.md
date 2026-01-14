# Quick Start Guide

This guide will get you up and running with the Fastify CRUD API on Kubernetes in minutes.

## Prerequisites Check

Before starting, ensure you have the required tools:

```bash
# Check all tools at once
make check-tools

# Or manually check each:
aws --version
eksctl version
kubectl version --client
docker --version
node --version
```

## Option 1: Automated Deployment to AWS EKS (Recommended)

### Step 1: Clone and Setup

```bash
git clone <your-repo-url>
cd fastify-k8s-tutorial
npm install
```

### Step 2: Configure AWS

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter your default region (e.g., us-east-1)
```

### Step 3: One-Command Deployment

```bash
# This single command does everything:
# - Creates EKS cluster (if doesn't exist)
# - Creates ECR repository
# - Builds and pushes Docker image
# - Deploys to Kubernetes
# - Sets up namespace

make full-deploy-eks
```

Wait ~15-20 minutes for cluster creation (first time only). Subsequent deployments take ~2 minutes.

### Step 4: Test Your API

```bash
# Get the LoadBalancer URL
kubectl get service fastify-crud-api -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Test the health endpoint (replace <URL> with the LoadBalancer URL)
curl http://<URL>/health

# Create an item
curl -X POST http://<URL>/items \
  -H "Content-Type: application/json" \
  -d '{"name":"My First Item","description":"Created on K8s!"}'

# Get all items
curl http://<URL>/items
```

## Option 2: Local Development with Minikube

Perfect for testing locally before deploying to AWS.

### Step 1: Prerequisites

Ensure you have the required tools installed:

```bash
# Check if tools are installed
minikube version
kubectl version --client
docker --version

# Or use the Makefile to check all tools
make check-tools
```

### Step 2: One-Command Setup (Recommended)

```bash
# This single command does everything:
# - Starts Minikube (if not running)
# - Configures Docker to use Minikube's daemon
# - Builds the Docker image
# - Deploys to Kubernetes
# - Waits for deployment to be ready

make minikube-setup

# Or use the script directly
./scripts/setup-minikube.sh
```

Wait ~2-3 minutes for the deployment to complete.

### Step 3: Access Your Application

```bash
# Get the service URL
make minikube-url

# Or use port forwarding
kubectl port-forward service/fastify-crud-api 3000:80
```

### Step 4: Test Locally

```bash
curl http://localhost:3000/health
curl -X POST http://localhost:3000/items -H "Content-Type: application/json" -d '{"name":"Local Item"}'
curl http://localhost:3000/items
```

### Alternative: Manual Step-by-Step Setup

If you prefer to run each step manually:

```bash
# 1. Start Minikube
minikube start

# 2. Configure Docker to use Minikube's daemon
eval $(minikube docker-env)

# 3. Build the Docker image
docker build -t fastify-crud-api:latest .

# 4. Deploy to Kubernetes
kubectl apply -f k8s/local/

# 5. Wait for deployment
kubectl wait --for=condition=available --timeout=120s deployment/fastify-crud-api

# 6. Access the application
minikube service fastify-crud-api --url
```

## Option 3: Using GitHub Actions (CI/CD)

### Step 1: Fork/Clone Repository to GitHub

### Step 2: Add GitHub Secrets

Go to: Settings → Secrets and variables → Actions → New repository secret

Add these secrets:
- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
- `AWS_REGION`: e.g., `us-east-1`
- `EKS_CLUSTER_NAME`: e.g., `fastify-crud-cluster`
- `ECR_REPOSITORY`: e.g., `fastify-crud-api`

### Step 3: Push Code

```bash
git add .
git commit -m "Initial commit"
git push origin main
```

GitHub Actions will automatically:
1. ✅ Check if cluster exists, create if needed
2. ✅ Build Docker image
3. ✅ Push to ECR
4. ✅ Deploy to EKS

### Step 4: Monitor Deployment

Go to: Actions tab in GitHub → Watch the workflow run

## Common Commands

### Check Status

```bash
# View all resources
kubectl get all

# Check pods
kubectl get pods

# View logs
kubectl logs -l app=fastify-crud-api --tail=50

# Describe pod (for troubleshooting)
kubectl describe pod <pod-name>
```

### Update Your Application

```bash
# After making code changes:

# For EKS:
make ecr-push              # Build and push new image
make k8s-deploy-eks        # Deploy updated image

# For Minikube:
make minikube-setup        # Full automated setup
make minikube-deploy       # Build and deploy (manual)
```

### Cleanup

```bash
# Delete Kubernetes resources only (keeps cluster)
make k8s-delete

# Delete entire EKS cluster
make eks-delete

# Stop Minikube
minikube stop

# Delete Minikube
minikube delete
```

## Environment Variables

You can customize the deployment with environment variables:

```bash
# EKS configuration
export EKS_CLUSTER_NAME=my-cluster
export AWS_REGION=eu-west-1
export ECR_REPOSITORY=my-app
export K8S_NAMESPACE=production
export NODE_TYPE=t3.large
export NODES=3

# Then run
make full-deploy-eks
```

## Troubleshooting

### Issue: Cluster creation fails

```bash
# Check AWS credentials
aws sts get-caller-identity

# Check IAM permissions - you need permissions for:
# - EKS (create cluster, describe cluster)
# - EC2 (create VPC, security groups, instances)
# - CloudFormation (create stacks)
# - IAM (create service roles)
```

### Issue: Pods not starting

```bash
# Check pod status
kubectl get pods

# View pod logs
kubectl logs <pod-name>

# Describe pod for events
kubectl describe pod <pod-name>

# Common fixes:
# 1. Image pull errors: Check ECR permissions
# 2. Crash loop: Check application logs
# 3. Pending: Check node resources
```

### Issue: Cannot connect to LoadBalancer

```bash
# Check service
kubectl get service fastify-crud-api

# LoadBalancer takes 2-3 minutes to provision
# Wait and check again

# Verify security groups allow traffic on port 80
```

### Issue: kubectl not connected to cluster

```bash
# Update kubeconfig
aws eks update-kubeconfig --name fastify-crud-cluster --region us-east-1

# Verify connection
kubectl cluster-info
```

## Next Steps

1. ✅ Application is running on Kubernetes!
2. Add a database (PostgreSQL/MongoDB)
3. Set up monitoring (Prometheus/Grafana)
4. Add Ingress controller for custom domains
5. Implement autoscaling
6. Add CI/CD tests

## Cost Considerations

**AWS EKS Costs (approximate monthly):**
- EKS Cluster: $72/month (~$0.10/hour)
- EC2 Nodes (2x t3.medium): ~$60/month
- Data transfer: Variable
- **Total: ~$132/month**

**To minimize costs:**
- Delete cluster when not in use: `make eks-delete`
- Use smaller instance types for testing
- Set up auto-scaling to scale down during low usage

## Support

If you encounter issues:
1. Check the main README.md for detailed documentation
2. Review kubectl logs: `make k8s-logs`
3. Check GitHub Actions logs if using CI/CD
4. Verify all prerequisites are installed: `make check-tools`