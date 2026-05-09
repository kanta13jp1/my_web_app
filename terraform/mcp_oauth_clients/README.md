# MCP OAuth Clients Terraform Skeleton

Issue #1577 Phase C prepares the Terraform source-of-truth shape for MCP OAuth
clients. This directory is intentionally plan-only: it validates client metadata
and produces a normalized plan summary, but it does not write to Supabase yet.
The custom provider/apply path will be added in a later PR after the provider
contract is reviewed.

## Local Plan

```bash
terraform init -backend=false
terraform validate
terraform plan -input=false -lock=false -var-file=examples/clients.tfvars
```

## Rules

- `managed_by` must stay `terraform`.
- Every client needs at least one HTTPS redirect URI.
- Every client needs at least one Resource Indicator.
- `reputation_score` stays in the 0-100 range.
- `metadata_document_url` is optional and represents the future CIMD migration
  path; `null` means Phase 1 DCR.

`terraform apply` is intentionally not wired. Manual SQL inserts into
`mcp_oauth_clients` remain outside the desired operating model.
