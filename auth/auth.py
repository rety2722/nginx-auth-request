from flask import Flask, request, Response

app = Flask(__name__)

VALID_TOKEN = "valid-token"


@app.route("/auth")
def auth():
    app.logger.info(f"Processing request to /auth")
    # Get the x-pretest header from the request
    auth_header = request.headers.get("x-pretest")

    # Check if the header exists and has a valid value
    if auth_header and auth_header == VALID_TOKEN:
        # Authentication succeeded
        app.logger.info(f"Auth successful with token: {auth_header}")
        return Response(status=200)
    else:
        # Authentication failed
        app.logger.warning(f"Auth failed with token: {auth_header}")
        return Response(status=401)


@app.route("/health")
def health_check():
    """Simple health check endpoint"""
    return "Auth service is running\n", 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
