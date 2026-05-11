#!/usr/bin/env python3
"""Tiny read-only JSON-RPC stdio fixture for the MCP isolation smoke."""

from __future__ import annotations

import json
import os
import sys
from typing import Any


SERVER_ID = os.environ.get("MCP_SERVER_ID", "low-risk-stdio-poc")


def response(request_id: Any, result: dict[str, Any]) -> dict[str, Any]:
    return {"jsonrpc": "2.0", "id": request_id, "result": result}


def error(request_id: Any, code: int, message: str) -> dict[str, Any]:
    return {"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}}


def handle(message: dict[str, Any]) -> dict[str, Any]:
    method = str(message.get("method", ""))
    request_id = message.get("id")

    if method == "initialize":
        return response(
            request_id,
            {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": SERVER_ID, "version": "1.0.0"},
            },
        )

    if method == "tools/list":
        return response(
            request_id,
            {
                "tools": [
                    {
                        "name": "echo.ping",
                        "description": "Read-only smoke tool for container isolation.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "message": {"type": "string"},
                            },
                            "additionalProperties": False,
                        },
                    }
                ]
            },
        )

    if method == "tools/call":
        params = message.get("params") if isinstance(message.get("params"), dict) else {}
        if params.get("name") != "echo.ping":
            return error(request_id, -32602, "unknown tool")
        arguments = params.get("arguments") if isinstance(params.get("arguments"), dict) else {}
        text = str(arguments.get("message", "pong"))
        return response(
            request_id,
            {
                "content": [
                    {
                        "type": "text",
                        "text": f"{SERVER_ID}: {text}",
                    }
                ],
                "isError": False,
            },
        )

    return error(request_id, -32601, f"unsupported method: {method}")


def main() -> int:
    for raw_line in sys.stdin:
        line = raw_line.strip()
        if not line:
            continue
        try:
            message = json.loads(line)
        except json.JSONDecodeError as exc:
            print(json.dumps(error(None, -32700, f"parse error: {exc}")), flush=True)
            continue
        print(json.dumps(handle(message), separators=(",", ":")), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
