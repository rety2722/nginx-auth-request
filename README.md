# Nginx Auth Request Demo

This project demonstrates how to use Nginx's `auth_request` module to authenticate requests based on HTTP headers.

## Architecture

The setup consists of three services:

2. **Auth**: A Flask service that validates the `x-pretest` header.
3. **Nginx**: Acts as a gateway, using `auth_request` to validate incoming requests.

## How it works

1. The client sends requests to Nginx with or without the `x-pretest` header
2. Nginx forwards the authentication headers to the auth service
3. The auth service checks if the `x-pretest` header contains a valid token
4. If authentication succeeds, Nginx processes the request; otherwise, it returns a 401 error

## Valid Authentication

A valid request must include the header: `x-pretest: valid-token`

## Running the Demo

```bash
docker-compose up --build
```

## Testing

You can test manually:

```bash
# Valid request
curl -H "x-pretest: valid-token" http://localhost:8080

# Invalid request
curl -H "x-pretest: wrong-token" http://localhost:8080

# Missing header
curl http://localhost:8080
``` 