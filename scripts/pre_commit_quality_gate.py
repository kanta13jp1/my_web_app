#!/usr/bin/env python3
"""Run the fast quality gate and stamp the Git tree only after success."""

from __future__ import annotations

import sys

import no_verify_sentinel
import quality_gate


def main() -> int:
    gate_code = quality_gate.main(["--fast"])
    if gate_code != 0:
        return gate_code
    return no_verify_sentinel.mark_pre_commit()


if __name__ == "__main__":
    raise SystemExit(main())
