# GitOps Workflow Guide

This document describes the GitOps workflow for the MLOps CallCenter AI project using ArgoCD and Kubernetes.

## Overview

Our GitOps workflow follows these principles:

1. **Git as Single Source of Truth**: All infrastructure and application configurations are stored in Git
2. **Declarative Configuration**: Everything is defined declaratively in Kubernetes manifests
3. **Automated Deployment**: ArgoCD automatically syncs cluster state with Git repository
4. **Pull-based Deployment**: ArgoCD pulls changes from Git rather than pushing to cluster
5. **Continuous Reconciliation**: ArgoCD continuously monitors and corrects drift

## Architecture

```
┌─────────────┐
│  Developer  │
└──────┬──────┘
       │ git push
       ▼
┌─────────────────┐
│   Git Repo      │
│  (GitHub)       │
└──────┬──────────┘
       │
       │ webhook (optional)
       ▼
┌─────────────────┐         ┌──────────────────┐
│    ArgoCD       │────────▶│   Kubernetes     │
│   (Operator)    │  apply  │    Cluster       │
└─────────────────┘         └──────────────────┘
       │
       │ monitors
       └──────────────────────────┘
```

## Workflow Steps

### 1. Development Workflow

#### Making Changes

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/update-agent-service
   ```

2. **Make changes to manifests**:
   - Update image tags in `infrastructure/k8s/overlays/dev/kustomization.yaml`
   - Modify resource limits in patches
   - Update ConfigMaps or Secrets

3. **Test locally** (optional):
   ```bash
   # Build kustomization
   kubectl kustomize infrastructure/k8s/overlays/dev > /tmp/manifests.yaml
   
   # Validate
   kubectl apply --dry-run=client -f /tmp/manifests.yaml
   ```

4. **Commit and push**:
   ```bash
   git add infrastructure/
   git commit -m "feat: update agent service to v1.2.0"
   git push origin feature/update-agent-service
   ```

5. **Create Pull Request**:
   - Open PR on GitHub
   - CI pipeline runs validation
   - Request review from team members

### 2. CI Pipeline (GitHub Actions)

When a PR is opened, the CI pipeline:

1. **Validates manifests**:
   - Runs `kubectl apply --dry-run`
   - Checks YAML syntax
   - Validates against Kubernetes API

2. **Security scanning**:
   - Scans for secrets in code
   - Checks for security vulnerabilities
   - Validates RBAC policies

3. **Policy checks**:
   - Ensures resource limits are set
   - Validates naming conventions
   - Checks for required labels

### 3. Merge to Main Branch

After PR approval and merge:

1. **Development environment** (automatic):
   - ArgoCD detects changes in `develop` branch
   - Automatically syncs to `callcenter-dev` namespace
   - Pods are rolled out with new configuration

2. **Staging environment** (automatic):
   - Changes merged to `staging` branch
   - ArgoCD syncs to `callcenter-staging` namespace

3. **Production environment** (manual approval):
   - Changes merged to `main` branch
   - ArgoCD detects changes but waits for manual sync
   - Operator clicks "Sync" in ArgoCD UI after review
   - Progressive rollout with monitoring

## ArgoCD Application Management

### Application Structure

```
argocd/
├── projects/
│   └── callcenter-ai-project.yaml    # Project definition
└── apps/
    ├── callcenter-ai-dev.yaml        # Dev application
    ├── callcenter-ai-staging.yaml    # Staging application
    └── callcenter-ai-prod.yaml       # Prod application
```

### Sync Policies

#### Development
- **Auto-sync**: Enabled
- **Self-heal**: Enabled
- **Prune**: Enabled

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

#### Production
- **Auto-sync**: Disabled
- **Manual approval**: Required
- **Prune**: Enabled with confirmation

```yaml
syncPolicy:
  automated: null  # Manual sync only
```

### Health Assessment

ArgoCD monitors these resources:

- Deployments: Ready replicas
- Services: Endpoints available
- Pods: Running and healthy
- ConfigMaps/Secrets: Present
- Ingresses: Rules configured

## Deployment Strategies

### Rolling Update (Default)

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

**Use for**: Most service updates

### Blue-Green Deployment

1. Deploy new version alongside old
2. Test new version
3. Switch traffic to new version
4. Remove old version

**Use for**: Major version updates

### Canary Deployment

1. Deploy new version to subset of pods
2. Monitor metrics
3. Gradually increase traffic
4. Full rollout or rollback

**Use for**: High-risk changes

## Rollback Procedures

### Using ArgoCD UI

1. Navigate to application
2. Click "History and Rollback"
3. Select previous revision
4. Click "Rollback"

### Using ArgoCD CLI

```bash
# Get application history
argocd app history callcenter-ai-prod

# Rollback to specific revision
argocd app rollback callcenter-ai-prod 42
```

### Using kubectl

```bash
# Rollback deployment
kubectl rollout undo deployment/agent-service -n callcenter-prod

# Rollback to specific revision
kubectl rollout undo deployment/agent-service --to-revision=3 -n callcenter-prod
```

## Monitoring and Observability

### ArgoCD Notifications

Configure notifications for:

- Sync failures
- Degraded health status
- Out-of-sync warnings

### Metrics

ArgoCD exposes metrics for:

- Sync duration
- Sync status
- Application health
- API server requests

### Logs

```bash
# View ArgoCD logs
kubectl logs -n argocd deployment/argocd-server

# View application sync logs
argocd app logs callcenter-ai-prod
```

## Best Practices

### 1. Repository Structure

- Keep infrastructure code separate from application code
- Use clear directory structure
- Version control everything

### 2. Branch Strategy

- `develop`: Development environment
- `staging`: Staging environment  
- `main`: Production environment
- Feature branches for changes

### 3. Commit Messages

Follow conventional commits:
```
feat: add new feature
fix: fix bug
docs: update documentation
chore: update dependencies
```

### 4. Secrets Management

- Never commit secrets to Git
- Use External Secrets Operator
- Rotate secrets regularly
- Use least privilege access

### 5. Testing

- Test changes in dev first
- Use staging for integration testing
- Validate production changes carefully

### 6. Documentation

- Document all changes in commit messages
- Update README for major changes
- Maintain runbooks for operations

## Troubleshooting

### Application Out of Sync

**Problem**: ArgoCD shows application as "OutOfSync"

**Solution**:
```bash
# View differences
argocd app diff callcenter-ai-prod

# Sync application
argocd app sync callcenter-ai-prod
```

### Sync Failed

**Problem**: Sync operation fails

**Solution**:
1. Check ArgoCD logs
2. Validate manifests locally
3. Check for resource conflicts
4. Verify RBAC permissions

### Health Status Degraded

**Problem**: Application health is degraded

**Solution**:
1. Check pod status: `kubectl get pods -n callcenter-prod`
2. View pod logs: `kubectl logs <pod-name> -n callcenter-prod`
3. Check events: `kubectl get events -n callcenter-prod`
4. Verify resource availability

## Security Considerations

### RBAC

- Use least privilege principle
- Separate dev/staging/prod access
- Regular access reviews

### Network Policies

- Restrict pod-to-pod communication
- Allow only necessary egress
- Use service mesh for mTLS

### Image Security

- Scan images for vulnerabilities
- Use signed images
- Pull from trusted registries

## Emergency Procedures

### Production Incident

1. **Assess impact**: Check monitoring dashboards
2. **Immediate action**: Rollback if necessary
3. **Communicate**: Notify stakeholders
4. **Investigate**: Review logs and metrics
5. **Fix**: Apply hotfix if needed
6. **Post-mortem**: Document incident

### Disaster Recovery

1. **Backup**: Regular etcd backups
2. **State**: Git contains all configurations
3. **Recovery**: Restore from Git + backups
4. **Validation**: Test in staging first

## Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kustomize Documentation](https://kustomize.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [GitOps Principles](https://www.gitops.tech/)