-- Codex #1: Issue #1964 FinTech disruption / Trading x AI department seed.
--
-- Scope:
-- - Add a FinTech / Trading x AI department under the existing AI faculty.
-- - Seed the 8 providers requested by #1964 as AI University learning entries.
-- - Keep the rows idempotent with the existing (provider, category) constraint.

WITH ai_faculty AS (
  SELECT id
  FROM university_faculties
  WHERE faculty_code = 'ai'
  LIMIT 1
),
fintech_dept AS (
  INSERT INTO university_departments (
    faculty_id,
    department_code,
    name_ja,
    name_en,
    description,
    emoji,
    sort_order
  )
  SELECT
    ai_faculty.id,
    'fintech_trading_ai',
    'FinTech disruption / Trading x AI',
    'Department of FinTech Disruption and Trading AI',
    'Compares institutional market-intelligence tools with low-cost AI workflows, then turns finance signals into learning, WBS actions, and personal KPI review.',
    'FX',
    80
  FROM ai_faculty
  ON CONFLICT (faculty_id, department_code) DO UPDATE
    SET name_ja = EXCLUDED.name_ja,
        name_en = EXCLUDED.name_en,
        description = EXCLUDED.description,
        emoji = EXCLUDED.emoji,
        sort_order = EXCLUDED.sort_order,
        is_active = true
  RETURNING id, faculty_id
),
fintech_rows AS (
  SELECT *
  FROM (VALUES
    (
      'bloomberg_terminal',
      'Bloomberg Terminal - institutional market intelligence baseline',
      $$## Bloomberg Terminal

Bloomberg Terminal is the institutional baseline for real-time market data, news, pricing, and professional trading workflows.

Learning focus:
- Why speed, source quality, and auditability matter in financial intelligence.
- How high-cost terminal workflows can be decomposed into source capture, dedupe, confidence scoring, and analyst review.
- Where a personal AI workflow should stop short of imitating paid data terminals and instead turn public signals into disciplined actions.

Jibun Company usage:
Use Bloomberg as a reference architecture, not as a copied feature set. The local workflow should preserve source URLs, confidence, next actions, and a human final decision.$$,
      'https://www.bloomberg.com/professional/products/bloomberg-terminal/',
      1200
    ),
    (
      'refinitiv_eikon',
      'Refinitiv Eikon / Workspace - market data workflow comparison',
      $$## Refinitiv Eikon / Workspace

Refinitiv Eikon, now part of LSEG Workspace, combines market data, news, charts, and research workflows for institutional users.

Learning focus:
- Entity resolution across news, market data, and company fundamentals.
- Workflow design that moves from raw data to research notes and decisions.
- Cost and governance tradeoffs when replacing parts of an institutional workflow with AI agents.

Jibun Company usage:
Use the pattern to connect market events with personal asset ledgers, KPI notes, and review tasks while keeping paid-data dependencies out of the core app.$$,
      'https://www.lseg.com/en/data-analytics/products/workspace',
      1210
    ),
    (
      'factset',
      'FactSet - portfolio analytics and institutional research patterns',
      $$## FactSet

FactSet represents portfolio analytics, estimates, company data, and research productivity for professional investors.

Learning focus:
- How portfolio analytics links company fundamentals with investment review.
- Why every AI-generated finance insight needs source links, assumptions, and confidence labels.
- How to preserve a decision log that can be revisited after outcomes are known.

Jibun Company usage:
Turn finance insights into auditable notes, personal KPI deltas, and WBS follow-ups rather than one-off trading recommendations.$$,
      'https://www.factset.com/',
      1220
    ),
    (
      'sentieo',
      'Sentieo - AI-assisted financial document research',
      $$## Sentieo

Sentieo is a financial document search and research workflow, now under AlphaSense.

Learning focus:
- Search-first research across filings, transcripts, and market news.
- Summaries that keep citations and original evidence close.
- Separating document retrieval, thesis formation, and human investment judgment.

Jibun Company usage:
Use NotebookLM, Claude, and Supabase logs to keep research claims traceable from source document to task decision.$$,
      'https://www.alpha-sense.com/platform/sentieo/',
      1230
    ),
    (
      'koyfin',
      'Koyfin - affordable market dashboard challenger',
      $$## Koyfin

Koyfin is a lower-cost market dashboard challenger that makes charts, watchlists, macro data, and screening more accessible.

Learning focus:
- Which parts of terminal value can be delivered through focused dashboards.
- How watchlists, charts, and macro indicators support daily review loops.
- How to keep individual users from drowning in unrelated market signals.

Jibun Company usage:
Convert market dashboards into a daily digest that only surfaces signals tied to personal goals, assets, and open WBS tasks.$$,
      'https://www.koyfin.com/',
      1240
    ),
    (
      'atom_finance',
      'Atom Finance - consumer investor research workflow',
      $$## Atom Finance

Atom Finance focuses on retail investing research and portfolio insights.

Learning focus:
- How professional-looking research can be translated for consumer investors.
- How portfolio notifications should avoid becoming ungrounded trading advice.
- How to design guardrails around incomplete, delayed, or single-source market claims.

Jibun Company usage:
Use the pattern for user-friendly finance explanations, but keep recommendations framed as review prompts with source links and risk notes.$$,
      'https://atom.finance/',
      1250
    ),
    (
      'claude_pro_finance',
      'Claude Pro finance workflow - low-cost external brain for market research',
      $$## Claude Pro finance workflow

Claude Pro can serve as a low-cost external brain for daily market research when used with strict source discipline.

Learning focus:
- Pattern detection, contradiction checks, and fake-news filtering over public inputs.
- Warning on social-only claims, single-source claims, and price moves without evidence.
- Compressing long research into concise briefs for human review.

Jibun Company usage:
Treat Claude as a research assistant, not a decision maker. Persist source URL, timestamp, confidence, and next action in a structured log.$$,
      'https://www.anthropic.com/claude',
      1260
    ),
    (
      'cursor_jibun_finance',
      'Cursor + Jibun Company - integrated signal-to-action finance OS',
      $$## Cursor + Jibun Company finance OS

Cursor plus Jibun Company turns a finance intelligence workflow into code, data, UI, and review automation.

Learning focus:
- Split source ingestion, dedupe, confidence scoring, and draft generation into small PR-sized changes.
- Reuse one signal across blog drafts, WBS tasks, portfolio notes, and daily briefs.
- Keep cost discipline by avoiding unnecessary paid-data or external API dependencies.

Jibun Company usage:
Move from reading market news to maintaining a daily action OS: capture, verify, classify, assign, and review.$$,
      'https://www.cursor.com/',
      1270
    )
  ) AS row(provider, title, content, source_url, sort_order)
)
INSERT INTO ai_university_content (
  provider,
  category,
  title,
  content,
  source_url,
  published_at,
  sort_order,
  faculty_id,
  department_id,
  is_active
)
SELECT
  row.provider,
  'fintech_trading_ai',
  row.title,
  row.content,
  row.source_url,
  '2026-05-12',
  row.sort_order,
  fintech_dept.faculty_id,
  fintech_dept.id,
  true
FROM fintech_rows row
CROSS JOIN fintech_dept
ON CONFLICT (provider, category) DO UPDATE
  SET title = EXCLUDED.title,
      content = EXCLUDED.content,
      source_url = EXCLUDED.source_url,
      published_at = EXCLUDED.published_at,
      sort_order = EXCLUDED.sort_order,
      faculty_id = EXCLUDED.faculty_id,
      department_id = EXCLUDED.department_id,
      is_active = true,
      updated_at = now();

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Codex #1: Issue #1964 FinTech disruption / Trading x AI seed',
  'Seeded the AI University FinTech disruption / Trading x AI department with Bloomberg Terminal, Refinitiv Eikon, FactSet, Sentieo, Koyfin, Atom Finance, Claude Pro finance workflow, and Cursor + Jibun Company finance OS content.',
  '2026-05-12'
)
ON CONFLICT DO NOTHING;
