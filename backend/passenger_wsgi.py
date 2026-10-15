"""
Namecheap Passenger WSGI entry point for MediCard FastAPI backend.
Passenger calls the `application` callable defined here.
"""
import sys
import os

# Add the app directory to the Python path
sys.path.insert(0, os.path.dirname(__file__))

# Required for Passenger + ASGI (FastAPI) bridging
from asgiref.wsgi import WsgiToAsgi  # noqa: E402 - must be after sys.path fix

from app.main import app as fastapi_app  # noqa: E402

# Passenger expects a WSGI callable named `application`
application = WsgiToAsgi(fastapi_app)
