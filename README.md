# Nginx Auth Request Demo

This project is a final version of migration from nginx to using traefik. It works for me. Hopefully, it works for you:)

## Dependencies and Assumptions

To run the project, it would be necessary to install the following:

1. **helm**: https://helm.sh/. Package manager for kubernetes. Greatly simplifies the development.
2. **kind**: https://kind.sigs.k8s.io/. This is used to configure the kubernetes context.
3. **make**: https://www.gnu.org/software/make/. The build system for this project. Can be substituted \
   to any other build system if necessary.

If there is a need to use another cluster context, like minikube, the makefile would need to be adjusted. \
It is assumed that docker and kubernetes are present on the system and are started and the user configures the context \
by themselves.

## Architecture

Briefly: does the same with gateway by traefik. IngressRoute handles internal routing and api access \
(/auth and /health are hidden from the external requests)

The setup consists of these services deployed on Kubernetes:

### 1. **Auth Service**

- **Technology**: Flask application (Python)
- **Purpose**: Validates the `x-pretest` header for authentication
- **Deployment**: Custom Helm chart (`./charts/auth-app`)
- **Image**: Built locally from `./auth` directory
- **Endpoints**:
  - `/auth` - Authentication endpoint (returns 200/401)
  - `/health` - Health check endpoint
- **Namespace**: `default`

### 2. **Traefik (API Gateway)**

- **Technology**: Traefik v3 proxy
- **Purpose**: Acts as the main entry point and reverse proxy
- **Deployment**: Official Traefik Helm chart
- **Configuration**: `traefik-values.yaml`
- **Namespace**: `traefik`
- **Features**:
  - Automatic service discovery
  - Middleware management

### 3. **Error Pages Service**

- **Technology**: Nginx serving static error pages
- **Purpose**: Provides custom error responses for authentication failures
- **Deployment**: Custom Helm chart (`./charts/errors`)
- **Image**: `nginx:alpine`
- **Namespace**: `default`
- **Error Codes**: 400, 401, 403, 404, 500, 502, 503

### 4. **Traefik Middlewares**

The system uses three key Traefik middlewares:

#### **Auth Request Middleware**
- **Name**: `auth-request`
- **Type**: ForwardAuth
- **Purpose**: Forwards requests to auth service for validation
- **Target**: `http://auth.default.svc.cluster.local:5000/auth`

#### **Error Pages Middleware**
- **Name**: `error-pages`
- **Type**: Errors
- **Purpose**: Redirects failed requests to custom error pages
- **Target**: `http://error-pages.default.svc.cluster.local:80`

#### **Path Rewrite Middleware**
- **Name**: `rewrite-to-health`
- **Type**: ReplacePath
- **Purpose**: Rewrites successful requests to health endpoint
- **Target**: `/health`

### 5. **IngressRoute Configuration**

The system uses Traefik's **IngressRoute** CRD for advanced routing capabilities:

#### **Advanced Routing Features**
- **Custom Resource Definition**: Uses Traefik's native CRDs instead of standard Kubernetes Ingress
- **Middleware Chaining**: Applies multiple middlewares in sequence (auth → error handling → path rewrite)
- **Internal Route Protection**: Prevents direct external access to `/auth` and `/health` endpoints
- **Service Discovery**: Automatically routes to Kubernetes services using DNS names
- **Flexible Matching**: Supports complex routing rules beyond simple path matching

#### **Route Configuration**
```yaml
# IngressRoute handles all external traffic
spec:
  entryPoints:
    - web  # Port 8080
  middlewares:
    - auth-request      # 1st: Authenticate request
    - error-pages       # 2nd: Handle auth failures  
    - rewrite-to-health # 3rd: Rewrite successful requests
  routes:
    - match: PathPrefix(`/`)
      kind: Rule
      services:
        - name: auth
          port: 5000
```

#### **Security Benefits**
- **Endpoint Isolation**: `/auth` and `/health` are only accessible internally via middleware
- **Request Validation**: All external requests must pass through authentication chain
- **Error Handling**: Failed authentication shows custom error pages instead of exposing service details
- **Service Mesh Integration**: Works seamlessly with Kubernetes service discovery

### **Request Flow**

```
Client Request
      ↓
   Traefik (Port 8080)
      ↓
[IngressRoute Matching]
      ↓
[Auth Request Middleware]
      ↓
Auth Service (/auth endpoint) - INTERNAL ONLY
      ↓
Authentication Check
      ├─ Valid Token → Continue
      └─ Invalid/Missing → Error Pages Service
      ↓
[Rewrite Middleware]
      ↓
Auth Service (/health endpoint) - INTERNAL ONLY
      ↓
Response to Client
```

**Key Difference from Standard Ingress**: IngressRoute allows sophisticated middleware chaining and internal routing that standard Kubernetes Ingress cannot achieve, making it ideal for auth_request patterns.

## Valid Authentication

A valid request must include the header: `x-pretest: valid-token`

## Running the Demo

```bash
make start
```

or

```bash
make clean && make start
```

## Testing

Can be tested manually after the startup:

```bash
# Valid request
curl -H "x-pretest: valid-token" http://localhost:8080

# Invalid request
curl -H "x-pretest: wrong-token" http://localhost:8080

# Missing header
curl http://localhost:8080
```
