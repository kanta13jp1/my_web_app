"""Offline SDK compatibility probes; never obtains credentials or calls providers."""

import importlib
import importlib.metadata
import socket
import sys
from unittest.mock import patch


def deny_network(*args, **kwargs):
    raise AssertionError("SDK probe attempted a real network connection")


def check_root():
    from google import genai
    from supabase import create_client

    importlib.import_module("notebooklm")
    assert importlib.metadata.version("notebooklm-py")
    client = genai.Client(api_key="offline-fixture-not-a-secret")
    assert client.models is not None
    client.close()
    supabase = create_client("https://offline-fixture.invalid", "offline-fixture-not-a-secret")
    assert supabase.table("offline_fixture") is not None
    print("PASS: Google GenAI, Supabase client construction, NotebookLM import (offline)")


def check_security():
    import httpx2
    from openai import OpenAI
    from pydantic import BaseModel

    class Fixture(BaseModel):
        value: int

    assert Fixture(value="7").value == 7
    seen = []

    def respond(request):
        assert request.url.host == "offline-fixture.invalid"
        assert request.url.path == "/v1/responses"
        seen.append(request.method)
        return httpx2.Response(200, json={
            "id": "resp_fixture", "object": "response", "created_at": 0,
            "status": "completed", "model": "offline-fixture", "output": [],
        })

    with OpenAI(api_key="offline-fixture-not-a-secret", base_url="https://offline-fixture.invalid/v1",
                http_client=httpx2.Client(transport=httpx2.MockTransport(respond))) as client:
        response = client.responses.create(model="offline-fixture", input="fixture", store=False,
                                           max_output_tokens=1)
        assert response.id == "resp_fixture"
    assert seen == ["POST"]
    with OpenAI(workload_identity={"identity_provider_id": "fixture", "service_account_id": "fixture",
                                  "provider": {"token_type": "id", "get_token": deny_network}}):
        pass
    print("PASS: SDK mock Responses round-trip, Pydantic, WIF construction; no token exchange")


if __name__ == "__main__":
    profile = sys.argv[1]
    if profile not in ("root", "root-minimum", "security"):
        raise SystemExit("Unsupported profile")
    with patch.object(socket.socket, "connect", deny_network), patch.object(socket, "create_connection", deny_network):
        (check_root if profile.startswith("root") else check_security)()
