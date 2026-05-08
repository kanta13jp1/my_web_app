mcp_oauth_clients = {
  claude_desktop = {
    client_name         = "Claude Desktop"
    redirect_uris       = ["https://claude.ai/redirect"]
    grant_types         = ["authorization_code", "refresh_token"]
    scopes              = ["mcp:tools:read"]
    resource_indicators = [
      "urn:jibun:tool:memory-search",
      "urn:jibun:tool:wbs",
    ]
    managed_by       = "terraform"
    reputation_score = 75
  }
}
