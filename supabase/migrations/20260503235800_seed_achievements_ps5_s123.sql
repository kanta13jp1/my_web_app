-- PS#5 S123: #1707 Copilot Code Review課金変更 対応文書 + AI_FLEET_SYNERGY Principle 6更新
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    '#1707: Copilot Code Review課金変更(2026-06-01〜)対応 — AI_FALLBACK_RUNBOOK + SYNERGY更新',
    'docs/AI_FALLBACK_RUNBOOK.md にCopilot Code Review = Actions minutes消費開始(2026-06-01)の対処方針追記。docs/AI_FLEET_SYNERGY_PLAYBOOK.md 原則6(Deterministic Guardrails)にBudget cap rule追加。ci-auto-fix.yml Actions custom image +20%高速化候補も文書化。',
    '2026-05-03'
  )
ON CONFLICT DO NOTHING;
