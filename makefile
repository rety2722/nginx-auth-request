.PHONY: all start clean build-auth kind-reset load-image apply-auth helm-traefik wait-for-ready port-forward clean-crd clean-all

KIND_CLUSTER_NAME = kind
AUTH_IMAGE = auth:latest

all: start

start: kind-reset build-auth load-image apply-auth helm-traefik wait-for-ready port-forward

kind-reset:
	@echo "[1] Resetting kind cluster..."
	kind delete cluster || true
	kind create cluster --config=kind-config.yaml

build-auth:
	@echo "[2] Building auth Docker image..."
	cd ./auth && docker build -t $(AUTH_IMAGE) . && cd ..

load-image:
	@echo "[3] Loading image into kind cluster..."
	kind load docker-image $(AUTH_IMAGE)

helm-traefik:
	@echo "[4] Installing/Upgrading Traefik with Helm..."
	helm repo add traefik https://traefik.github.io/charts || true
	helm repo update
	helm upgrade --install traefik traefik/traefik \
	  -n traefik --create-namespace \
	  -f traefik/chart/values.yaml

apply-auth: helm-traefik
	@echo "[5] Deploying auth via Helm..."
	helm upgrade --install auth ./auth/chart \
	  --namespace default \
	  --create-namespace

wait-for-ready:
	@echo "[6] Waiting for http://localhost:8080 to be ready..."
	@bash -c " \
	success=0; \
	for i in {1..40}; do \
	  if curl -s -o /dev/null http://localhost:8080; then \
	    printf '\nService is ready.\n'; \
	    success=1; \
	    break; \
	  else \
	    printf '.'; \
	    sleep 2; \
	  fi; \
	done; \
	if [ $$success -eq 0 ]; then \
	  printf '\nTimeout: Service not ready after 80 seconds.\n'; \
	  exit 1; \
	fi"

port-forward:
	@echo "[7] Port forwarding to http://localhost:8080 (Ctrl+C to stop)..."
	@bash -c " \
	kubectl port-forward -n traefik svc/traefik 8080:8080 & \
	PORT_FORWARD_PID=\$$!; \
	trap 'kill \$$PORT_FORWARD_PID' EXIT; \
	wait \$$PORT_FORWARD_PID"

clean:
	@echo "[0.1] Uninstalling auth app..."
	@helm uninstall auth -n default || true
	@echo "✓ Removed auth Helm release."

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