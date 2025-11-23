#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_info "Setting up ArgoCD for GitOps..."

# Create ArgoCD namespace
print_info "Creating ArgoCD namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
print_info "Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
print_info "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s \
    deployment/argocd-server -n argocd

# Get ArgoCD admin password
print_info "Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d)

# Install ArgoCD CLI (optional)
if ! command -v argocd &> /dev/null; then
    print_warning "ArgoCD CLI not found. Install it from: https://argo-cd.readthedocs.io/en/stable/cli_installation/"
fi

# Apply ArgoCD project
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"

print_info "Creating ArgoCD project..."
kubectl apply -f "$INFRA_DIR/argocd/projects/callcenter-ai-project.yaml"

# Apply ArgoCD applications
print_info "Creating ArgoCD applications..."
kubectl apply -f "$INFRA_DIR/argocd/apps/"

# Expose ArgoCD server
print_info "Setting up ArgoCD server access..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Wait for LoadBalancer IP
print_info "Waiting for LoadBalancer IP..."
sleep 10
ARGOCD_IP=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$ARGOCD_IP" ]; then
    print_warning "LoadBalancer IP not available yet. You can access ArgoCD via port-forward:"
    echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
    ARGOCD_URL="https://localhost:8080"
else
    ARGOCD_URL="https://$ARGOCD_IP"
fi

# Success message
print_info "ArgoCD setup completed!"
echo ""
print_info "ArgoCD Details:"
echo "  URL: $ARGOCD_URL"
echo "  Username: admin"
echo "  Password: $ARGOCD_PASSWORD"
echo ""
print_info "To access ArgoCD UI:"
echo "  1. Open $ARGOCD_URL in your browser"
echo "  2. Login with the credentials above"
echo "  3. You should see the callcenter-ai applications"
echo ""
print_info "To use ArgoCD CLI:"
echo "  argocd login $ARGOCD_IP --username admin --password $ARGOCD_PASSWORD"
echo ""
print_warning "IMPORTANT: Change the admin password after first login!"

# Save credentials to file
CREDS_FILE="$INFRA_DIR/argocd-credentials.txt"
cat > "$CREDS_FILE" << EOF
ArgoCD Credentials
==================
URL: $ARGOCD_URL
Username: admin
Password: $ARGOCD_PASSWORD

Access via port-forward:
kubectl port-forward svc/argocd-server -n argocd 8080:443

ArgoCD CLI login:
argocd login $ARGOCD_IP --username admin --password $ARGOCD_PASSWORD

IMPORTANT: Change the admin password after first login!
EOF

print_info "Credentials saved to: $CREDS_FILE"
print_warning "Keep this file secure and delete it after saving the credentials!"