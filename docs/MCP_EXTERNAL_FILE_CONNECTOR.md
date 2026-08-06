# External MCP File Connector

`tools-hub` exposes authenticated actions for searching explicitly configured
MCP file servers and attaching selected content to `my_agent.chat`.

## Supabase secrets

Configure both secrets. An empty connector list disables the feature without
exposing an endpoint or token to Flutter.

```text
MCP_FILE_CONNECTOR_ALLOWED_HOSTS=mcp.example.com
MCP_FILE_CONNECTORS_JSON=[{"id":"company-drive","name":"Company Drive","endpoint_url":"https://mcp.example.com/mcp","search_tool":"files.search","fetch_tool":"files.get","bearer_token":"replace-with-secret","allowed_user_ids":["00000000-0000-4000-8000-000000000000"],"acl_mode":"metadata"}]
```

Connector requirements:

- `endpoint_url` must use HTTPS and its hostname must be in
  `MCP_FILE_CONNECTOR_ALLOWED_HOSTS`.
- `allowed_user_ids` must contain explicit Supabase Auth UUIDs. Access is
  denied when the list is absent or the caller is not listed.
- `acl_mode: metadata` requires each search and fetch result to contain the
  caller in `owner_user_id`, `user_id`, or `allowed_user_ids`, unless the
  result has `visibility: public`.
- `acl_mode: user_scoped` is allowed only for a connector assigned to exactly
  one user. The upstream MCP server must already scope that connection.
- Keep `bearer_token` only in Supabase secrets. The connectors action returns
  neither the token nor the endpoint URL.

## MCP tool response contract

The search tool receives `query`, `limit`, and `user_id`. The fetch tool
receives `id`, `file_id`, `uri`, and `user_id`. Tool results may use MCP
`structuredContent` or JSON text content and should return these fields:

```json
{
  "results": [
    {
      "id": "file-123",
      "title": "Roadmap.md",
      "uri": "mcp://company-drive/file-123",
      "mime_type": "text/markdown",
      "snippet": "Quarterly delivery plan",
      "content": "Full content is required on fetch responses",
      "allowed_user_ids": ["00000000-0000-4000-8000-000000000000"]
    }
  ]
}
```

`tools-hub` repeats the authorization and security scan when content is
fetched. It stores at most 24,000 characters in a user-owned `hub_data` row.
Flutter passes only that row ID to `ai-hub`; `ai-hub` then rechecks ownership
and safety metadata before adding the content as untrusted user data.
