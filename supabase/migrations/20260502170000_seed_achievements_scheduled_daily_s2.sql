-- Scheduled daily-development task: 2026-05-02
-- Blog drafts (JA + EN) documenting MCP AuthKit metadata + RFC 9728 protected resource endpoint

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Blog Draft: MCP AuthKit Metadata + RFC 9728 Protected Resource Discovery',
  'Wrote JA + EN technical blog drafts (docs/blog-drafts/2026-05-02-mcp-authkit-metadata-discovery{,-en}.md) covering the MCP server discovery endpoint shipped in commit fd173222b. Documents the /.well-known/oauth-protected-resource handler in mcp_auth_guard.ts, AuthKit + WorkOS issuer ordering, RFC 8707 resource indicator audience checks, trailing-slash issuer tolerance, the WWW-Authenticate 401 challenge link to the metadata URL, and the agent_tool_policy_server_gate.sql server-side scope gate as the missing half of discovery. Drafts saved with published: false ready for editorial review.',
  '2026-05-02'
)
ON CONFLICT DO NOTHING;
