.PHONY: all start apply-error-pages clean docker-build-auth kind-reset kind-load-image apply-auth helm-traefik port-forward clean-crd clean-all wait-for-ready docker-build-all kind-create

KIND_CLUSTER_NAME = kind
KIND_CONFIG_FILE = kind-config.yaml

AUTH_IMAGE = auth:latest
AUTH_IMAGE_DIR = ./auth

all: start

start: docker-build-auth kind-reset kind-load-image helm-traefik apply-error-pages apply-auth wait-for-ready port-forward

# ==== Docker build ====
docker-build-all: docker-build-auth

docker-build-auth:
	@echo "Building auth Docker image..."
	@docker build -t $(AUTH_IMAGE) $(AUTH_IMAGE_DIR)

# ==== kind context management ====
kind-reset:
	@echo "Resetting kind cluster..."
	@kind delete cluster --name $(KIND_CLUSTER_NAME) || true
	@kind create cluster --name $(KIND_CLUSTER_NAME) --config=$(KIND_CONFIG_FILE)
	@kubectl config use-context kind-$(KIND_CLUSTER_NAME)
	@echo "✓ Setting kubectl context to new cluster..."
	@kubectl cluster-info --context kind-$(KIND_CLUSTER_NAME)

kind-create:
	@echo "Creating kind cluster..."
	@kind create cluster --name $(KIND_CLUSTER_NAME) --config=$(KIND_CONFIG_FILE)
	@echo "✓ Setting kubectl context to new cluster..."
	@kubectl config use-context kind-$(KIND_CLUSTER_NAME)
	@kubectl cluster-info --context kind-$(KIND_CLUSTER_NAME)

kind-load-image:
	@echo "Loading image into kind cluster..."
	@kind load docker-image $(AUTH_IMAGE) --name $(KIND_CLUSTER_NAME)

# ==== helm deployments ====
helm-traefik:
	@echo "Installing/Upgrading Traefik with Helm..."
	@helm repo add traefik https://traefik.github.io/charts || true
	@helm repo update
	@helm upgrade --install traefik traefik/traefik \
	  -n traefik --create-namespace \
	  -f traefik-values.yaml

apply-error-pages:
	@echo "Deploying error-pages via Helm..."
	@helm upgrade --install error-pages ./charts/errors \
      --namespace default \
      --create-namespace

apply-auth: helm-traefik apply-error-pages
	@echo "Deploying auth via Helm..."
	@helm upgrade --install auth ./charts/auth-app \
	  --namespace default \
	  --create-namespace

# ==== Wait for readiness ====
wait-for-ready:
	@echo "Waiting for Traefik to be ready..."
	@kubectl wait --for=condition=available --timeout=180s deployment/traefik -n traefik
	@kubectl wait --for=condition=Ready --timeout=60s pod -l app.kubernetes.io/name=traefik -n traefik
	@echo "✓ Traefik is ready."

	@echo "Waiting for error-pages to be ready..."
	@kubectl wait --for=condition=available --timeout=120s deployment/error-pages -n default
	@kubectl wait --for=condition=Ready --timeout=60s pod -l app.kubernetes.io/name=error-pages -n default
	@echo "✓ Error-pages is ready."

	@echo "Waiting for auth service to be ready..."
	@kubectl wait --for=condition=available --timeout=120s deployment/auth -n default
	@kubectl wait --for=condition=Ready --timeout=60s pod -l app.kubernetes.io/name=auth -n default
	@echo "✓ Auth service is ready."

# ==== Port forwarding ====
port-forward:
	@echo "Port forwarding to http://localhost:8080 (Ctrl+C to stop)..."
	@bash -c " \
	kubectl port-forward -n traefik svc/traefik 8080:8080 & \
	PORT_FORWARD_PID=\$$!; \
	trap 'kill \$$PORT_FORWARD_PID' EXIT; \
	wait \$$PORT_FORWARD_PID"

clean:
	@echo "Uninstalling auth app..."
	@helm uninstall auth -n default || true
	@echo "✓ Removed auth Helm release."

	@echo "Uninstalling error-pages..."
	@helm uninstall error-pages -n default || true
	@echo "✓ Removed error-pages Helm release."

	@echo "Uninstalling Traefik..."
	@helm uninstall traefik -n traefik || true
	@kubectl delete namespace traefik --ignore-not-found
	@echo "✓ Removed Traefik Helm release and namespace."

	@echo "Deleting kind cluster..."
	@kind delete cluster --name $(KIND_CLUSTER_NAME) || true
	@echo "✓ Kind cluster deleted."
	@echo "⚠️  kubectl context may need to be reset. Run 'make start' to recreate cluster."

	@echo "Removing local Docker image..."
	@docker rmi $(AUTH_IMAGE) || true
	@echo "✓ Docker image removed."

clean-crd:
	@echo "[CLEAN-CRD] Deleting leftover Traefik CRDs..."
	-kubectl delete crd ingressroutes.traefik.io --ignore-not-found
	-kubectl delete crd middlewares.traefik.io --ignore-not-found

clean-all: clean clean-crd
	@echo "[CLEAN-ALL] Completed full cleanup."