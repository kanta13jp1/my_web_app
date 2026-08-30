#!/usr/bin/env python3
"""Validate Flutter's public Supabase environment without logging values."""

from __future__ import annotations

import base64
import json
import os

from render_web_supabase_config import normalize_public_url


def legacy_jwt_role(key: str) -> str | None:
    segments = key.split(".")
    if len(segments) != 3:
        return None
    try:
        payload_segment = segments[1] + "=" * (-len(segments[1]) % 4)
        payload = json.loads(base64.urlsafe_b64decode(payload_segment))
    except (ValueError, json.JSONDecodeError):
        return None
    role = payload.get("role") if isinstance(payload, dict) else None
    return role if isinstance(role, str) else None


def validate_publishable_key(raw_key: str) -> None:
    key = raw_key.strip()
    if not key:
        raise ValueError("SUPABASE_PUBLISHABLE_KEY is required.")
    if key.startswith("sb_secret_"):
        raise ValueError("A server-only Supabase secret key cannot be used by Flutter.")
    role = legacy_jwt_role(key)
    if role == "service_role":
        raise ValueError("A legacy service_role JWT cannot be used by Flutter.")
    if not key.startswith("sb_publishable_") and role != "anon":
        raise ValueError(
            "Flutter requires an sb_publishable_ key or a legacy anon JWT during migration."
        )


def validate_environment(url: str, publishable_key: str) -> None:
    normalize_public_url(url)
    validate_publishable_key(publishable_key)


def main() -> int:
    try:
        validate_environment(
            os.environ.get("SUPABASE_URL", ""),
            os.environ.get("SUPABASE_PUBLISHABLE_KEY", ""),
        )
    except ValueError as error:
        print(f"Flutter Supabase environment is invalid: {error}")
        return 1
    print("Flutter Supabase environment is valid (values redacted).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
