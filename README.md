# Kubernetes Tutorial - Fastify CRUD API

A minimal Node.js repository demonstrating how to build, dockerize, and deploy a Fastify CRUD API to Kubernetes (Minikube locally and AWS EKS for dev environment).

## Repository Structure

```
.
├── src/
│   ├── index.js              # Main application entry point
│   ├── routes/               # API routes
│   │   └── items.js          # CRUD endpoints for items
│   └── db.js                 # In-memory database (for demo)
├── k8s/
│   ├── local/                # Minikube deployment
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── eks/                  # AWS EKS deployment
│       ├── deployment.yaml
│       └── service.yaml
├── .github/
│   └── workflows/
│       ├── build.yaml        # Build and push Docker image
│       └── deploy-eks.yaml   # Deploy to EKS
├── Dockerfile
├── .dockerignore
├── package.json
└── README.md
```

## Prerequisites

### Local Development (Minikube)
- [Docker](https://docs.docker.com/get-docker/)
- [Minikube](https://minikube.sigs.k8s.io/docs/start/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- Node.js 18+

### AWS EKS Deployment
- AWS CLI configured (`aws configure`)
- [eksctl](https://eksctl.io/) - EKS cluster management tool
- kubectl configured for EKS
- GitHub repository secrets configured (see below)

**Note:** The repository now includes automation to create EKS clusters and namespaces if they don't exist!

## Local Development

### 1. Run Locally (without Docker)

```bash
npm install
npm run dev
```

Test the API:
```bash
curl http://localhost:3000/health
curl -X POST http://localhost:3000/items -H "Content-Type: application/json" -d '{"name":"test"}'
curl http://localhost:3000/items
```

### 2. Build Docker Image

```bash
docker build -t fastify-crud-api:latest .
```

### 3. Run with Docker

```bash
docker run -p 3000:3000 fastify-crud-api:latest
```

## Minikube Deployment

### Quick Start (Automated Setup)

The easiest way to deploy to Minikube is using the provided setup script or Makefile:

```bash
# Using the setup script
./scripts/setup-minikube.sh

# Or using Make
make minikube-setup
```

This will automatically:
- ✅ Check if Minikube is running, start it if not
- ✅ Configure Docker to use Minikube's daemon
- ✅ Build the Docker image
- ✅ Deploy to Kubernetes
- ✅ Wait for deployment to be ready
- ✅ Display access instructions

### Manual Setup (Step by Step)

### 1. Start Minikube

```bash
minikube start
```

### 2. Build Image in Minikube

```bash
# Use Minikube's Docker daemon
eval $(minikube docker-env)

# Build the image
docker build -t fastify-crud-api:latest .
```

### 3. Deploy to Minikube

```bash
kubectl apply -f k8s/local/
```

### 4. Access the Application

```bash
# Get the service URL
minikube service fastify-crud-api --url

# Or use port forwarding
kubectl port-forward service/fastify-crud-api 3000:80
```

### 5. Test the API

```bash
# Health check
curl http://localhost:3000/health

# Create item
curl -X POST http://localhost:3000/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Kubernetes Item"}'

# Get all items
curl http://localhost:3000/items

# Get specific item
curl http://localhost:3000/items/1

# Update item
curl -X PUT http://localhost:3000/items/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"Updated Item"}'

# Delete item
curl -X DELETE http://localhost:3000/items/1
```

## AWS EKS Deployment

### Quick Start (Automated Setup)

The easiest way to deploy to EKS is using the provided setup script or Makefile:

```bash
# Using the setup script
./scripts/setup-eks.sh

# Or using Make
make eks-setup
```

This will automatically:
- ✅ Check if the EKS cluster exists, create it if not
- ✅ Create the ECR repository if needed
- ✅ Create the Kubernetes namespace if specified
- ✅ Configure kubectl to connect to the cluster

### Manual Setup (Step by Step)

### 1. Create EKS Cluster (Automated)

The cluster will be created automatically by the setup script or GitHub Actions if it doesn't exist. You can also create it manually:

```bash
# Check if cluster exists
aws eks describe-cluster --name fastify-crud-cluster --region us-east-1

# If it doesn't exist, the script will create it, or you can run:
eksctl create cluster \
  --name fastify-crud-cluster \
  --region us-east-1 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3
```

**Note:** Cluster creation takes approximately 15-20 minutes.

### 2. Configure GitHub Secrets

Add these secrets to your GitHub repository (Settings → Secrets → Actions):

- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
- `AWS_REGION`: e.g., `us-east-1`
- `EKS_CLUSTER_NAME`: Your cluster name
- `ECR_REPOSITORY`: Your ECR repository name
- `DOCKERHUB_USERNAME`: (Optional) For Docker Hub
- `DOCKERHUB_TOKEN`: (Optional) For Docker Hub

### 3. Push to ECR

The ECR repository is automatically created by the setup script. To push manually:

```bash
# The ECR repository is created automatically, but you can create it manually:
aws ecr create-repository --repository-name fastify-crud-api --region us-east-1

# Tag and push
docker tag fastify-crud-api:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/fastify-crud-api:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/fastify-crud-api:latest
```

### 4. Deploy to EKS

```bash
# Update kubeconfig
aws eks update-kubeconfig --name fastify-crud-cluster --region us-east-1

# Apply manifests
kubectl apply -f k8s/eks/

# Check deployment
kubectl get pods
kubectl get services
```

### 5. Access the Application

```bash
# Get the LoadBalancer URL
kubectl get service fastify-crud-api -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Test
curl http://<load-balancer-url>/health
```

## GitHub Actions CI/CD

This repository includes two workflows that automatically handle cluster creation:

### 1. Build Workflow (`build.yaml`)
- Triggers on push to `main` and pull requests
- Builds Docker image
- Pushes to Docker Hub or ECR
- **Automatically creates ECR repository if it doesn't exist**

### 2. Deploy to EKS Workflow (`deploy-eks.yaml`)
- Triggers manually or on push to `main` with tag
- **Automatically checks if EKS cluster exists**
- **Creates the cluster if it doesn't exist** (takes ~15-20 minutes)
- **Creates namespace if specified and doesn't exist**
- **Creates ECR repository if needed**
- Deploys the latest image to EKS
- Updates Kubernetes deployment

The GitHub Actions workflow will handle all infrastructure provisioning automatically!

## Using the Makefile

A comprehensive Makefile is included for easy management:

```bash
# Show all available commands
make help

# Check if required tools are installed
make check-tools

# Full EKS setup (create cluster + ECR + namespace)
make eks-setup

# Check if EKS cluster exists
make eks-check

# Build and push to ECR
make ecr-push

# Full deployment to EKS (setup + build + push + deploy)
make full-deploy-eks

# Deploy to existing EKS cluster
make k8s-deploy-eks

# Check deployment status
make k8s-status

# View logs
make k8s-logs

# Minikube commands
make minikube-start
make minikube-setup      # Full automated setup
make minikube-deploy
make minikube-url

# Clean up
make k8s-delete        # Delete K8s resources
make eks-delete        # Delete entire EKS cluster
make clean             # Clean local Docker images
```

## Useful Commands

### Kubectl Commands

```bash
# Get all resources
kubectl get all

# Describe pod
kubectl describe pod <pod-name>

# View logs
kubectl logs <pod-name>

# Execute command in pod
kubectl exec -it <pod-name> -- /bin/sh

# Delete deployment
kubectl delete -f k8s/local/
```

### Minikube Commands

```bash
# Stop Minikube
minikube stop

# Delete Minikube cluster
minikube delete

# View Minikube dashboard
minikube dashboard
```

### EKS Commands

```bash
# List clusters
eksctl get cluster

# Delete cluster
eksctl delete cluster --name fastify-crud-cluster --region us-east-1

# Scale deployment
kubectl scale deployment fastify-crud-api --replicas=3
```

## API Endpoints

- `GET /health` - Health check
- `GET /items` - Get all items
- `GET /items/:id` - Get item by ID
- `POST /items` - Create new item
- `PUT /items/:id` - Update item
- `DELETE /items/:id` - Delete item

## Environment Variables

- `PORT`: Server port (default: 3000)
- `NODE_ENV`: Environment (development/production)

## Next Steps

1. Add persistent storage (PostgreSQL/MongoDB)
2. Implement ConfigMaps and Secrets
3. Add Ingress controller
4. Implement horizontal pod autoscaling
5. Add monitoring (Prometheus/Grafana)
6. Implement health checks and readiness probes
7. Add Helm charts

## License

MIT