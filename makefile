.PHONY: all start apply-error-pages clean build-auth kind-reset load-image apply-auth helm-traefik wait-for-ready-port port-forward clean-crd clean-all wait-for-ready-pod

KIND_CLUSTER_NAME = kind
AUTH_IMAGE = auth:latest

all: start

# start: kind-reset build-auth load-image helm-traefik apply-auth wait-for-ready-pod wait-for-ready-port port-forward
start: kind-reset build-auth load-image helm-traefik apply-error-pages apply-auth wait-for-ready port-forward

kind-reset:
	@echo "[1] Resetting kind cluster..."
	@kind delete cluster || true
	@kind create cluster --config=kind-config.yaml

build-auth:
	@echo "[2] Building auth Docker image..."
	@docker build -t $(AUTH_IMAGE) ./auth

load-image:
	@echo "[3] Loading image into kind cluster..."
	@kind load docker-image $(AUTH_IMAGE)

helm-traefik:
	@echo "[4] Installing/Upgrading Traefik with Helm..."
	@helm repo add traefik https://traefik.github.io/charts || true
	@helm repo update
	@helm upgrade --install traefik traefik/traefik \
	  -n traefik --create-namespace \
	  -f traefik-values.yaml

apply-error-pages:
	@echo "[4.5] Deploying error-pages via Helm..."
	@helm upgrade --install error-pages ./charts/errors \
      --namespace default \
      --create-namespace

apply-auth: helm-traefik apply-error-pages
	@echo "[5] Deploying auth via Helm..."
	@helm upgrade --install auth ./charts/auth-app \
	  --namespace default \
	  --create-namespace

wait-for-ready:
	@echo "[6] Waiting for Traefik to be ready..."
	@kubectl wait --for=condition=available --timeout=180s deployment/traefik -n traefik
	@kubectl wait --for=condition=Ready --timeout=60s pod -l app.kubernetes.io/name=traefik -n traefik
	@echo "✓ Traefik is ready."

	@echo "[6.5] Waiting for error-pages to be ready..."
	@kubectl wait --for=condition=available --timeout=120s deployment/error-pages -n default
	@kubectl wait --for=condition=Ready --timeout=60s pod -l app.kubernetes.io/name=error-pages -n default
	@echo "✓ Error-pages is ready."

	@echo "[6.7] Waiting for auth service to be ready..."
	@kubectl wait --for=condition=available --timeout=120s deployment/auth -n default
	@kubectl wait --for=condition=Ready --timeout=60s pod -l app.kubernetes.io/name=auth -n default
	@echo "✓ Auth service is ready."

wait-for-ready-pod:
	@echo "[6] Waiting for Traefik pod to be ready..."
	@bash -c " \
	for i in {1..60}; do \
	  POD=\$$(kubectl get pod -n traefik -l app.kubernetes.io/name=traefik -o jsonpath='{.items[0].metadata.name}'); \
	  STATUS=\$$(kubectl get pod -n traefik \$$POD -o jsonpath='{.status.phase}'); \
	  if [ \"\$$STATUS\" = \"Running\" ]; then \
	    echo '\n✓ Traefik pod is running.'; \
	    break; \
	  else \
	    printf '.'; \
	    sleep 2; \
	  fi; \
	done"

wait-for-ready-port:
	@echo "[7] Waiting for Traefik service to be ready for port-forwarding..."
	@bash -c " \
    success=0; \
    for i in {1..60}; do \
      kubectl get svc -n traefik traefik >/dev/null 2>&1 || { printf '.'; sleep 2; continue; }; \
      READY=\$$(kubectl get deployment -n traefik traefik -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo '0'); \
      [ \"\$$READY\" != \"0\" ] && [ \"\$$READY\" != \"\" ] || { printf '.'; sleep 2; continue; }; \
      printf '\nTraefik service is ready for port-forwarding.\n'; \
      success=1; \
      break; \
    done; \
    [ \$$success -eq 1 ] || { printf '\nTimeout: Traefik service not ready after 120 seconds.\n'; exit 1; }"

port-forward:
	@echo "[8] Port forwarding to http://localhost:8080 (Ctrl+C to stop)..."
	@bash -c " \
	kubectl port-forward -n traefik svc/traefik 8080:8080 & \
	PORT_FORWARD_PID=\$$!; \
	trap 'kill \$$PORT_FORWARD_PID' EXIT; \
	wait \$$PORT_FORWARD_PID"

clean:
	@echo "[0.1] Uninstalling auth app..."
	@helm uninstall auth -n default || true
	@echo "✓ Removed auth Helm release."

	@echo "[0.1.5] Uninstalling error-pages..."
	@helm uninstall error-pages -n default || true
	@echo "✓ Removed error-pages Helm release."

	@echo "[0.2] Uninstalling Traefik..."
	@helm uninstall traefik -n traefik || true
	@kubectl delete namespace traefik --ignore-not-found
	@echo "✓ Removed Traefik Helm release and namespace."

	@echo "[0.3] Deleting kind cluster..."
	@kind delete cluster || true
	@echo "✓ Kind cluster deleted."

	@echo "[0.4] Removing local Docker image..."
	@docker rmi $(AUTH_IMAGE) || true
	@echo "✓ Docker image removed."

clean-crd:
	@echo "[CLEAN-CRD] Deleting leftover Traefik CRDs..."
	-kubectl delete crd ingressroutes.traefik.io --ignore-not-found
	-kubectl delete crd middlewares.traefik.io --ignore-not-found

clean-all: clean clean-crd
	@echo "[CLEAN-ALL] Completed full cleanup."