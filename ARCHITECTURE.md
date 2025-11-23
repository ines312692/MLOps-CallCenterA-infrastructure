# Infrastructure Architecture Diagrams

## Complete System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              External Users                                  │
└────────────────────────────────┬────────────────────────────────────────────┘
                                 │ HTTPS
                                 ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Internet / DNS                                     │
│  api.callcenter-ai.com  →  LoadBalancer IP                                  │
│  mlflow.callcenter-ai.com  →  LoadBalancer IP                               │
│  grafana.callcenter-ai.com  →  LoadBalancer IP                              │
└────────────────────────────────┬────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster (GKE/EKS/AKS)                        │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      Ingress Controller (NGINX)                      │   │
│  │  - TLS Termination (cert-manager)                                    │   │
│  │  - Rate Limiting                                                      │   │
│  │  - Authentication (for admin services)                               │   │
│  └──────────┬───────────────────┬────────────────────┬──────────────────┘   │
│             │                   │                    │                       │
│             ▼                   ▼                    ▼                       │
│  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐           │
│  │  Agent Service   │ │     MLflow       │ │     Grafana      │           │
│  │   (Port 8000)    │ │   (Port 5000)    │ │   (Port 3000)    │           │
│  │                  │ │                  │ │                  │           │
│  │ ┌──────────────┐ │ │ ┌──────────────┐ │ │ ┌──────────────┐ │           │
│  │ │    Pod 1     │ │ │ │    Pod       │ │ │ │    Pod       │ │           │
│  │ │    Pod 2     │ │ │ └──────┬───────┘ │ │ └──────┬───────┘ │           │
│  │ │    Pod 3     │ │ │        │         │ │        │         │           │
│  │ │   (HPA)      │ │ │        ▼         │ │        ▼         │           │
│  │ └──────┬───────┘ │ │ ┌──────────────┐ │ │ ┌──────────────┐ │           │
│  │        │         │ │ │  PostgreSQL  │ │ │ │  Prometheus  │ │           │
│  │        │         │ │ │  (Backend)   │ │ │ │  (DataSource)│ │           │
│  │        ▼         │ │ └──────────────┘ │ │ └──────────────┘ │           │
│  │ ┌──────────────┐ │ │ ┌──────────────┐ │ │                  │           │
│  │ │    Redis     │ │ │ │ Artifacts    │ │ │                  │           │
│  │ │   (Cache)    │ │ │ │    (PVC)     │ │ │                  │           │
│  │ └──────────────┘ │ │ └──────────────┘ │ │                  │           │
│  └──────┬───────────┘ └──────────────────┘ └──────────────────┘           │
│         │                                                                    │
│         ▼                                                                    │
│  ┌─────────────────────────────────────────────────────────┐               │
│  │         Classification Services (Internal Network)       │               │
│  │                                                           │               │
│  │  ┌──────────────────────┐    ┌──────────────────────┐  │               │
│  │  │  TF-IDF Service      │    │ Transformer Service   │  │               │
│  │  │   (Port 8001)        │    │    (Port 8002)        │  │               │
│  │  │                      │    │                       │  │               │
│  │  │ ┌────────────────┐  │    │ ┌────────────────┐   │  │               │
│  │  │ │ Pod 1  Pod 2   │  │    │ │ Pod 1  Pod 2   │   │  │               │
│  │  │ │ Pod 3  Pod 4   │  │    │ │ Pod 3 (HPA)    │   │  │               │
│  │  │ │ Pod 5 (HPA)    │  │    │ └────────────────┘   │  │               │
│  │  │ └────────────────┘  │    │                       │  │               │
│  │  │        ▼            │    │        ▼              │  │               │
│  │  │ ┌────────────────┐  │    │ ┌────────────────┐   │  │               │
│  │  │ │  Models (PVC)  │  │    │ │  Models (PVC)  │   │  │               │
│  │  │ │  Data (PVC)    │  │    │ │  Data (PVC)    │   │  │               │
│  │  │ └────────────────┘  │    │ │  HF Cache      │   │  │               │
│  │  └──────────────────────┘    │ └────────────────┘   │  │               │
│  │                               └──────────────────────┘  │               │
│  └─────────────────────────────────────────────────────────┘               │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────┐               │
│  │              Monitoring Stack (Internal)                 │               │
│  │                                                           │               │
│  │  ┌──────────────────┐         ┌──────────────────┐     │               │
│  │  │   Prometheus     │────────▶│     Grafana      │     │               │
│  │  │  (Port 9090)     │  Scrape │   (Port 3000)    │     │               │
│  │  │                  │  Metrics│                  │     │               │
│  │  │ ┌──────────────┐ │         │                  │     │               │
│  │  │ │ TSDB Storage │ │         │                  │     │               │
│  │  │ │   (50Gi PVC) │ │         │                  │     │               │
│  │  │ └──────────────┘ │         │                  │     │               │
│  │  └────────▲─────────┘         └──────────────────┘     │               │
│  │           │ Scrapes                                     │               │
│  │           └─────────────────────────────────────────┐   │               │
│  │                     All Services (metrics endpoints) │   │               │
│  └─────────────────────────────────────────────────────────┘               │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────┐               │
│  │              Network Policies (Security Layer)           │               │
│  │  - Agent Service → TF-IDF, Transformer, MLflow, Redis   │               │
│  │  - TF-IDF/Transformer → MLflow only                     │               │
│  │  - MLflow → PostgreSQL only                             │               │
│  │  - Grafana → Prometheus only                            │               │
│  │  - Prometheus → All services (metrics)                  │               │
│  │  - External access via Ingress only                     │               │
│  └─────────────────────────────────────────────────────────┘               │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────┘
```

## GitOps Workflow

```
┌───────────────────┐
│   Developer       │
│   Workstation     │
└─────────┬─────────┘
          │ git push
          ▼
┌───────────────────────────────────────────────────────────────┐
│                       Git Repository (GitHub)                  │
│                                                                │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  infrastructure/                                        │  │
│  │  ├── k8s/                                               │  │
│  │  │   ├── base/          (Base configurations)          │  │
│  │  │   └── overlays/                                      │  │
│  │  │       ├── dev/       (Development configs)          │  │
│  │  │       ├── staging/   (Staging configs)              │  │
│  │  │       └── prod/      (Production configs)           │  │
│  │  ├── helm/                                              │  │
│  │  └── argocd/                                            │  │
│  └────────────────────────────────────────────────────────┘  │
└─────────┬──────────────────────────────────────────────────┘
          │
          │ Webhook (optional)
          │ or Polling
          ▼
┌─────────────────────────────────────────────────────────────┐
│                    ArgoCD (GitOps Controller)                │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Application Controller                              │   │
│  │  - Monitors Git repository                           │   │
│  │  - Detects configuration changes                     │   │
│  │  - Compares desired state (Git) vs actual (cluster) │   │
│  │  - Syncs automatically (dev) or waits (prod)        │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Dev App      │  │ Staging App  │  │ Prod App     │     │
│  │ (Auto Sync)  │  │ (Auto Sync)  │  │ (Manual)     │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
└─────────┼──────────────────┼──────────────────┼─────────────┘
          │                  │                  │
          │ kubectl apply    │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Dev        │  │   Staging    │  │   Prod       │     │
│  │  Namespace   │  │  Namespace   │  │  Namespace   │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
          │                  │                  │
          └──────────┬───────┴──────────────────┘
                     │ Health Status & Metrics
                     ▼
┌─────────────────────────────────────────────────────────────┐
│               Monitoring & Alerting                          │
│  Prometheus → Grafana → Alerts → Notifications              │
└─────────────────────────────────────────────────────────────┘
```

## Request Flow

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │
       │ POST /predict
       │ {"text": "WiFi not working", "ticket_id": "T123"}
       ▼
┌──────────────────────────────────────────┐
│         Ingress Controller                │
│  - TLS Termination                        │
│  - Rate Limiting                          │
│  - Request Routing                        │
└──────┬───────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────┐
│       Agent Service (LangChain)           │
│                                           │
│  1. Receive request                       │
│  2. PII Detection & Scrubbing            │
│  3. Language Detection                    │
│  4. Model Selection (Groq LLM)           │
│     ├─ Text complexity analysis          │
│     ├─ Language analysis                 │
│     └─ Historical performance            │
└──────┬────────────────┬──────────────────┘
       │                │
       │ Simple         │ Complex
       ▼                ▼
┌────────────┐    ┌──────────────┐
│  TF-IDF    │    │ Transformer  │
│  Service   │    │   Service    │
│            │    │              │
│ - Fast     │    │ - Powerful   │
│ - SVM      │    │ - Multilang  │
│ - Cached   │    │ - Contextual │
└─────┬──────┘    └──────┬───────┘
      │                  │
      │ Classification   │
      │ Result          │
      │                  │
      ├──────────┬───────┘
               ▼
┌──────────────────────────────────────────┐
│           MLflow Tracking                 │
│  - Log prediction                         │
│  - Record confidence                      │
│  - Store metrics                          │
└──────┬───────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────┐
│       Agent Service (Response)            │
│  - Format response                        │
│  - Add metadata                           │
│  - Log metrics to Prometheus             │
└──────┬───────────────────────────────────┘
       │
       │ Response
       ▼
┌──────────────────────────────────────────┐
│           Client                          │
│  {                                        │
│    "ticket_id": "T123",                  │
│    "category": "Network Issues",         │
│    "confidence": 0.92,                   │
│    "model_used": "tfidf",                │
│    "processing_time": 0.056              │
│  }                                        │
└──────────────────────────────────────────┘
```

## Deployment Strategies

### Rolling Update (Default)

```
Initial State:
┌────┐ ┌────┐ ┌────┐
│ v1 │ │ v1 │ │ v1 │  (3 replicas)
└────┘ └────┘ └────┘

Step 1: Create new pod
┌────┐ ┌────┐ ┌────┐ ┌────┐
│ v1 │ │ v1 │ │ v1 │ │ v2 │
└────┘ └────┘ └────┘ └────┘

Step 2: Terminate old, wait for ready
┌────┐ ┌────┐ ┌────┐
│ v1 │ │ v1 │ │ v2 │
└────┘ └────┘ └────┘

Step 3: Continue rolling
┌────┐ ┌────┐ ┌────┐
│ v1 │ │ v2 │ │ v2 │
└────┘ └────┘ └────┘

Final State:
┌────┐ ┌────┐ ┌────┐
│ v2 │ │ v2 │ │ v2 │
└────┘ └────┘ └────┘
```

### Blue-Green Deployment

```
Blue (v1) - Production Traffic
┌────┐ ┌────┐ ┌────┐
│ v1 │ │ v1 │ │ v1 │  ◄── Service (100% traffic)
└────┘ └────┘ └────┘

Deploy Green (v2)
┌────┐ ┌────┐ ┌────┐
│ v1 │ │ v1 │ │ v1 │  ◄── Service (100% traffic)
└────┘ └────┘ └────┘
┌────┐ ┌────┐ ┌────┐
│ v2 │ │ v2 │ │ v2 │  (Test in isolation)
└────┘ └────┘ └────┘

Switch Traffic
┌────┐ ┌────┐ ┌────┐
│ v1 │ │ v1 │ │ v1 │  (Keep for rollback)
└────┘ └────┘ └────┘
┌────┐ ┌────┐ ┌────┐
│ v2 │ │ v2 │ │ v2 │  ◄── Service (100% traffic)
└────┘ └────┘ └────┘

Cleanup Old
┌────┐ ┌────┐ ┌────┐
│ v2 │ │ v2 │ │ v2 │  ◄── Service (100% traffic)
└────┘ └────┘ └────┘
```

### Canary Deployment

```
Initial: All v1
┌────┐ ┌────┐ ┌────┐
│ v1 │ │ v1 │ │ v1 │  ◄── Service (100%)
└────┘ └────┘ └────┘

Deploy Canary (10%)
┌────┐ ┌────┐ ┌────┐
│ v1 │ │ v1 │ │ v1 │  ◄── Service (90%)
└────┘ └────┘ └────┘
┌────┐
│ v2 │  ◄── Service (10%)
└────┘

Increase Canary (50%)
┌────┐ ┌────┐
│ v1 │ │ v1 │  ◄── Service (50%)
└────┘ └────┘
┌────┐ ┌────┐
│ v2 │ │ v2 │  ◄── Service (50%)
└────┘ └────┘

Full Rollout
┌────┐ ┌────┐ ┌────┐
│ v2 │ │ v2 │ │ v2 │  ◄── Service (100%)
└────┘ └────┘ └────┘
```

## Auto-Scaling

```
┌─────────────────────────────────────────────────────────┐
│     Horizontal Pod Autoscaler (HPA) Controller          │
└────────────────────┬────────────────────────────────────┘
                     │
                     │ Monitors
                     ▼
┌─────────────────────────────────────────────────────────┐
│              Metrics Server                              │
│  - CPU Usage                                             │
│  - Memory Usage                                          │
│  - Custom Metrics (optional)                            │
└────────────────────┬────────────────────────────────────┘
                     │
                     │ Collects from
                     ▼
┌─────────────────────────────────────────────────────────┐
│                 Service Pods                             │
│                                                          │
│  Low Load (CPU < 30%):                                  │
│  ┌────┐ ┌────┐                                          │
│  │ P1 │ │ P2 │  (Min replicas: 2)                       │
│  └────┘ └────┘                                          │
│                                                          │
│  Normal Load (CPU ~70%):                                │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐                    │
│  │ P1 │ │ P2 │ │ P3 │ │ P4 │ │ P5 │                    │
│  └────┘ └────┘ └────┘ └────┘ └────┘                    │
│                                                          │
│  High Load (CPU > 80%):                                 │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐                    │
│  │ P1 │ │ P2 │ │ P3 │ │ P4 │ │ P5 │                    │
│  └────┘ └────┘ └────┘ └────┘ └────┘                    │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐                    │
│  │ P6 │ │ P7 │ │ P8 │ │ P9 │ │P10 │  (Max: 10)         │
│  └────┘ └────┘ └────┘ └────┘ └────┘                    │
└─────────────────────────────────────────────────────────┘
```

## Multi-Environment Architecture

```
┌────────────────────────────────────────────────────────────┐
│                      Git Repository                         │
│                                                             │
│  main      ──────────────────────────────────┐             │
│  staging   ──────────────────────────┐       │             │
│  develop   ──────────────┐           │       │             │
└───────────────────────────┼───────────┼───────┼────────────┘
                            │           │       │
                            ▼           ▼       ▼
                    ┌───────────┐ ┌─────────┐ ┌──────────┐
                    │   Dev     │ │ Staging │ │   Prod   │
                    │ Namespace │ │Namespace│ │Namespace │
                    └───────────┘ └─────────┘ └──────────┘
                    
Development Environment (callcenter-dev):
- Auto-sync enabled
- Self-healing enabled
- Reduced resources
- 1-2 replicas per service
- Debug logging
- Letsencrypt staging certificates

Staging Environment (callcenter-staging):
- Auto-sync enabled
- Production-like setup
- Medium resources
- 2-3 replicas per service
- Info logging
- Letsencrypt staging certificates

Production Environment (callcenter-prod):
- Manual sync (approval required)
- High availability
- Full resources
- 3-5+ replicas per service
- Error/warning logging only
- Letsencrypt production certificates
- Pod Disruption Budgets
- Priority Classes
- Stricter network policies
```

## Summary

This architecture provides:

1. **High Availability**: Multiple replicas, health checks, auto-scaling
2. **Security**: Network policies, RBAC, TLS, secrets management
3. **Observability**: Metrics, logs, dashboards, alerts
4. **Scalability**: HPA, efficient resource usage, caching
5. **GitOps**: Declarative, version-controlled, auditable
6. **Multi-Environment**: Dev, staging, prod with appropriate configs
7. **Production-Ready**: All best practices implemented