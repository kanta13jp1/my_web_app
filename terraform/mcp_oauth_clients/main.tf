terraform {
  required_version = ">= 1.6.0"
}

locals {
  normalized_clients = {
    for key, client in var.mcp_oauth_clients : key => {
      client_name           = client.client_name
      redirect_uris         = client.redirect_uris
      grant_types           = client.grant_types
      scopes                = client.scopes
      resource_indicators   = client.resource_indicators
      managed_by            = client.managed_by
      metadata_document_url = client.metadata_document_url
      reputation_score      = client.reputation_score
      rotation_due_at       = client.rotation_due_at
    }
  }
}

check "terraform_managed_only" {
  assert {
    condition = alltrue([
      for client in values(var.mcp_oauth_clients) : client.managed_by == "terraform"
    ])
    error_message = "MCP OAuth clients must be managed_by=terraform."
  }
}

check "resource_indicators_required" {
  assert {
    condition = alltrue([
      for client in values(var.mcp_oauth_clients) : length(client.resource_indicators) > 0
    ])
    error_message = "Each MCP OAuth client must declare at least one Resource Indicator."
  }
}
