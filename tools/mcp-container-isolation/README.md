# MCP Container Isolation PoC

Issue #1645 uses this low-risk stdio MCP fixture to prove that an MCP server can
launch without host network access, host secrets, published ports, or writable
root filesystem assumptions.

Local contract validation:

```powershell
python scripts/check_mcp_container_isolation.py
python scripts/check_mcp_container_isolation_test.py
```

Docker launch smoke when Docker is available:

```powershell
python scripts/check_mcp_container_isolation.py --run-docker --require-docker
```

The Docker path builds `mcp-low-risk-poc` and sends
`tools/mcp-container-isolation/fixtures/smoke.jsonl` to the container over
stdio. The service uses `network_mode: none`, `read_only: true`, drops all
Linux capabilities, and has no ports or host credential mounts.
