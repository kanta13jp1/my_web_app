# Claude Code Remote Control server mode policy

Last reviewed: 2026-09-03 JST

This policy supplements the security decision tracked in Issue #2877 and Draft
PR #5265. It does not approve Remote Control or start a server. Complete that
security decision and the external Owner/OAuth/device checks first.

## Safe mode selection

| Need | Mode | Repository policy |
| --- | --- | --- |
| One remotely controlled task | `--spawn session` | Default; always add `--sandbox`; do not pass `--capacity` |
| Two isolated tasks | `--spawn worktree --capacity 2` | Allowed only after the resource and security gates pass |
| Shared working directory | `--spawn same-dir` | Prohibited; concurrent edits can conflict |

The Claude Code default server capacity is 32. This repository never accepts
that default. Multi-session mode is capped at 2 and uses git worktrees with
`--no-create-session-in-dir` so an on-demand session does not silently share the
launch directory. `--permission-mode default` preserves normal permission
prompts; sandboxing does not replace them.

## Resource gate

Do not start local server mode when any condition is true:

- RAM use is at least 85%.
- Free physical memory is below 4 GiB.
- Free disk is below 30 GiB.
- A measurement is unavailable.

This matches the repository's cloud-first boundary. Under pressure, preserve
the branch and use GitHub Actions instead of starting more local sessions,
Flutter/Dart toolchains, browser automation, or local child workers.

Generate a plan without starting Claude Code:

```powershell
python scripts/claude_remote_control_server_plan.py --mode single --json
```

The command is withheld and the process exits nonzero until the security review
is recorded and resource measurements are healthy:

```powershell
python scripts/claude_remote_control_server_plan.py `
  --mode single `
  --security-review-recorded `
  --json
```

For the exceptional two-session case:

```powershell
python scripts/claude_remote_control_server_plan.py `
  --mode multi `
  --capacity 2 `
  --security-review-recorded `
  --json
```

The script prints an argument vector. It intentionally has no execute option.
Review the output before manually running it.

## Sandbox verification

Use a disposable, secret-free test repository. Do not test against this
repository's production credentials or the user's home directory.

1. Confirm the generated argument vector contains `--sandbox` and
   `--permission-mode default`.
2. Start only one test session and inspect the Remote Control status panel.
3. Ask the session to create and remove a marker inside the disposable repo.
4. Ask it to read a non-sensitive marker immediately outside that repo. The
   sandbox must block the read or require an explicit permission expansion.
5. Ask it to reach a benign endpoint that is not allowlisted. The sandbox must
   block the request or require explicit approval. Do not weaken organization
   privacy controls to make the test pass.
6. Stop the server, verify the remote client can no longer steer it, and remove
   only the disposable test repository.

Record pass/fail, Claude Code version, mode, capacity, and reviewer names. Never
record OAuth tokens, session URLs, QR codes, device credentials, file contents,
or environment values.

## Official evidence

- [Remote Control server flags, security model, and limitations](https://code.claude.com/docs/en/remote-control)
- [Claude Code sandboxing](https://code.claude.com/docs/en/sandboxing)

External behavior can change. Recheck both pages before changing this policy.
