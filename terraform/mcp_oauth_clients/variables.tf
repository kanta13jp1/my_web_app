variable "mcp_oauth_clients" {
  description = "Plan-only MCP OAuth client declarations for the future custom provider."
  type = map(object({
    client_name           = string
    redirect_uris         = list(string)
    grant_types           = optional(list(string), ["authorization_code", "refresh_token"])
    scopes                = optional(list(string), [])
    resource_indicators   = list(string)
    managed_by            = optional(string, "terraform")
    metadata_document_url = optional(string)
    reputation_score      = optional(number, 50)
    rotation_due_at       = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for client in values(var.mcp_oauth_clients) : length(client.redirect_uris) > 0
    ])
    error_message = "Each MCP OAuth client must declare at least one redirect URI."
  }

  validation {
    condition = alltrue(flatten([
      for client in values(var.mcp_oauth_clients) : [
        for uri in client.redirect_uris : startswith(uri, "https://")
      ]
    ]))
    error_message = "MCP OAuth redirect URIs must use https://."
  }

  validation {
    condition = alltrue([
      for client in values(var.mcp_oauth_clients) :
      client.reputation_score >= 0 && client.reputation_score <= 100
    ])
    error_message = "MCP OAuth reputation_score must be between 0 and 100."
  }

  validation {
    condition = alltrue([
      for client in values(var.mcp_oauth_clients) : client.managed_by == "terraform"
    ])
    error_message = "Manual MCP OAuth client declarations are not allowed here."
  }
}
