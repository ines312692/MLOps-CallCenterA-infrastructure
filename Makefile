.PHONY: help install-tools setup-argocd deploy-dev deploy-staging deploy-prod \
        validate-dev validate-staging validate-prod clean-dev clean-staging clean-prod \
        scale-up scale-down logs status port-forward helm-install helm-upgrade \
        backup restore test-connectivity

# Variables
KUBECTL := kubectl
HELM := helm
KUSTOMIZE := kustomize
ARGOCD := argocd
NAMESPACE_DEV := callcenter-dev
NAMESPACE_STAGING := callcenter-staging
NAMESPACE_PROD := callcenter-prod

# Colors
GREEN  := \033[0;32m
YELLOW := \033[1;33m
RED    := \033[0;31m
NC     := \033[0m

help: ## Show this help message
	@echo '$(GREEN)MLOps CallCenter AI - Infrastructure Management$(NC)'
	@echo ''
	@echo 'Usage:'
	@echo '  make $(YELLOW)<target>$(NC)'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install-tools: ## Install required tools (kubectl, helm, kustomize, argocd)
	@echo "$(GREEN)Installing required tools...$(NC)"
	@command -v kubectl >/dev/null 2>&1 || { echo "Installing kubectl..."; curl -LO "https://dl.k8s.io/release/$$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl; }
	@command -v helm >/dev/null 2>&1 || { echo "Installing helm..."; curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash; }
	@command -v kustomize >/dev/null 2>&1 || { echo "Installing kustomize..."; curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash && sudo mv kustomize /usr/local/bin/; }
	@command -v argocd >/dev/null 2>&1 || { echo "Installing argocd CLI..."; curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && sudo install -m 555 argocd /usr/local/bin/argocd; }
	@echo "$(GREEN)All tools installed!$(NC)"

setup-argocd: ## Install and configure ArgoCD
	@echo "$(GREEN)Setting up ArgoCD...$(NC)"
	@bash scripts/setup-argocd.sh

validate-dev: ## Validate development manifests
	@echo "$(GREEN)Validating development manifests...$(NC)"
	@$(KUBECTL) apply --dry-run=client -k k8s/overlays/dev

validate-staging: ## Validate staging manifests
	@echo "$(GREEN)Validating staging manifests...$(NC)"
	@$(KUBECTL) apply --dry-run=client -k k8s/overlays/staging

validate-prod: ## Validate production manifests
	@echo "$(GREEN)Validating production manifests...$(NC)"
	@$(KUBECTL) apply --dry-run=client -k k8s/overlays/prod

deploy-dev: validate-dev ## Deploy to development environment
	@echo "$(GREEN)Deploying to development...$(NC)"
	@bash scripts/deploy.sh --environment dev

deploy-staging: validate-staging ## Deploy to staging environment
	@echo "$(GREEN)Deploying to staging...$(NC)"
	@bash scripts/deploy.sh --environment staging

deploy-prod: validate-prod ## Deploy to production environment
	@echo "$(YELLOW)Deploying to production...$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		bash scripts/deploy.sh --environment prod; \
	else \
		echo "$(RED)Deployment cancelled$(NC)"; \
	fi

clean-dev: ## Clean development environment
	@echo "$(RED)Cleaning development environment...$(NC)"
	@$(KUBECTL) delete namespace $(NAMESPACE_DEV) --ignore-not-found=true

clean-staging: ## Clean staging environment
	@echo "$(RED)Cleaning staging environment...$(NC)"
	@$(KUBECTL) delete namespace $(NAMESPACE_STAGING) --ignore-not-found=true

clean-prod: ## Clean production environment (with confirmation)
	@echo "$(RED)Cleaning production environment...$(NC)"
	@read -p "$(RED)This will DELETE the production environment. Are you ABSOLUTELY sure? Type 'DELETE' to confirm: $(NC)" confirm; \
	if [ "$$confirm" = "DELETE" ]; then \
		$(KUBECTL) delete namespace $(NAMESPACE_PROD) --ignore-not-found=true; \
	else \
		echo "$(GREEN)Cleanup cancelled$(NC)"; \
	fi

status: ## Show status of all environments
	@echo "$(GREEN)=== Development Environment ===$(NC)"
	@$(KUBECTL) get all -n $(NAMESPACE_DEV) 2>/dev/null || echo "Not deployed"
	@echo ""
	@echo "$(GREEN)=== Staging Environment ===$(NC)"
	@$(KUBECTL) get all -n $(NAMESPACE_STAGING) 2>/dev/null || echo "Not deployed"
	@echo ""
	@echo "$(GREEN)=== Production Environment ===$(NC)"
	@$(KUBECTL) get all -n $(NAMESPACE_PROD) 2>/dev/null || echo "Not deployed"

logs: ## Show logs from services (usage: make logs ENV=dev SERVICE=agent-service)
	@if [ -z "$(ENV)" ] || [ -z "$(SERVICE)" ]; then \
		echo "$(RED)Usage: make logs ENV=dev SERVICE=agent-service$(NC)"; \
		exit 1; \
	fi
	@$(KUBECTL) logs -f -l component=$(SERVICE) -n callcenter-$(ENV)

logs-dev-agent: ## Show logs from development agent service
	@$(KUBECTL) logs -f -l component=agent-service -n $(NAMESPACE_DEV)

logs-prod-agent: ## Show logs from production agent service
	@$(KUBECTL) logs -f -l component=agent-service -n $(NAMESPACE_PROD)

scale-up: ## Scale up services (usage: make scale-up ENV=dev SERVICE=agent-service REPLICAS=5)
	@if [ -z "$(ENV)" ] || [ -z "$(SERVICE)" ] || [ -z "$(REPLICAS)" ]; then \
		echo "$(RED)Usage: make scale-up ENV=dev SERVICE=agent-service REPLICAS=5$(NC)"; \
		exit 1; \
	fi
	@$(KUBECTL) scale deployment/$(SERVICE) --replicas=$(REPLICAS) -n callcenter-$(ENV)
	@echo "$(GREEN)Scaled $(SERVICE) to $(REPLICAS) replicas in callcenter-$(ENV)$(NC)"

scale-down: ## Scale down services to minimum (usage: make scale-down ENV=dev)
	@if [ -z "$(ENV)" ]; then \
		echo "$(RED)Usage: make scale-down ENV=dev$(NC)"; \
		exit 1; \
	fi
	@$(KUBECTL) scale deployment/agent-service --replicas=1 -n callcenter-$(ENV)
	@$(KUBECTL) scale deployment/tfidf-service --replicas=1 -n callcenter-$(ENV)
	@$(KUBECTL) scale deployment/transformer-service --replicas=1 -n callcenter-$(ENV)
	@echo "$(GREEN)Scaled down all services in callcenter-$(ENV)$(NC)"

port-forward-dev: ## Port forward development services
	@echo "$(GREEN)Port forwarding development services...$(NC)"
	@echo "Agent API: http://localhost:8000"
	@echo "MLflow: http://localhost:5000"
	@echo "Prometheus: http://localhost:9090"
	@echo "Grafana: http://localhost:3000"
	@$(KUBECTL) port-forward svc/agent-service 8000:8000 -n $(NAMESPACE_DEV) & \
	$(KUBECTL) port-forward svc/mlflow 5000:5000 -n $(NAMESPACE_DEV) & \
	$(KUBECTL) port-forward svc/prometheus 9090:9090 -n $(NAMESPACE_DEV) & \
	$(KUBECTL) port-forward svc/grafana 3000:3000 -n $(NAMESPACE_DEV) &
	@echo "$(YELLOW)Press Ctrl+C to stop port forwarding$(NC)"

port-forward-prod: ## Port forward production services (read-only)
	@echo "$(GREEN)Port forwarding production services...$(NC)"
	@echo "Agent API: http://localhost:8000"
	@echo "MLflow: http://localhost:5000"
	@echo "Prometheus: http://localhost:9090"
	@echo "Grafana: http://localhost:3000"
	@$(KUBECTL) port-forward svc/agent-service 8000:8000 -n $(NAMESPACE_PROD) & \
	$(KUBECTL) port-forward svc/mlflow 5000:5000 -n $(NAMESPACE_PROD) & \
	$(KUBECTL) port-forward svc/prometheus 9090:9090 -n $(NAMESPACE_PROD) & \
	$(KUBECTL) port-forward svc/grafana 3000:3000 -n $(NAMESPACE_PROD) &
	@echo "$(YELLOW)Press Ctrl+C to stop port forwarding$(NC)"

helm-install-dev: ## Install using Helm (development)
	@echo "$(GREEN)Installing with Helm (development)...$(NC)"
	@$(HELM) upgrade --install callcenter-ai ./helm/callcenter-ai \
		--namespace $(NAMESPACE_DEV) \
		--create-namespace \
		--values ./helm/callcenter-ai/values-dev.yaml

helm-install-prod: ## Install using Helm (production)
	@echo "$(GREEN)Installing with Helm (production)...$(NC)"
	@$(HELM) upgrade --install callcenter-ai ./helm/callcenter-ai \
		--namespace $(NAMESPACE_PROD) \
		--create-namespace \
		--values ./helm/callcenter-ai/values-prod.yaml

helm-upgrade-dev: ## Upgrade using Helm (development)
	@echo "$(GREEN)Upgrading with Helm (development)...$(NC)"
	@$(HELM) upgrade callcenter-ai ./helm/callcenter-ai \
		--namespace $(NAMESPACE_DEV) \
		--values ./helm/callcenter-ai/values-dev.yaml

helm-upgrade-prod: ## Upgrade using Helm (production)
	@echo "$(YELLOW)Upgrading with Helm (production)...$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(HELM) upgrade callcenter-ai ./helm/callcenter-ai \
			--namespace $(NAMESPACE_PROD) \
			--values ./helm/callcenter-ai/values-prod.yaml; \
	else \
		echo "$(RED)Upgrade cancelled$(NC)"; \
	fi

test-connectivity: ## Test connectivity between services (usage: make test-connectivity ENV=dev)
	@if [ -z "$(ENV)" ]; then \
		echo "$(RED)Usage: make test-connectivity ENV=dev$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Testing connectivity in callcenter-$(ENV)...$(NC)"
	@$(KUBECTL) run -it --rm debug --image=curlimages/curl --restart=Never -n callcenter-$(ENV) -- \
		sh -c "curl -s http://agent-service:8000/health && echo '\nAgent service: OK' || echo '\nAgent service: FAIL'"

top: ## Show resource usage (usage: make top ENV=dev)
	@if [ -z "$(ENV)" ]; then \
		echo "$(RED)Usage: make top ENV=dev$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Resource usage in callcenter-$(ENV):$(NC)"
	@$(KUBECTL) top pods -n callcenter-$(ENV)

events: ## Show recent events (usage: make events ENV=dev)
	@if [ -z "$(ENV)" ]; then \
		echo "$(RED)Usage: make events ENV=dev$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Recent events in callcenter-$(ENV):$(NC)"
	@$(KUBECTL) get events -n callcenter-$(ENV) --sort-by='.lastTimestamp' | tail -20

describe: ## Describe a resource (usage: make describe ENV=dev TYPE=pod NAME=agent-service-xxx)
	@if [ -z "$(ENV)" ] || [ -z "$(TYPE)" ] || [ -z "$(NAME)" ]; then \
		echo "$(RED)Usage: make describe ENV=dev TYPE=pod NAME=agent-service-xxx$(NC)"; \
		exit 1; \
	fi
	@$(KUBECTL) describe $(TYPE) $(NAME) -n callcenter-$(ENV)

backup: ## Backup Kubernetes resources (usage: make backup ENV=dev)
	@if [ -z "$(ENV)" ]; then \
		echo "$(RED)Usage: make backup ENV=dev$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Backing up callcenter-$(ENV)...$(NC)"
	@mkdir -p backups/$(ENV)
	@$(KUBECTL) get all,configmap,secret,pvc,ingress -n callcenter-$(ENV) -o yaml > backups/$(ENV)/backup-$$(date +%Y%m%d-%H%M%S).yaml
	@echo "$(GREEN)Backup saved to backups/$(ENV)/$(NC)"

argocd-sync-dev: ## Sync ArgoCD application (development)
	@echo "$(GREEN)Syncing ArgoCD application (development)...$(NC)"
	@$(ARGOCD) app sync callcenter-ai-dev

argocd-sync-prod: ## Sync ArgoCD application (production)
	@echo "$(YELLOW)Syncing ArgoCD application (production)...$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(ARGOCD) app sync callcenter-ai-prod; \
	else \
		echo "$(RED)Sync cancelled$(NC)"; \
	fi

argocd-status: ## Show ArgoCD application status
	@echo "$(GREEN)ArgoCD Application Status:$(NC)"
	@$(ARGOCD) app list

clean-all: clean-dev clean-staging clean-prod ## Clean all environments
	@echo "$(RED)All environments cleaned$(NC)"