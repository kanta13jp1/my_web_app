---
name: github-reuse-first
description: Search GitHub for maintained open-source projects before starting substantial greenfield development, a major feature, architecture work, or a rebuild. Compare reuse candidates for license, maintenance, deployment effort, architecture fit, reusable features, security, and long-term ownership; recommend using as-is, extending/forking, reusing components, or building from scratch; then propose the smallest MVP and wait for explicit user approval before writing code. Use when the user asks to build something and wants existing OSS investigated first, asks whether to reuse or build, or requests a reuse-first technical assessment.
---

# GitHub Reuse First

Use GitHub as a reuse-first gate before implementation. Produce a current, evidence-based recommendation, not a repository popularity list.

## Enforce The Discovery Gate

- Do not edit files, scaffold a project, install dependencies, or write implementation code during discovery.
- Verify that the connected GitHub plugin is callable. Prefer the `github:github` workflow and GitHub repository data over generic web search.
- If GitHub is unavailable, stop and ask the user to connect or re-authenticate the GitHub plugin. Do not silently replace the required GitHub investigation with memory or guesses.
- Inspect the local repository read-only when architecture, language, deployment, or license constraints affect candidate fit.
- Proceed to implementation only after the user explicitly approves the recommendation.

## Define The Target

Extract or infer the following before searching:

- Problem and intended users
- Must-have MVP capabilities
- Existing stack and deployment target
- Integration, data, privacy, and security constraints
- Acceptable licenses and operating cost
- Time available for setup and ongoing maintenance

State material assumptions. Ask one concise question only when a missing constraint would change the recommendation substantially.

## Search GitHub

1. Generate multiple search formulations from the product category, core capability, framework, and deployment target.
2. Find 5-10 plausible repositories, then shortlist 3-5 serious candidates.
3. Inspect each shortlisted repository directly. Check its README, license, releases, recent commits, issue activity, contributor distribution, test/CI evidence, documentation, deployment instructions, extension points, and security posture when available.
4. Prefer current repository evidence. Treat stars and forks as discovery signals, never as proof of quality or maintenance.
5. Record unknowns explicitly rather than estimating unverified facts.

## Evaluate Candidates

Compare candidates on:

- Functional fit and reusable features
- Last meaningful activity and release cadence
- Maintainer and issue responsiveness
- License compatibility and attribution obligations
- Setup, migration, hosting, and operational effort
- Architecture and dependency fit with the current project
- Test quality, documentation, security, and upgrade path
- Extension points versus the cost of carrying a fork
- Vendor lock-in and long-term maintenance burden

Reject candidates with incompatible licenses, abandoned critical dependencies, unsafe defaults, or a deployment model that defeats the MVP goal.

## Choose One Outcome

Choose exactly one primary recommendation:

1. **Use as-is**: The product already satisfies the MVP with configuration only.
2. **Extend or fork**: The core is suitable and the required delta is bounded and maintainable.
3. **Reuse components**: Only specific libraries, modules, schemas, or UI patterns should be adopted.
4. **Build from scratch**: No candidate clears the fit, license, security, or maintenance threshold.

Explain why the selected outcome has lower total delivery and ownership cost than the alternatives.

## Report Before Coding

Return the discovery result in the user's language with direct GitHub links and this structure:

1. **Goal and constraints**: Concise restatement and assumptions.
2. **Candidate comparison**: Repository, license, maintenance signal, deployment difficulty, reusable scope, gaps, and risks.
3. **Recommendation**: One of the four outcomes and the decisive evidence.
4. **Smallest MVP**: Minimum capabilities, reused pieces, custom pieces, and what is deliberately excluded.
5. **Implementation outline**: Short phases, validation checks, migration risks, and rollback approach.
6. **Approval gate**: Ask the user to confirm the recommendation before implementation.

Stop after the approval gate. Do not perform implementation work in the same turn unless the user already gave explicit approval to proceed after discovery.

## Implement After Approval

After approval, re-check the working tree and repository instructions, preserve unrelated changes, record upstream project and license attribution, implement only the approved MVP scope, and run deterministic tests. If discovery evidence has materially changed, report the change before continuing.
