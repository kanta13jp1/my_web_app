# Dynamic Context Injection

Issue: #1644

This contract turns the NotebookLM Master Brain, repo docs, and project skills
into a session-start routing aid. It does not replace Claude Code #1 design
judgment or Codex #1 implementation checks. It only makes the first context
bundle visible before work starts.

## Ownership

- Claude Code #1 owns design direction, product-risk calls, and final routing
  decisions.
- Codex #1 owns repo reads, scoped implementation, deterministic checks, PR
  evidence, merge follow-up, and cleanup.
- NotebookLM is external memory. Its output must be connected to a GitHub Issue,
  PR body, or existing Issue comment before it influences implementation.
- Old Codex #2/#3 labels are dormant; Codex #1 absorbs implementation work in
  the current two-instance flow.

## Repo Contract

The mapping lives in `config/context-injection-map.json`.

Each route declares:

- prompt keywords
- recommended docs
- recommended skills
- NotebookLM query candidates
- GitHub Issue targets for connecting any generated proposal

Session-start visibility is provided by:

```powershell
python scripts/context_injection_check.py
python scripts/context_injection_check.py --prompt "MCP external tool isolation"
python scripts/codex_session_check.py
```

The session report must show:

- the target NotebookLM harness notebook id
  `bc58b50b-5fc4-4840-9a62-b397d6d3b65a`
- whether the latest NotebookLM intake snapshot found the harness notebook
- unapplied NotebookLM candidate count from `docs/notebooklm-intake/`
- matched docs, skills, NotebookLM query candidates, and Issue targets

## Proposal Rule

Do not paste raw `notebooklm ask` output directly into implementation.

Instead, distill it into a proposal with:

- matched route id
- docs checked
- skill checked
- NotebookLM query candidate used
- target Issue or existing Issue comment
- repo evidence and CI evidence

The generated proposal is reviewable only when the GitHub Issue or PR body
shows where the NotebookLM-derived idea landed.

## Current Routes

- `ai-tool-adoption`: AI tool updates, hook adoption, Codex memory, and
  NotebookLM-backed workflow changes.
- `mcp-tool-boundary`: managed MCP, external tool permission, and container
  isolation decisions.
- `wbs-priority-routing`: WBS due-date selection and two-instance handoff
  checks.
- `calendar-ui`: calendar UI work and browser evidence requirements.
- `blog-news-automation`: source-risk, draft generation, and production E2E
  checks for blog/news automation.

## Validation

Run:

```powershell
python scripts/context_injection_check.py --check
python scripts/context_injection_check_test.py
```

These checks keep the mapping deterministic and prevent broken doc or skill
pointers from silently entering the session-start prompt.
