-- Codex takeover: AI University 100 providers.
--
-- Add three vibe-coding providers that were explicitly listed as missing
-- in the Replit seed: Cursor, Lovable, and Bolt.new.
-- Sources:
--   Cursor official features: https://cursor.com/en-US
--   Lovable official Supabase docs: https://docs.lovable.dev/integrations/supabase
--   Lovable enterprise/code ownership: https://lovable.dev/enterprise-landing
--   Bolt.new official repository: https://github.com/stackblitz/bolt.new

INSERT INTO ai_university_content (provider, category, title, content, updated_at)
VALUES
  (
    'cursor',
    'overview',
    'Cursor — codebase-aware AI editor and agents',
    $md$
# Cursor — codebase-aware AI editor and agents

Cursor is an AI-native code editor from Anysphere. It focuses on helping developers move
between small targeted edits and more autonomous agent work without leaving the editor.

## Positioning

- **Layer**: developer IDE / code editor
- **Core value**: understand an existing codebase, edit files, run commands, and help ship changes
- **Best fit**: professional engineering work where local repository context matters
- **Jibun Inc. comparison**: Cursor helps build software; Jibun Inc. helps operate the user's life-management workspace

## Officially highlighted capabilities

- Codebase understanding and indexing
- Agent workflows for planning/building software
- Model choice across OpenAI, Anthropic, Gemini, xAI, and Cursor models
- Parallel cloud agents that can build, test, and demo features
- Enterprise adoption and secure team workflows

## Why it matters for AI University

Cursor belongs in the "AI software engineering" cluster with Cognition, Replit, Poolside,
and GitHub Copilot. The key learning point is the autonomy slider: completion, targeted
edit, agent, and cloud agent are different levels of delegation.

Official: https://cursor.com/en-US
$md$,
    NOW()
  ),
  (
    'cursor',
    'use_cases',
    'Cursor use cases — refactor, test, and multi-file implementation',
    $md$
# Cursor use cases

## 1. Existing codebase refactor

Cursor is strongest when the repository already exists and the next task requires reading
many files, editing several modules, and preserving local conventions.

## 2. Test repair and bug fixing

Cursor's value is not only code generation. The practical workflow is:

1. Ask the agent to inspect the failing behavior.
2. Let it modify files.
3. Run tests or linters.
4. Iterate on failures.

## 3. Pairing with Jibun Inc.

Jibun Inc. can record the user's goals, notes, metrics, and operating rhythm. Cursor is
then a downstream build tool for implementing the software artifacts that those goals
produce.

## Watch points

- Keep sensitive context and credentials out of prompts.
- Review multi-file edits before accepting them.
- Treat cloud agents as asynchronous contributors, not invisible magic.
$md$,
    NOW()
  ),
  (
    'cursor',
    'quiz',
    'Cursor quiz — autonomy slider',
    $md$
# Quiz

**Question**: Cursor's main product category is closest to which option?

A. AI image generator
B. AI-native code editor and software agent workspace
C. Vector database
D. Speech-to-text API

**Correct answer**: B

**Explanation**: Cursor is positioned as an AI code editor with codebase understanding,
agent workflows, and model selection for software development tasks.
$md$,
    NOW()
  ),
  (
    'lovable',
    'overview',
    'Lovable — team-oriented AI app builder on React/Supabase/Tailwind',
    $md$
# Lovable — team-oriented AI app builder

Lovable is an AI app builder that lets teams turn prompts and product context into working
software prototypes. It is especially relevant to AI University because it shifts app
creation from "developer-only editor" toward PM/designer/operator collaboration.

## Officially documented stack and workflow

- Lovable apps use a modern stack including **React, Supabase, and Tailwind**.
- Validated prototypes can sync/export code to GitHub.
- Supabase integration can add auth, database, storage, and server-side code.
- Enterprise workflows include role-based access control, SSO/SAML, SCIM, and audit logs.

## Differentiation from Cursor

Lovable frames Cursor as an engineering acceleration tool, while Lovable targets broader
teams that need to build working software while engineers keep control through GitHub PRs.

Official docs:
- https://docs.lovable.dev/integrations/supabase
- https://lovable.dev/enterprise-landing
$md$,
    NOW()
  ),
  (
    'lovable',
    'use_cases',
    'Lovable use cases — prototype, Supabase backend, GitHub handoff',
    $md$
# Lovable use cases

## 1. Product prototype

PMs and operators can express a workflow in natural language and get a working UI quickly.
This is useful before committing engineering time to a full implementation.

## 2. Supabase-backed app

With Supabase connected, Lovable can create authentication, database tables, storage-backed
uploads, and server-side functionality. The important learning point is that an AI builder
still needs a real backend for persistent data.

## 3. Engineering handoff

Lovable's GitHub export/sync path makes it easier to move from prototype to maintained
code. For Jibun Inc., that means Lovable can be treated as a discovery/prototyping lane,
not the final system of record.

## Watch points

- Review generated database schema before applying it to production.
- Keep billing and security ownership explicit when Supabase/Stripe are involved.
- Avoid assuming a prototype has production-grade error handling.
$md$,
    NOW()
  ),
  (
    'lovable',
    'quiz',
    'Lovable quiz — backend integration',
    $md$
# Quiz

**Question**: Which backend service does Lovable officially document for auth, database,
storage, and server-side code?

A. Supabase
B. Qdrant
C. Deepgram
D. Midjourney

**Correct answer**: A

**Explanation**: Lovable's Supabase integration provides managed backend capabilities such
as authentication, database persistence, file uploads, and server-side logic.
$md$,
    NOW()
  ),
  (
    'bolt_new',
    'overview',
    'Bolt.new — AI full-stack development in the browser',
    $md$
# Bolt.new — AI full-stack development in the browser

Bolt.new is StackBlitz's AI-powered web development agent. Its distinctive point is that
the agent can work inside a browser-based full-stack environment rather than merely
suggesting snippets.

## Officially highlighted capabilities

- Prompt, run, edit, and deploy full-stack web applications from the browser
- Powered by StackBlitz WebContainers
- Install and run npm tools and libraries
- Run Node.js servers
- Interact with third-party APIs
- Deploy to production from chat

## Positioning

Bolt.new sits between UI generators and full IDE agents. Compared with Cursor, it lowers
local setup friction. Compared with Lovable, it exposes more developer-style environment
control in the browser.

Official: https://github.com/stackblitz/bolt.new
$md$,
    NOW()
  ),
  (
    'bolt_new',
    'use_cases',
    'Bolt.new use cases — browser-first full-stack prototyping',
    $md$
# Bolt.new use cases

## 1. Zero-setup web prototype

When the goal is to test a frontend or full-stack concept quickly, Bolt.new can scaffold,
run, edit, and preview the app without a local dev environment.

## 2. JavaScript ecosystem exploration

Because Bolt.new runs npm tools and Node.js servers through WebContainers, it is a useful
way to evaluate Vite, Astro, Next.js, Tailwind, ShadCN, and similar stacks.

## 3. AI University exercise

Ask learners to build the same small app in Replit, Lovable, Cursor, and Bolt.new. Compare:

- setup time
- backend persistence
- source-code ownership
- deploy path
- debugging depth

## Watch points

- Browser environments have different constraints than local machines.
- Token limits and paid tiers can interrupt longer sessions.
- Production apps still need code review, tests, and security checks.
$md$,
    NOW()
  ),
  (
    'bolt_new',
    'quiz',
    'Bolt.new quiz — WebContainers',
    $md$
# Quiz

**Question**: Bolt.new's browser-based development environment is powered by which
StackBlitz technology?

A. WebContainers
B. Supabase Edge Functions
C. Flutter CanvasKit
D. OpenAI Realtime

**Correct answer**: A

**Explanation**: Bolt.new uses StackBlitz WebContainers to run npm tooling, Node.js
servers, and full-stack development workflows directly in the browser.
$md$,
    NOW()
  )
ON CONFLICT (provider, category) DO UPDATE
SET title = EXCLUDED.title,
    content = EXCLUDED.content,
    updated_at = EXCLUDED.updated_at;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI University vibe-coding providers added',
  'Codex が AI大学 100社達成を一時引き継ぎ、Cursor / Lovable / Bolt.new の3プロバイダーを overview・use_cases・quiz 付きで追加した。',
  '2026-04-21'
)
ON CONFLICT DO NOTHING;
