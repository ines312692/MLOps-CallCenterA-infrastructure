# Complete Kubernetes & GitOps Setup Guide

This guide provides step-by-step instructions to set up the complete Kubernetes and GitOps infrastructure for the MLOps CallCenter AI project.

## Prerequisites

### Required Tools

- **kubectl** (v1.24+): Kubernetes command-line tool
- **helm** (v3.x): Kubernetes package manager
- **kustomize** (v4.x): Kubernetes configuration management
- **argocd CLI** (optional): ArgoCD command-line interface
- **docker**: Container runtime
- **git**: Version control

### Installation

#### macOS
```bash
# Install via Homebrew
brew install kubectl helm kustomize argocd git docker
```

#### Linux
```bash
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# kustomize
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo mv kustomize /usr/local/bin/

# argocd CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
```

#### Windows (via Chocolatey)
```powershell
choco install kubernetes-cli kubernetes-helm kustomize argocd-cli git docker-desktop
```

### Kubernetes Cluster

You need access to a Kubernetes cluster. Options:

1. **Local Development**:
   - Minikube
   - Kind
   - Docker Desktop

2. **Cloud Providers**:
   - GKE (Google Kubernetes Engine)
   - EKS (Amazon Elastic Kubernetes Service)
   - AKS (Azure Kubernetes Service)

3. **On-Premises**:
   - kubeadm
   - k3s
   - RKE

## Step 1: Cluster Setup

### Option A: Local Kubernetes (Minikube)

```bash
# Start Minikube with sufficient resources
minikube start --cpus=4 --memory=8192 --disk-size=50g

# Enable addons
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable storage-provisioner

# Verify cluster
kubectl cluster-info
kubectl get nodes
```

### Option B: Cloud Provider (GKE Example)

```bash
# Create GKE cluster
gcloud container clusters create callcenter-ai-cluster \
  --zone us-central1-a \
  --num-nodes 3 \
  --machine-type n1-standard-4 \
  --disk-size 50 \
  --enable-autoscaling \
  --min-nodes 3 \
  --max-nodes 10

# Get credentials
gcloud container clusters get-credentials callcenter-ai-cluster --zone us-central1-a

# Verify cluster
kubectl cluster-info
```

## Step 2: Install Core Components

### 2.1 Install NGINX Ingress Controller

```bash
# Install NGINX Ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Wait for LoadBalancer IP
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Get LoadBalancer IP
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

### 2.2 Install Cert-Manager (for TLS)

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=cert-manager \
  --timeout=120s

# Create ClusterIssuer for Let's Encrypt
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

### 2.3 Install Metrics Server (if not present)

```bash
# Install metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify
kubectl top nodes
```

## Step 3: Clone Repository

```bash
# Clone the repository
git clone https://github.com/your-org/MLOps-CallCenterAI.git
cd MLOps-CallCenterAI
```

## Step 4: Configure Secrets

### 4.1 Create Secrets File

Create a file `infrastructure/k8s/base/secrets-values.yaml`:

```yaml
groqApiKey: "your-actual-groq-api-key"
postgresPassword: "your-strong-postgres-password"
grafanaPassword: "your-strong-grafana-password"
```

### 4.2 Apply Secrets

```bash
# For development
kubectl create secret generic groq-api-key \
  --from-literal=GROQ_API_KEY=your-groq-api-key \
  --namespace callcenter-dev

kubectl create secret generic postgres-credentials \
  --from-literal=username=mlflow \
  --from-literal=password=your-postgres-password \
  --namespace callcenter-dev

kubectl create secret generic grafana-credentials \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=your-grafana-password \
  --namespace callcenter-dev
```

**Note**: In production, use External Secrets Operator or sealed-secrets!

## Step 5: Install ArgoCD

```bash
# Run the setup script
cd infrastructure/scripts
chmod +x setup-argocd.sh
./setup-argocd.sh

# Save the credentials shown in the output!
```

Alternative manual installation:

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080
```

## Step 6: Deploy Using GitOps (Recommended)

### 6.1 Apply ArgoCD Project

```bash
kubectl apply -f infrastructure/argocd/projects/callcenter-ai-project.yaml
```

### 6.2 Deploy Applications

```bash
# Deploy development environment
kubectl apply -f infrastructure/argocd/apps/callcenter-ai-dev.yaml

# Deploy production environment (manual sync)
kubectl apply -f infrastructure/argocd/apps/callcenter-ai-prod.yaml
```

### 6.3 Monitor Deployment

```bash
# Watch ArgoCD sync status
argocd app get callcenter-ai-dev --watch

# Or via UI
# Open ArgoCD UI and watch the sync progress
```

## Step 7: Deploy Using kubectl/kustomize (Alternative)

If not using GitOps:

```bash
# Deploy to development
cd infrastructure/scripts
chmod +x deploy.sh
./deploy.sh --environment dev

# Deploy to production
./deploy.sh --environment prod
```

Or manually:

```bash
# Create namespaces
kubectl apply -f infrastructure/k8s/namespaces/

# Deploy to development
kubectl apply -k infrastructure/k8s/overlays/dev

# Deploy to production
kubectl apply -k infrastructure/k8s/overlays/prod
```

## Step 8: Deploy Using Helm (Alternative)

```bash
# Install development
helm upgrade --install callcenter-ai ./infrastructure/helm/callcenter-ai \
  --namespace callcenter-dev \
  --create-namespace \
  --values ./infrastructure/helm/callcenter-ai/values-dev.yaml \
  --set agentService.secrets.groqApiKey=your-groq-api-key \
  --set postgresql.auth.password=your-postgres-password \
  --set grafana.adminPassword=your-grafana-password

# Install production
helm upgrade --install callcenter-ai ./infrastructure/helm/callcenter-ai \
  --namespace callcenter-prod \
  --create-namespace \
  --values ./infrastructure/helm/callcenter-ai/values-prod.yaml \
  --set agentService.secrets.groqApiKey=your-groq-api-key \
  --set postgresql.auth.password=your-postgres-password \
  --set grafana.adminPassword=your-grafana-password
```

## Step 9: Verify Deployment

### 9.1 Check Pod Status

```bash
# Development
kubectl get pods -n callcenter-dev

# Production
kubectl get pods -n callcenter-prod

# All should show Running and Ready
```

### 9.2 Check Services

```bash
kubectl get svc -n callcenter-dev
kubectl get svc -n callcenter-prod
```

### 9.3 Check Ingress

```bash
kubectl get ingress -n callcenter-dev
kubectl get ingress -n callcenter-prod
```

### 9.4 Test Endpoints

```bash
# Port forward to agent service
kubectl port-forward svc/agent-service 8000:8000 -n callcenter-dev

# Test health endpoint
curl http://localhost:8000/health

# Test prediction endpoint
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{"text": "My laptop is not connecting to WiFi", "ticket_id": "T12345"}'
```

## Step 10: Access Services

### Development Environment

```bash
# Port forward to access services locally
kubectl port-forward svc/agent-service 8000:8000 -n callcenter-dev &
kubectl port-forward svc/mlflow 5000:5000 -n callcenter-dev &
kubectl port-forward svc/prometheus 9090:9090 -n callcenter-dev &
kubectl port-forward svc/grafana 3000:3000 -n callcenter-dev &
```

Access:
- Agent API: http://localhost:8000
- MLflow: http://localhost:5000
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin/your-password)

### Production Environment

Access via domain names (after DNS configuration):
- API: https://api.callcenter-ai.com
- MLflow: https://mlflow.callcenter-ai.com
- Grafana: https://grafana.callcenter-ai.com

## Step 11: Configure DNS

Update your DNS records to point to the LoadBalancer IP:

```bash
# Get LoadBalancer IP
kubectl get ingress -n callcenter-prod

# Create DNS A records:
# api.callcenter-ai.com -> LoadBalancer IP
# mlflow.callcenter-ai.com -> LoadBalancer IP
# grafana.callcenter-ai.com -> LoadBalancer IP
```

## Step 12: Set Up Monitoring

### 12.1 Access Grafana

```bash
# Get Grafana password (if not set manually)
kubectl get secret grafana-credentials -n callcenter-dev \
  -o jsonpath="{.data.admin-password}" | base64 -d

# Access Grafana
# URL: http://localhost:3000 (via port-forward) or https://grafana.callcenter-ai.com
# Login: admin / your-password
```

### 12.2 Import Dashboards

Grafana dashboards are pre-configured. Verify:

1. Log in to Grafana
2. Go to Dashboards
3. Look for "CallCenter AI" folder
4. Open dashboards to view metrics

## Step 13: Configure CI/CD

### 13.1 GitHub Actions Secrets

Add these secrets to your GitHub repository:

- `DOCKER_USERNAME`: Your Docker registry username
- `DOCKER_PASSWORD`: Your Docker registry password/token
- `KUBECONFIG`: Your Kubernetes config (base64 encoded)
- `GROQ_API_KEY`: Your Groq API key

### 13.2 Update Workflows

Update image registry in workflows:
- `.github/workflows/ci-agent-service.yml`
- `.github/workflows/ci-tfidf-service.yml`
- `.github/workflows/ci-transformer-service.yml`

Replace `your-registry` with your actual registry URL.

## Step 14: Next Steps

1. **Configure External Secrets** (recommended for production)
2. **Set up backup strategy** for persistent volumes
3. **Configure log aggregation** (e.g., ELK stack, Loki)
4. **Set up alerting** in Prometheus/Grafana
5. **Implement service mesh** (e.g., Istio, Linkerd) for advanced traffic management
6. **Configure autoscaling** for nodes (cluster autoscaler)
7. **Implement disaster recovery** plan

## Common Post-Installation Tasks

### Scale Services

```bash
# Scale manually
kubectl scale deployment agent-service --replicas=5 -n callcenter-prod

# Configure HPA
kubectl autoscale deployment agent-service \
  --cpu-percent=70 --min=3 --max=10 -n callcenter-prod
```

### Update Services

```bash
# Using GitOps (recommended)
# 1. Update image tag in Git
# 2. Commit and push
# 3. ArgoCD will sync automatically (dev) or wait for manual sync (prod)

# Using kubectl
kubectl set image deployment/agent-service \
  agent-service=your-registry/agent-service:v1.2.0 \
  -n callcenter-prod
```

### View Logs

```bash
# View logs
kubectl logs -f deployment/agent-service -n callcenter-prod

# View logs from all replicas
kubectl logs -f -l app=callcenter-ai,component=agent-service -n callcenter-prod
```

## Troubleshooting

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for detailed troubleshooting guide.

Quick checks:

```bash
# Check all resources
kubectl get all -n callcenter-dev

# Check events
kubectl get events -n callcenter-dev --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods -n callcenter-dev
kubectl top nodes
```

## Documentation

- [GitOps Workflow](./GITOPS_WORKFLOW.md)
- [Troubleshooting Guide](./TROUBLESHOOTING.md)
- [Main README](./README.md)

## Support

For issues or questions:
- Check documentation
- Review logs and events
- Contact DevOps team
- Open GitHub issue

## Cleanup

To remove everything:

```bash
# Delete namespaces (this will delete all resources in them)
kubectl delete namespace callcenter-dev
kubectl delete namespace callcenter-prod
kubectl delete namespace argocd

# Delete cluster (if local)
minikube delete

# Or delete cloud cluster
gcloud container clusters delete callcenter-ai-cluster --zone us-central1-a
```