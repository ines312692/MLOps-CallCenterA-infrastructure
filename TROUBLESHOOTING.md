# Kubernetes Infrastructure Troubleshooting Guide

This guide helps diagnose and resolve common issues with the MLOps CallCenter AI Kubernetes infrastructure.

## Table of Contents

1. [Pod Issues](#pod-issues)
2. [Service Connectivity](#service-connectivity)
3. [Ingress Problems](#ingress-problems)
4. [Persistent Volume Issues](#persistent-volume-issues)
5. [Resource Constraints](#resource-constraints)
6. [ArgoCD Issues](#argocd-issues)
7. [Networking Problems](#networking-problems)
8. [Performance Issues](#performance-issues)

## Pod Issues

### Pod Stuck in Pending State

**Symptoms**:
```bash
$ kubectl get pods -n callcenter-prod
NAME                           READY   STATUS    RESTARTS   AGE
agent-service-xxx              0/1     Pending   0          5m
```

**Diagnosis**:
```bash
# Check pod events
kubectl describe pod agent-service-xxx -n callcenter-prod

# Check node resources
kubectl describe nodes

# Check PVC status
kubectl get pvc -n callcenter-prod
```

**Common Causes & Solutions**:

1. **Insufficient resources**:
   - Symptom: `FailedScheduling: Insufficient cpu/memory`
   - Solution: Scale cluster or reduce resource requests
   ```bash
   # Scale nodes
   kubectl scale deployment agent-service --replicas=1 -n callcenter-prod
   ```

2. **PVC not bound**:
   - Symptom: `waiting for volume to be created`
   - Solution: Check storage class and provisioner
   ```bash
   kubectl get storageclass
   kubectl get pv
   ```

3. **Node selector mismatch**:
   - Symptom: `no nodes available to schedule pods`
   - Solution: Remove node selector or add appropriate label
   ```bash
   kubectl label nodes <node-name> <label-key>=<label-value>
   ```

### Pod in CrashLoopBackOff

**Symptoms**:
```bash
NAME                           READY   STATUS             RESTARTS   AGE
transformer-service-xxx        0/1     CrashLoopBackOff   5          10m
```

**Diagnosis**:
```bash
# Check pod logs
kubectl logs transformer-service-xxx -n callcenter-prod

# Check previous logs
kubectl logs transformer-service-xxx --previous -n callcenter-prod

# Check pod events
kubectl describe pod transformer-service-xxx -n callcenter-prod
```

**Common Causes & Solutions**:

1. **Application error**:
   - Check logs for error messages
   - Verify environment variables
   - Check ConfigMaps and Secrets
   ```bash
   kubectl get configmap -n callcenter-prod
   kubectl get secret -n callcenter-prod
   ```

2. **Missing dependencies**:
   - Check if dependent services are running
   - Verify service discovery
   ```bash
   kubectl get svc -n callcenter-prod
   ```

3. **Liveness probe failure**:
   - Adjust probe timeouts
   - Check application health endpoint
   ```bash
   # Test health endpoint from within pod
   kubectl exec -it transformer-service-xxx -n callcenter-prod -- curl localhost:8002/health
   ```

### Pod Not Ready

**Symptoms**:
```bash
NAME                           READY   STATUS    RESTARTS   AGE
tfidf-service-xxx              0/1     Running   0          2m
```

**Diagnosis**:
```bash
# Check readiness probe
kubectl describe pod tfidf-service-xxx -n callcenter-prod

# Check pod logs
kubectl logs tfidf-service-xxx -n callcenter-prod
```

**Solutions**:

1. **Readiness probe failing**:
   - Increase `initialDelaySeconds`
   - Check health endpoint response
   - Verify application startup time

2. **Slow startup**:
   - Adjust probe timing
   - Consider init containers for pre-warming

## Service Connectivity

### Cannot Connect to Service

**Diagnosis**:
```bash
# Check service
kubectl get svc -n callcenter-prod

# Check endpoints
kubectl get endpoints -n callcenter-prod

# Test from another pod
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://agent-service.callcenter-prod:8000/health
```

**Solutions**:

1. **No endpoints**:
   - Check if pods are ready
   - Verify selector labels match
   ```bash
   kubectl get pods -n callcenter-prod --show-labels
   ```

2. **Network policy blocking**:
   - Check network policies
   ```bash
   kubectl get networkpolicy -n callcenter-prod
   kubectl describe networkpolicy <policy-name> -n callcenter-prod
   ```

3. **Service type mismatch**:
   - Verify service type (ClusterIP, NodePort, LoadBalancer)
   - Check if external access is needed

## Ingress Problems

### Ingress Not Working

**Diagnosis**:
```bash
# Check ingress
kubectl get ingress -n callcenter-prod

# Describe ingress
kubectl describe ingress agent-service-ingress -n callcenter-prod

# Check ingress controller
kubectl get pods -n ingress-nginx
```

**Solutions**:

1. **Ingress controller not running**:
   ```bash
   # Install NGINX ingress controller
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
   ```

2. **TLS certificate issues**:
   ```bash
   # Check cert-manager
   kubectl get certificates -n callcenter-prod
   kubectl describe certificate <cert-name> -n callcenter-prod
   
   # Check cert-manager logs
   kubectl logs -n cert-manager deployment/cert-manager
   ```

3. **DNS not resolving**:
   - Check DNS records point to LoadBalancer IP
   - Verify ingress annotations
   - Test with curl: `curl -H "Host: api.callcenter-ai.com" http://<ingress-ip>`

## Persistent Volume Issues

### PVC Pending

**Diagnosis**:
```bash
# Check PVC
kubectl get pvc -n callcenter-prod

# Describe PVC
kubectl describe pvc mlflow-artifacts-pvc -n callcenter-prod

# Check PVs
kubectl get pv
```

**Solutions**:

1. **No storage class**:
   ```bash
   # List storage classes
   kubectl get storageclass
   
   # Set default storage class
   kubectl patch storageclass <storage-class> \
     -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
   ```

2. **Provisioner issues**:
   - Check cloud provider integration
   - Verify IAM permissions
   - Check provisioner logs

3. **Size constraints**:
   - Verify requested size is available
   - Check quota limits

## Resource Constraints

### OOMKilled Pods

**Symptoms**:
```bash
NAME                           READY   STATUS      RESTARTS   AGE
transformer-service-xxx        0/1     OOMKilled   3          10m
```

**Diagnosis**:
```bash
# Check pod status
kubectl describe pod transformer-service-xxx -n callcenter-prod

# Check resource usage
kubectl top pod transformer-service-xxx -n callcenter-prod
```

**Solutions**:

1. **Increase memory limits**:
   ```bash
   # Edit deployment
   kubectl edit deployment transformer-service -n callcenter-prod
   
   # Or patch
   kubectl patch deployment transformer-service -n callcenter-prod \
     --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value":"8Gi"}]'
   ```

2. **Add resource requests**:
   - Ensure requests are set appropriately
   - Monitor actual usage with `kubectl top`

### CPU Throttling

**Diagnosis**:
```bash
# Check metrics
kubectl top pods -n callcenter-prod

# Check node capacity
kubectl describe nodes
```

**Solutions**:

1. **Increase CPU limits**
2. **Scale horizontally** (add more replicas)
3. **Optimize application** (profiling, caching)

## ArgoCD Issues

### Application Out of Sync

**Diagnosis**:
```bash
# Check application status
argocd app get callcenter-ai-prod

# View differences
argocd app diff callcenter-ai-prod
```

**Solutions**:

1. **Manual sync**:
   ```bash
   argocd app sync callcenter-ai-prod
   ```

2. **Force sync**:
   ```bash
   argocd app sync callcenter-ai-prod --force
   ```

3. **Reset to Git state**:
   ```bash
   argocd app sync callcenter-ai-prod --replace
   ```

### Sync Failed

**Diagnosis**:
```bash
# View sync status
argocd app get callcenter-ai-prod

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller
```

**Solutions**:

1. **Validation errors**:
   - Check manifest syntax
   - Validate with `kubectl apply --dry-run`

2. **Permission errors**:
   - Check RBAC permissions
   - Verify service account

3. **Resource conflicts**:
   - Check for existing resources
   - Use `--force` flag if needed

## Networking Problems

### DNS Resolution Failing

**Diagnosis**:
```bash
# Test DNS from pod
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup agent-service.callcenter-prod.svc.cluster.local

# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

**Solutions**:

1. **CoreDNS not running**:
   ```bash
   kubectl rollout restart deployment/coredns -n kube-system
   ```

2. **DNS policy issues**:
   - Check pod DNS policy
   - Verify DNS config in pod spec

### Network Policy Blocking Traffic

**Diagnosis**:
```bash
# List network policies
kubectl get networkpolicy -n callcenter-prod

# Test connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://tfidf-service:8001/health
```

**Solutions**:

1. **Adjust network policies**:
   ```bash
   kubectl edit networkpolicy <policy-name> -n callcenter-prod
   ```

2. **Temporarily disable** (for testing):
   ```bash
   kubectl delete networkpolicy <policy-name> -n callcenter-prod
   ```

## Performance Issues

### High Latency

**Diagnosis**:
```bash
# Check pod metrics
kubectl top pods -n callcenter-prod

# Check Prometheus metrics
kubectl port-forward svc/prometheus 9090:9090 -n callcenter-monitoring
# Open http://localhost:9090
```

**Solutions**:

1. **Scale horizontally**:
   ```bash
   kubectl scale deployment agent-service --replicas=5 -n callcenter-prod
   ```

2. **Enable HPA**:
   ```bash
   kubectl autoscale deployment agent-service \
     --cpu-percent=70 --min=3 --max=10 -n callcenter-prod
   ```

3. **Optimize resources**:
   - Increase CPU/memory limits
   - Add caching layer (Redis)
   - Profile application

### Slow Pod Startup

**Solutions**:

1. **Use init containers** for pre-warming
2. **Optimize image size** (multi-stage builds)
3. **Use image pull policy** `IfNotPresent`
4. **Pre-pull images** on nodes

## Common Commands

### Quick Debugging

```bash
# Get all resources
kubectl get all -n callcenter-prod

# Check events
kubectl get events -n callcenter-prod --sort-by='.lastTimestamp'

# View logs
kubectl logs -f <pod-name> -n callcenter-prod

# Execute command in pod
kubectl exec -it <pod-name> -n callcenter-prod -- /bin/bash

# Port forward to service
kubectl port-forward svc/agent-service 8000:8000 -n callcenter-prod

# Check resource usage
kubectl top pods -n callcenter-prod
kubectl top nodes
```

### Cleanup Commands

```bash
# Delete failed pods
kubectl delete pod --field-selector=status.phase=Failed -n callcenter-prod

# Delete completed pods
kubectl delete pod --field-selector=status.phase=Succeeded -n callcenter-prod

# Clean up evicted pods
kubectl get pods -n callcenter-prod | grep Evicted | awk '{print $1}' | xargs kubectl delete pod -n callcenter-prod
```

## Getting Help

If issues persist:

1. **Check logs**: Application, Kubernetes events, ArgoCD
2. **Review documentation**: Kubernetes, ArgoCD, application docs
3. **Community support**: Kubernetes Slack, Stack Overflow
4. **Contact team**: DevOps team, application developers

## Additional Resources

- [Kubernetes Debugging Guide](https://kubernetes.io/docs/tasks/debug/)
- [ArgoCD Troubleshooting](https://argo-cd.readthedocs.io/en/stable/operator-manual/troubleshooting/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)