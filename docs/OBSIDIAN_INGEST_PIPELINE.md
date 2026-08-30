# Obsidian Ingest Pipeline

Issue: [#974](https://github.com/kanta13jp1/my_web_app/issues/974)

This is the first practical slice of the AI Second Brain workflow from
NotebookLM "Claude Code and Obsidian: Building Your AI Second Brain".

The pipeline accepts a URL, text file, stdin, GitHub Issue, or GitHub PR and
creates an Obsidian-compatible Markdown note proposal with YAML frontmatter,
wiki links, tags, related-note suggestions, and an append-only audit log.

## Draft

```powershell
python scripts\memory_ingest.py `
  --gh-issue 974 `
  --mode draft `
  --tag second-brain
```

The draft is written to `memory/ingest_drafts/`. Review or edit it there.

## Save

```powershell
python scripts\memory_ingest.py `
  --input-file memory\ingest_drafts\ingest_YYYYMMDD_example.md `
  --mode save `
  --target-dir memory\vault
```

Saved notes live in `memory/vault/` and can be opened by Obsidian as plain
Markdown.

## Discard

```powershell
python scripts\memory_ingest.py `
  --url https://example.com `
  --mode discard
```

Discard mode does not write a note, but it does log the decision to
`memory/ingest_log.jsonl`.

## Export To Another Vault

```powershell
python scripts\memory_ingest.py `
  --gh-pr 994 `
  --mode save `
  --export-dir C:\Users\kanta\Documents\Obsidian\jibun-vault
```

## Vault Migration Manifest

Before staging an existing local vault for the site, create a local-only
manifest outside the vault:

```powershell
python scripts\obsidian_vault_migration_manifest.py `
  --vault C:\path\to\company-vault `
  --output C:\tmp\company-vault-migration-manifest.json `
  --credential-path relative\path\to\known-credential.json `
  --fail-on-review
```

The command is read-only toward the vault and performs no network requests.
It records Markdown structure, wikilink/embed resolution, attachment hashes,
and migration classifications. It never includes note bodies or frontmatter
values. `.obsidian`, `scripts`, `Templates`, agent instruction files, and
credential-like paths are excluded without being opened or hashed. Hidden
backup paths and migration `_control`/`_source` data are also excluded so a
backup cannot be staged beside its active copy. Every other JSON file is kept
unread and classified as structured data requiring separate review; use
`--credential-path` to identify a known credential without inspecting it.
Financial, debt, housing, legal, account, and subscription notes are marked
`review_required` rather than auto-staged.

The output must be outside the vault. Exit code `2` with `--fail-on-review`
means the manifest was written successfully but manual review is still
required; it does not mean files were uploaded.

## Stage Structure In The Site

Open `/notion-migration`, create or load a migration ledger, and use the
Obsidian manifest card. Selection and validation happen in the browser before
any request is made. The confirmation screen shows the auto-stage, review, and
excluded counts.

The site sends only the manifest digest, aggregate safety counts, and
allowlisted structure for non-excluded Markdown notes and attachments. It does
not send note bodies, frontmatter values, credential material, absolute paths,
or even the relative paths of excluded files. Links or attachment references
to an excluded path are removed from the staged structure.

Staging is idempotent by migration batch and manifest SHA-256. Entries are
written in bounded chunks to dedicated RLS-protected tables and never mixed
with the Notion source-deletion ledger. A retry resumes the same manifest;
partial failures remain marked `failed` until retried. Authenticated users can
read, insert, and update only their own staging rows and cannot delete them.

## Acceptance Coverage

- URL/text/GitHub input produces a Markdown note proposal.
- Related notes are ranked from `memory/` and `docs/`; at least `MEMORY.md` is
  suggested when no stronger match exists.
- Draft/save/discard modes support user approval before persistence.
- Saved notes are Obsidian-compatible Markdown with YAML frontmatter and wiki
  links.
- Every ingest attempt writes a JSONL audit record.

## Remaining Migration Work

- Review every `review_required` note before content import.
- Resolve unresolved wikilinks and verify attachment rendering.
- Import selected note bodies through a separately approved, encrypted path.
- Complete the seven Notion parity checks before any Notion deletion or
  subscription cancellation.

## Asset Management Vault Import

The asset-management page reads a selected local vault entirely in the
browser. It supports balance tables and explicit subscription cancellation
tables. A cancellation table is recognized only inside a Markdown section
whose heading contains `解約` or `停止済み`, with the columns `サービス名`,
`終了日 / 停止日`, and `状態`.

Only rows explicitly marked `解約完了`, `解約済み`, `停止済み`, `停止完了`,
`終了済み`, or `終了完了` are considered. The page previews exact matches
against currently registered recurring subscriptions. Missing and ambiguous
matches remain read-only and are never deleted. Absence from the vault is not
interpreted as cancellation.

After final confirmation, selected matches are removed from current recurring
fixed costs and written to the existing deletion-tombstone mirror so another
device cannot restore them. Historical monthly and transaction records remain
unchanged. Markdown bodies and local file paths are not uploaded.
