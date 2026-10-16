"""
Namecheap Passenger WSGI entry point for MediCard FastAPI backend.
Uses a synchronous WSGI wrapper around the ASGI FastAPI app.
"""
import sys
import os

# Ensure the app directory is on the path
sys.path.insert(0, os.path.dirname(__file__))

from app.main import app as fastapi_app


def application(environ, start_response):
    """
    Minimal WSGI → ASGI bridge for Passenger.
    Runs the ASGI app synchronously using asyncio.
    """
    import asyncio
    import io

    # Build ASGI scope from WSGI environ
    path = environ.get("PATH_INFO", "/")
    query = environ.get("QUERY_STRING", "")
    method = environ.get("REQUEST_METHOD", "GET")
    headers = []
    for key, value in environ.items():
        if key.startswith("HTTP_"):
            header_name = key[5:].lower().replace("_", "-")
            headers.append((header_name.encode(), value.encode()))
        elif key == "CONTENT_TYPE" and value:
            headers.append((b"content-type", value.encode()))
        elif key == "CONTENT_LENGTH" and value:
            headers.append((b"content-length", value.encode()))

    body = environ.get("wsgi.input", io.BytesIO()).read()

    scope = {
        "type": "http",
        "asgi": {"version": "3.0"},
        "http_version": "1.1",
        "method": method,
        "path": path,
        "query_string": query.encode(),
        "root_path": environ.get("SCRIPT_NAME", ""),
        "scheme": environ.get("wsgi.url_scheme", "https"),
        "server": (environ.get("SERVER_NAME", "localhost"), int(environ.get("SERVER_PORT", 443))),
        "headers": headers,
    }

    # Holders for response data
    status_holder = []
    headers_holder = []
    body_parts = []

    async def receive():
        return {"type": "http.request", "body": body, "more_body": False}

    async def send(message):
        if message["type"] == "http.response.start":
            status_holder.append(message["status"])
            headers_holder.extend(message.get("headers", []))
        elif message["type"] == "http.response.body":
            body_parts.append(message.get("body", b""))

    # Run the ASGI app
    loop = asyncio.new_event_loop()
    try:
        loop.run_until_complete(fastapi_app(scope, receive, send))
    finally:
        loop.close()

    # Build status string
    status_code = status_holder[0] if status_holder else 500
    status_map = {
        200: "200 OK", 201: "201 Created", 204: "204 No Content",
        400: "400 Bad Request", 401: "401 Unauthorized", 403: "403 Forbidden",
        404: "404 Not Found", 405: "405 Method Not Allowed",
        422: "422 Unprocessable Entity", 500: "500 Internal Server Error",
    }
    status_str = status_map.get(status_code, f"{status_code} Unknown")

    # Convert headers
    wsgi_headers = [
        (k.decode() if isinstance(k, bytes) else k,
         v.decode() if isinstance(v, bytes) else v)
        for k, v in headers_holder
    ]

    start_response(status_str, wsgi_headers)
    return [b"".join(body_parts)]
