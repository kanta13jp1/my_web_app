output "mcp_oauth_client_plan" {
  description = "Normalized MCP OAuth client declarations that a future provider will upsert."
  value       = local.normalized_clients
}

output "mcp_oauth_client_count" {
  description = "Number of MCP OAuth clients in this plan."
  value       = length(local.normalized_clients)
}
