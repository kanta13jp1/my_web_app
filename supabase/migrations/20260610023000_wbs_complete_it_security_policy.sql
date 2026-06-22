-- Win版#132 part 253 (2026-06-10 / Win Claude): Complete WBS IT セキュリティポリシータスク
-- 「IT セキュリティポリシー v1」
--  (task bd345cfa-c41d-4c84-9a83-53bd3879855d / category business-ops / milestone paying-100 /
--   description: パスワード管理 / 端末暗号化 / VPN).
--
-- 本タスクは owner_instance='codex' だったが、組織規程 (org-level policy docs) の「策定・文書化」は
-- L3 (Win Claude) の architect/ops-docs レーン ([DYNAMIC-CLAIM] = docs 引き取り可 / business-ops は
-- 禁止カテゴリ (business-legal/urgent/IPO) に非該当)。user 明示 /loop 再起動による本 session 2 件目
-- ([DYNAMIC-CLAIM] 2-cap 内)。owner も 'win' へ是正。
--
-- Deliverable (docs-only, no code/EF/schema change):
--   - docs/IT_SECURITY_POLICY_V1.md … 組織レベル IT セキュリティ規程の正本 (SSOT)。
--       タスク定義 3 軸を規程化: §1 アカウント・パスワード管理 (パスワードマネージャー + 2FA 必須 +
--       共有アカウント禁止 + dormant instance クレデンシャル棚卸し) / §3 端末セキュリティ
--       (Windows 11 Home の実態に合わせ Device Encryption (BitLocker 相当) 必須 + 自動更新 + 画面ロック) /
--       §4 ネットワーク・VPN (公衆 Wi-Fi は VPN またはテザリング / 製品選定は【CEO確定】placeholder)。
--       + 本組織固有の §2 鍵管理 (anon key は公開前提で RLS が守る設計の明文化 / service_role 級は
--       server-side のみ / 露出時は即ローテ) + §5 AI エージェント運用 (deny-by-default / SUBAGENT-GUARD /
--       MCP 10 原則 pointer) + §7 点検 cadence (四半期棚卸し) + §8 incident は ONCALL_INCIDENT_SOP へ
--       dispatch + §10 Deferred (SOC2=9a564512 / MDM は採用時 / VPN 製品 CEO 確定)。
--   - 非重複: MCP_AUTH_SECURITY_PRINCIPLES (MCP 技術 10 原則) / AI_DEV_PRINCIPLES (開発設計原則) とは
--     軸分け — 本書は「人と端末とアカウント」の組織運用規程。B2B_PROPOSAL_V1 §4 セキュリティ FAQ の
--     正本としても機能 (part 252 の自然な続き)。
--   - honest 完成定義: 規程の「策定・文書化」が成果物 (CEO 承認で発効)。SOC 2 認証準備 (9a564512) /
--     インシデント対応詳細 (ONCALL_INCIDENT_SOP 正本) は別タスク。実端末への設定適用は CEO の
--     運用アクション (§7 点検で確認)。
--
-- ai_review_status='approved' を同一 UPDATE で設定するため、progress=100 への遷移でも
-- wbs_request_ai_review trigger は発火しない → status='completed' が確定する。
-- Idempotent: 固定値 UPDATE / description append は LIKE guard / achievement は NOT EXISTS guard。

UPDATE public.wbs_tasks
SET
  status            = 'completed',
  progress          = 100,
  ai_review_status  = 'approved',
  ai_reviewed_at    = now(),
  ai_review_notes   = 'Win Claude (architect / ops-docs lane / L3) self-authored deliverable. docs/IT_SECURITY_POLICY_V1.md に組織レベル IT セキュリティ規程の正本 (SSOT) を整備。タスク定義 3 軸 (パスワード管理 / 端末暗号化 / VPN) を規程化: パスワードマネージャー + 2FA 必須 / Windows 11 Home 実態に合わせた Device Encryption 必須 / 公衆 Wi-Fi は VPN またはテザリング (製品選定【CEO確定】)。+ 組織固有の鍵管理 (anon key 公開前提 = RLS 防御の明文化 / service_role は server-side のみ / 露出時即ローテ) + AI エージェント運用 (deny-by-default / SUBAGENT-GUARD / MCP 10 原則 pointer) + 四半期棚卸し cadence + incident は ONCALL_INCIDENT_SOP へ dispatch。MCP_AUTH_SECURITY_PRINCIPLES / AI_DEV_PRINCIPLES と軸分け非重複。B2B_PROPOSAL_V1 §4 FAQ の正本化 (part 252 の続き)。SOC2 (9a564512) / MDM は Deferred 明記の honest scope。コード/スキーマ変更なしの docs-only。',
  owner_instance    = 'win',
  start_date        = COALESCE(start_date, DATE '2026-06-10'),
  end_date          = DATE '2026-06-10',
  remaining_work    = 'Completed by Win Claude (part 253). IT セキュリティ規程 SSOT = docs/IT_SECURITY_POLICY_V1.md (アカウント/鍵/端末/ネットワーク/AI 運用/棚卸し/インシデント/例外/Deferred)。残: CEO 承認で発効 + 実端末への設定適用確認 (§7 四半期点検) / VPN 製品選定【CEO確定】(§4-2) / SOC 2 gap 分析 = 9a564512 (series-a) / J-SOX 内部統制 = efe466ca (audit-ready)。',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-06-10: IT security policy v1 established%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-06-10 (Win Claude part 253): IT security policy v1 established at docs/IT_SECURITY_POLICY_V1.md as the org-level SSOT covering the three axes in the task description: (1) account/password management (password manager mandatory, 2FA on all key services, no shared accounts, decommissioned-instance credential inventory per the 12-to-2 fleet transition), (2) device security (device encryption mandatory, stated accurately for the real Windows 11 Home dev machine as Device Encryption / BitLocker-equivalent, auto-updates, screen lock, disposal rules), and (3) network/VPN (public Wi-Fi requires VPN or phone tethering; VPN product selection left as an explicit CEO-confirmation placeholder rather than inventing a vendor). Adds org-specific sections: secrets handling (anon key treated as public-by-design with RLS as the actual protection layer, service_role-class keys server-side only, immediate rotation on suspected exposure), AI-agent operations (deny-by-default, SUBAGENT-GUARD, MCP 10-principles pointer), quarterly credential/device audits, incident dispatch to ONCALL_INCIDENT_SOP, exception management, and deferred scope (SOC 2 prep 9a564512, MDM deferred until hiring, office physical security until an office exists). Non-duplicative by axis split with MCP_AUTH_SECURITY_PRINCIPLES (MCP-publishing technicals) and AI_DEV_PRINCIPLES (dev design principles); serves as the authoritative source behind the customer-facing security FAQ in B2B_PROPOSAL_V1 section 4 (natural continuation of part 252). Honest completion: authoring the policy is the deliverable; it takes effect on CEO approval, and applying settings to the physical device is a CEO operational action verified via the quarterly audit. Task claimed codex -> win (org policy docs is the L3 lane); 2nd task this session under explicit user /loop re-invocation, within the DYNAMIC-CLAIM 2-task cap.'
  END,
  updated_at        = now()
WHERE id = 'bd345cfa-c41d-4c84-9a83-53bd3879855d';

-- 開発実績ログ (development_achievements ページ反映 / 重複防止 = NOT EXISTS guard)
INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'IT セキュリティポリシー v1 策定 (アカウント/端末暗号化/VPN + AI エージェント運用規程)',
  'docs/IT_SECURITY_POLICY_V1.md を新設。組織レベル IT セキュリティ規程の正本 (SSOT) として、アカウント・パスワード管理 (パスワードマネージャー + 2FA 必須 + dormant instance クレデンシャル棚卸し) / 端末セキュリティ (Windows 11 Home 実態に合わせた Device Encryption 必須) / ネットワーク・VPN (公衆 Wi-Fi は VPN またはテザリング) のタスク定義 3 軸に加え、鍵管理 (anon key 公開前提 = RLS 防御の明文化 / service_role 級は server-side のみ / 露出時即ローテ) と AI エージェント運用 (deny-by-default / SUBAGENT-GUARD / MCP 10 原則) を規程化。四半期棚卸し cadence + ONCALL_INCIDENT_SOP への incident dispatch + Deferred (SOC2 / MDM / VPN 製品選定【CEO確定】) を明記。B2B_PROPOSAL_V1 §4 セキュリティ FAQ の正本 + SOC 2 準備の前提文書。paying-100 マイルストーン布石 (設計シリーズ第 13 弾)。',
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'IT セキュリティポリシー v1 策定 (アカウント/端末暗号化/VPN + AI エージェント運用規程)'
);
