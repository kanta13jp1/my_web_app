# Claude Code Remote Control network troubleshooting

Last reviewed: 2026-09-03 JST

Use this runbook when a Claude Code Remote Control session cannot be created,
connects intermittently, or reports `Remote credentials fetch failed`. It
separates DNS, TCP/TLS, proxy, authentication, eligibility, and session errors
so a network failure is not "fixed" by weakening security controls.

Remote Control must already be approved by the organization Owner and the
security/legal reviewers. Do not use these steps to bypass a managed setting,
data-retention restriction, Zero Data Retention restriction, firewall rule, or
proxy policy.

## Protect the diagnostic evidence

- Run diagnostics from the same shell and network as Claude Code.
- Never paste the output of `/status`, a session URL, QR code, OAuth token,
  proxy credential, environment value, or complete verbose log into an Issue.
- Keep a captured log outside the repository, preferably in the operating
  system temporary directory. Redact it before sharing through an approved
  private support channel, then delete it under the organization's retention
  policy.
- Do not add authorization headers to connectivity probes. An HTTP `401`,
  `403`, or `404` can still prove that DNS, TCP, and TLS succeeded.
- Never set `NODE_TLS_REJECT_UNAUTHORIZED=0` or disable certificate validation.

## 1. Record a secret-free baseline

Record the timestamp and version:

```powershell
Get-Date -Format o
claude --version
```

Open a local Claude Code session and run `/status`. Confirm the login method,
account, and organization locally, but do not copy the output into the ticket.
Remote Control requires a `claude.ai` OAuth login; API keys, Console accounts,
third-party model providers, and a custom `ANTHROPIC_BASE_URL` do not provide a
Remote Control backend.

Check only whether relevant variables are present. This command prints names
and `SET`/`unset`, never values:

```powershell
$names = @(
  'ANTHROPIC_API_KEY',
  'ANTHROPIC_BASE_URL',
  'CLAUDE_CODE_OAUTH_TOKEN',
  'CLAUDE_CODE_USE_BEDROCK',
  'CLAUDE_CODE_USE_VERTEX',
  'CLAUDE_CODE_USE_FOUNDRY',
  'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC',
  'DISABLE_TELEMETRY',
  'HTTPS_PROXY',
  'HTTP_PROXY',
  'NO_PROXY',
  'NODE_EXTRA_CA_CERTS'
)

foreach ($name in $names) {
  $state = if (Test-Path "Env:$name") { 'SET' } else { 'unset' }
  "$name=$state"
}
```

Do not replace this with `Get-ChildItem Env:` because that exposes values.

## 2. Prove the outbound HTTPS path

Remote Control opens no inbound port. The local process makes outbound HTTPS
connections through the Anthropic API. Check DNS and TCP port 443 first:

```powershell
Resolve-DnsName api.anthropic.com
Test-NetConnection api.anthropic.com -Port 443 -InformationLevel Detailed
```

`TcpTestSucceeded : True` proves that the shell reached port 443. Next, test
TLS and HTTP without credentials:

```powershell
curl.exe -I --connect-timeout 10 https://api.anthropic.com
curl.exe -I --connect-timeout 10 https://claude.ai
```

Any HTTP response proves that DNS, TCP, and TLS completed. A timeout, DNS
failure, proxy tunnel error, or certificate error identifies the failing layer.
Ask the network owner to allow outbound HTTPS on port 443 to the hosts in the
official network-access list. Do not create an inbound firewall rule.

If a corporate proxy is required, verify that the approved `HTTPS_PROXY` is
present in the same shell. Claude Code reads shell proxy variables at process
startup, so restart it after a proxy change. Never put a proxy password in a
script, Issue, screenshot, or committed settings file. For TLS inspection, use
the organization CA through `NODE_EXTRA_CA_CERTS` or the supported certificate
store; do not suppress TLS verification.

## 3. Reproduce once with verbose output

Only after the Remote Control security and host-resource gates pass, run one
sandboxed, single-session reproduction:

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$log = Join-Path $env:TEMP "claude-remote-control-$stamp.log"
claude remote-control --verbose --sandbox --spawn session 2>&1 |
  Tee-Object -FilePath $log
```

Stop after one reproduction. Do not run multiple servers while diagnosing a
connection problem. Classify the earliest relevant failure:

| Evidence | Layer | Next action |
| --- | --- | --- |
| DNS name cannot resolve | DNS/VPN | Repair the resolver or VPN route |
| TCP 443 fails | Firewall/proxy | Ask the network owner to permit outbound HTTPS |
| Certificate validation fails | TLS inspection | Install the approved CA; keep validation enabled |
| Proxy tunnel/authentication fails | Proxy | Correct the approved proxy configuration |
| Eligibility or organization-policy error | Account/policy | Check `/status` and ask the Owner; do not bypass policy |
| `Remote credentials fetch failed` | OAuth, network, or earlier session creation | Follow the decision flow below |
| Reconnect fails after a long outage | Session lifetime | Start a new Remote Control session |

Before sharing `$log`, make a redacted copy and inspect every line. Remove
session URLs, query strings, authorization material, cookies, QR/device data,
user and organization identifiers, local paths, prompts, and file contents.
Keep the original private and delete both copies when the support case closes.

## 4. Resolve `Remote credentials fetch failed`

1. Read the complete `--verbose` error and fix a DNS, TCP 443, TLS, or proxy
   failure before changing authentication.
2. If the error says the user is not signed in, open local Claude Code, run
   `/status`, then use `/login` and select the `claude.ai` account. The
   equivalent current CLI flow is `claude auth login`.
3. If an API key, inference-only setup token, third-party provider, or custom
   `ANTHROPIC_BASE_URL` is active, do not copy its value. Confirm with the owner
   that the shell may use `claude.ai` OAuth, remove the conflicting variable
   only from a disposable shell, and run `/login` there.
4. On Claude Code v2.1.224 and later, a stale saved token is refreshed and
   retried automatically. Do not repeatedly log out or delete credential files
   merely because this message appeared. Older versions should be updated
   through the organization's approved software-update path.
5. If the verbose output also says `Session creation failed`, confirm that the
   subscription is active and route the sanitized failure to the service owner.
6. Retry once. If it still fails, stop and escalate with the evidence checklist
   below rather than cycling credentials.

`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` or `DISABLE_TELEMETRY` can cause an
eligibility check to fail. If either is enforced by managed policy, leave it in
place and escalate. If it was set only in the disposable shell, the Owner and
security reviewer may approve one test in a new shell without that variable.
Closing that shell restores the prior environment. Never weaken an
organization privacy control to make Remote Control work.

## 5. Close or escalate

An outage longer than roughly ten minutes can end the Remote Control process.
After network recovery, start a new session instead of assuming the old remote
session is still live.

Record only this sanitized evidence:

- timestamp, operating system, and Claude Code version;
- exact error class, with identifiers and content removed;
- DNS result, `TcpTestSucceeded`, and TLS/HTTP result for each required host;
- proxy and relevant environment variable names as `SET`/`unset` only;
- login method and organization eligibility as confirmed/not confirmed, with
  no account details;
- whether one sandboxed retry succeeded;
- network, organization Owner, or Anthropic support ticket reference.

The responder closes the incident only after a new sandboxed session connects,
the remote client disconnects when the local process stops, and the temporary
diagnostic logs are handled under the retention policy.

## Official evidence

- [Remote Control troubleshooting](https://code.claude.com/docs/en/remote-control)
- [Enterprise network configuration](https://code.claude.com/docs/en/network-config)
- [Network and connection error reference](https://code.claude.com/docs/en/errors#network-and-connection-errors)
- [Claude Code CLI reference](https://code.claude.com/docs/en/cli-usage)
- [Claude Code environment variables](https://code.claude.com/docs/en/env-vars)

External behavior can change. Recheck these pages before changing this runbook.
