# MLOps CallCenter AI - Infrastructure Overview

## What Has Been Created

A complete, production-ready Kubernetes and GitOps infrastructure for your MLOps CallCenter AI project has been created. This infrastructure includes:

###  Directory Structure

```
infrastructure/
├── k8s/                          # Kubernetes manifests
│   ├── base/                     # Base configurations
│   │   ├── agent-service.yaml
│   │   ├── tfidf-service.yaml
│   │   ├── transformer-service.yaml
│   │   ├── mlflow.yaml
│   │   ├── postgres.yaml
│   │   ├── redis.yaml
│   │   ├── prometheus.yaml
│   │   ├── grafana.yaml
│   │   ├── configmaps.yaml
│   │   ├── secrets.yaml
│   │   ├── networkpolicies.yaml
│   │   ├── ingress.yaml
│   │   └── kustomization.yaml
│   ├── overlays/                 # Environment-specific configs
│   │   ├── dev/
│   │   │   ├── kustomization.yaml
│   │   │   ├── resources-patch.yaml
│   │   │   └── ingress-patch.yaml
│   │   └── prod/
│   │       ├── kustomization.yaml
│   │       ├── resources-patch.yaml
│   │       ├── ingress-patch.yaml
│   │       ├── pod-disruption-budget.yaml
│   │       └── priority-class.yaml
│   └── namespaces/
│       └── namespaces.yaml
├── helm/                         # Helm charts
│   └── callcenter-ai/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-dev.yaml
│       └── values-prod.yaml
├── argocd/                       # GitOps configurations
│   ├── projects/
│   │   └── callcenter-ai-project.yaml
│   └── apps/
│       ├── callcenter-ai-dev.yaml
│       └── callcenter-ai-prod.yaml
├── scripts/                      # Automation scripts
│   ├── deploy.sh
│   └── setup-argocd.sh
├── Makefile                      # Easy management commands
├── README.md                     # Main documentation
├── SETUP_GUIDE.md               # Complete setup guide
├── GITOPS_WORKFLOW.md           # GitOps workflow guide
└── TROUBLESHOOTING.md           # Troubleshooting guide
```

##  Key Features

### 1. Multi-Environment Support
- **Development**: For testing and development
- **Staging**: For pre-production testing (optional)
- **Production**: For production workloads

### 2. GitOps-Ready with ArgoCD
- Automated deployments from Git
- Continuous synchronization
- Self-healing capabilities
- Easy rollbacks
- Full audit trail

### 3. Complete Service Stack
- **Agent Service**: Main API and orchestration
- **TF-IDF Service**: Traditional ML classification
- **Transformer Service**: Deep learning classification
- **MLflow**: Model registry and tracking
- **PostgreSQL**: MLflow backend storage
- **Redis**: Caching layer
- **Prometheus**: Metrics collection
- **Grafana**: Visualization dashboards

### 4. Production-Ready Features

#### High Availability
- Multiple replicas for critical services
- Pod Disruption Budgets
- Anti-affinity rules
- Health checks (liveness & readiness probes)

#### Auto-Scaling
- Horizontal Pod Autoscaler (HPA)
- Resource-based scaling
- Configurable min/max replicas

#### Security
- RBAC (Role-Based Access Control)
- Network Policies for pod-to-pod communication
- Secrets management
- Non-root containers
- Security contexts

#### Monitoring & Observability
- Prometheus metrics collection
- Grafana dashboards
- Service health monitoring
- Resource usage tracking

#### Networking
- Ingress with NGINX
- TLS/SSL with cert-manager
- LoadBalancer support
- Service mesh ready

### 5. Multiple Deployment Options

#### Option A: GitOps with ArgoCD (Recommended)
```bash
# Setup ArgoCD
make setup-argocd

# Deploy applications
kubectl apply -f argocd/apps/
```

#### Option B: Direct Deployment with kubectl/kustomize
```bash
# Deploy development
make deploy-dev

# Deploy production
make deploy-prod
```

#### Option C: Helm Charts
```bash
# Install with Helm
make helm-install-dev
make helm-install-prod
```

##  Quick Start

### Prerequisites
1. Kubernetes cluster (local or cloud)
2. kubectl configured
3. Basic tools (helm, kustomize)

### Deployment Steps

#### 1. Setup Infrastructure Tools
```bash
cd infrastructure
make install-tools
```

#### 2. Configure Secrets
Create your secrets (DO NOT commit to Git):
```bash
# Groq API Key
kubectl create secret generic groq-api-key \
  --from-literal=GROQ_API_KEY=your-key \
  --namespace callcenter-dev

# Database password
kubectl create secret generic postgres-credentials \
  --from-literal=username=mlflow \
  --from-literal=password=your-password \
  --namespace callcenter-dev
```

#### 3. Deploy Using GitOps (Recommended)
```bash
# Setup ArgoCD
make setup-argocd

# Apply ArgoCD applications
kubectl apply -f argocd/projects/
kubectl apply -f argocd/apps/
```

#### 4. Or Deploy Directly
```bash
# Deploy to development
make deploy-dev

# Deploy to production (with confirmation)
make deploy-prod
```

#### 5. Verify Deployment
```bash
# Check status
make status

# Check resource usage
make top ENV=dev

# View logs
make logs-dev-agent
```

#### 6. Access Services
```bash
# Port forward services
make port-forward-dev

# Access:
# - Agent API: http://localhost:8000
# - MLflow: http://localhost:5000
# - Prometheus: http://localhost:9090
# - Grafana: http://localhost:3000
```

##  Documentation

### Main Guides
1. **[SETUP_GUIDE.md](SETUP_GUIDE.md)**: Complete installation and setup
2. **[GITOPS_WORKFLOW.md](GITOPS_WORKFLOW.md)**: GitOps workflow and best practices
3. **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)**: Common issues and solutions
4. **[README.md](README.md)**: Infrastructure overview

### Quick Reference

#### Common Commands
```bash
# Show all available commands
make help

# Deploy environments
make deploy-dev
make deploy-prod

# Check status
make status
make top ENV=dev
make events ENV=dev

# View logs
make logs ENV=dev SERVICE=agent-service
make logs-dev-agent

# Scale services
make scale-up ENV=dev SERVICE=agent-service REPLICAS=5
make scale-down ENV=dev

# Port forwarding
make port-forward-dev
make port-forward-prod

# ArgoCD operations
make argocd-sync-dev
make argocd-sync-prod
make argocd-status

# Cleanup
make clean-dev
make clean-prod
```

#### kubectl Commands
```bash
# Get all resources
kubectl get all -n callcenter-dev

# Describe resources
kubectl describe pod <pod-name> -n callcenter-dev

# View logs
kubectl logs -f deployment/agent-service -n callcenter-dev

# Execute commands in pod
kubectl exec -it <pod-name> -n callcenter-dev -- /bin/bash

# Port forward
kubectl port-forward svc/agent-service 8000:8000 -n callcenter-dev
```

##  Architecture Highlights

### Service Communication
```
Client → Ingress → Agent Service → {TF-IDF Service, Transformer Service}
                                 → MLflow
                                 → Redis
```

### Data Flow
```
Request → Agent Service (PII Detection) → Model Selection → Classification → Response
                                                          ↓
                                                       MLflow (Tracking)
```

### Monitoring Stack
```
Services → Prometheus (Metrics) → Grafana (Dashboards)
```

##  Security Features

1. **Network Policies**: Restrict pod-to-pod communication
2. **RBAC**: Role-based access control for Kubernetes resources
3. **Secrets Management**: Kubernetes secrets (recommend External Secrets Operator for production)
4. **Security Contexts**: Non-root containers, read-only filesystems
5. **TLS/SSL**: Automatic certificate management with cert-manager
6. **Pod Security Standards**: Security best practices enforced

##  Monitoring & Observability

### Metrics Available
- Request rates and latencies
- Model inference times
- Confidence scores
- Resource usage (CPU, memory)
- Error rates
- Pod health status

### Dashboards
- Service performance dashboard
- Resource utilization dashboard
- Model performance dashboard
- System health dashboard

##  CI/CD Integration

The infrastructure integrates with your existing GitHub Actions workflows:

1. **Build**: GitHub Actions builds Docker images
2. **Push**: Images pushed to registry
3. **Deploy**: ArgoCD detects changes and deploys
4. **Monitor**: Prometheus/Grafana track performance

##  Scaling Strategies

### Horizontal Pod Autoscaling
- CPU-based: Scales based on CPU utilization
- Memory-based: Scales based on memory utilization
- Custom metrics: Can scale based on custom metrics

### Vertical Pod Autoscaling
- Can be enabled for automatic resource adjustment

### Cluster Autoscaling
- Automatically adds/removes nodes based on demand

## 🔧 Customization

### Modify Resources
Edit the patch files in `k8s/overlays/{env}/resources-patch.yaml`

### Change Replica Counts
Edit `kustomization.yaml` in overlays or use:
```bash
make scale-up ENV=prod SERVICE=agent-service REPLICAS=10
```

### Update Configurations
Modify ConfigMaps in `k8s/base/configmaps.yaml`

### Change Ingress Domains
Update `ingress-patch.yaml` in environment overlays

##  Getting Help

1. Check the [TROUBLESHOOTING.md](TROUBLESHOOTING.md) guide
2. Review logs: `make logs ENV=dev SERVICE=agent-service`
3. Check events: `make events ENV=dev`
4. Check resource usage: `make top ENV=dev`
5. Review documentation in the infrastructure directory

##  Learning Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kustomize Documentation](https://kustomize.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [GitOps Principles](https://www.gitops.tech/)

##  Next Steps

1. **Review** all documentation files
2. **Customize** configurations for your environment
3. **Set up** your Kubernetes cluster
4. **Configure** secrets securely
5. **Deploy** to development first
6. **Test** thoroughly
7. **Deploy** to production
8. **Monitor** and optimize

##  Important Notes

### Before Production Deployment

1. **Secrets**: Use External Secrets Operator or HashiCorp Vault
2. **Backup**: Set up backup strategy for persistent volumes
3. **Monitoring**: Configure alerting rules
4. **DNS**: Configure DNS records for ingress
5. **TLS**: Use Let's Encrypt production certificates
6. **Resource Limits**: Adjust based on actual usage
7. **Scaling**: Configure appropriate min/max replicas
8. **Security**: Review and test network policies
9. **Disaster Recovery**: Document and test recovery procedures
10. **Documentation**: Update with environment-specific details

### Security Checklist

- [ ] Secrets are not committed to Git
- [ ] RBAC is properly configured
- [ ] Network policies are tested
- [ ] TLS certificates are configured
- [ ] Container images are from trusted sources
- [ ] Resource limits are set
- [ ] Security scanning is enabled in CI/CD
- [ ] Pod security contexts are configured
- [ ] Ingress authentication is configured (where needed)

##  Contributing

When making changes to infrastructure:

1. Create a feature branch
2. Make changes
3. Test in development
4. Create pull request
5. Get approval
6. Merge to appropriate branch
7. ArgoCD will sync automatically (dev) or wait for manual approval (prod)

##  Support

For issues or questions:
- Review documentation
- Check logs and events
- Contact DevOps team
- Open GitHub issue

---

**Infrastructure Version**: 1.0.0  
**Created**: November 2025  
**Maintained by**: MLOps Team

This infrastructure provides a solid foundation for running your MLOps CallCenter AI project in production with modern DevOps practices, high availability, and full observability.