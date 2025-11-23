#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
ENVIRONMENT="dev"
DRY_RUN=false
NAMESPACE=""

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy MLOps CallCenter AI to Kubernetes

OPTIONS:
    -e, --environment ENV    Environment to deploy (dev, staging, prod). Default: dev
    -n, --namespace NAME     Kubernetes namespace. Default: callcenter-ENV
    -d, --dry-run           Perform a dry run without applying changes
    -h, --help              Show this help message

EXAMPLES:
    # Deploy to development
    $0 -e dev

    # Deploy to production with dry run
    $0 -e prod --dry-run

    # Deploy to custom namespace
    $0 -e staging -n my-namespace

EOF
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    print_error "Invalid environment: $ENVIRONMENT"
    print_info "Valid environments: dev, staging, prod"
    exit 1
fi

# Set namespace if not provided
if [ -z "$NAMESPACE" ]; then
    NAMESPACE="callcenter-$ENVIRONMENT"
fi

print_info "Deployment Configuration:"
echo "  Environment: $ENVIRONMENT"
echo "  Namespace: $NAMESPACE"
echo "  Dry Run: $DRY_RUN"
echo ""

# Check prerequisites
print_info "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed"
    exit 1
fi

if ! command -v kustomize &> /dev/null; then
    print_warning "kustomize not found, using kubectl kustomize"
fi

# Check cluster connection
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_info "Prerequisites check passed"

# Create namespace if it doesn't exist
print_info "Ensuring namespace exists..."
if [ "$DRY_RUN" = false ]; then
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
else
    print_info "[DRY RUN] Would create namespace: $NAMESPACE"
fi

# Deploy using kustomize
OVERLAY_DIR="$INFRA_DIR/k8s/overlays/$ENVIRONMENT"

if [ ! -d "$OVERLAY_DIR" ]; then
    print_error "Overlay directory not found: $OVERLAY_DIR"
    exit 1
fi

print_info "Deploying to $ENVIRONMENT environment..."

if [ "$DRY_RUN" = true ]; then
    print_info "[DRY RUN] Would apply the following manifests:"
    kubectl kustomize "$OVERLAY_DIR"
else
    kubectl apply -k "$OVERLAY_DIR" -n "$NAMESPACE"
fi

# Wait for deployments to be ready
if [ "$DRY_RUN" = false ]; then
    print_info "Waiting for deployments to be ready..."

    DEPLOYMENTS=(
        "agent-service"
        "tfidf-service"
        "transformer-service"
        "mlflow"
        "prometheus"
        "grafana"
    )

    for deployment in "${DEPLOYMENTS[@]}"; do
        print_info "Waiting for deployment: $deployment"
        kubectl rollout status deployment/"$ENVIRONMENT-$deployment" -n "$NAMESPACE" --timeout=5m || {
            print_warning "Timeout waiting for $deployment"
        }
    done

    print_info "All deployments are ready!"
else
    print_info "[DRY RUN] Would wait for deployments to be ready"
fi

# Display service endpoints
print_info "Service Endpoints:"
if [ "$DRY_RUN" = false ]; then
    kubectl get ingress -n "$NAMESPACE" -o wide
else
    print_info "[DRY RUN] Would display ingress endpoints"
fi

# Success message
print_info "Deployment completed successfully!"
print_info "To check the status, run: kubectl get all -n $NAMESPACE"