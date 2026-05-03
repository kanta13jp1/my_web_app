-- PS#4 S669: 競合9社追加 AI Codingエージェント (CodeRabbit/Greptile/Qodo/Pieces/Sourcegraph Cody/Sweep/Aider/OpenHands/Continue.dev)
-- bc58b50b (Codex vs Claude Code Synergy) 関連: AIコーディングエージェントエコシステムを競合として追加
-- SEO: "CodeRabbit代替"/"AIコードレビュー"/"OSS AIコーディングエージェント" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S669: 競合9社追加 (CodeRabbit/Greptile/Qodo/Pieces/Sourcegraph Cody/Sweep/Aider/OpenHands/Continue.dev)',
  'comparison_page.dartにCodeRabbit(AIコードレビューボット/PR自動レビュー/GitHub・GitLab/FF6B35)/Greptile(AIコードベース横断検索/自然言語質問/PR文脈理解/00BFA5)/Qodo旧CodiumAI(AIテスト生成/PR-Agent/コード整合性/7C4DFF)/Pieces for Developers(AIスニペット管理/ローカルLLM/オフライン対応/00A8E8)/Sourcegraph Cody(全社コードベース横断AI/Context fetcher/VSCode・JetBrains/FF5F6D)/Sweep AI(Issue→PR自動変換/自然言語修正/OSS/43A047)/Aider(OSSターミナルAIペアプロ/git自動コミット/マルチファイル編集/009688)/OpenHands旧OpenDevin(All Hands AI/OSS自律エージェント/Docker/E91E63)/Continue.dev(OSS IDE拡張/任意LLM接続/ローカルモデル/1976D2)の9社追加(1843→1852社)。sitemap 1939→1948 URLs。ai-coding-agentカテゴリ新設。',
  '2026-05-03'
)
ON CONFLICT DO NOTHING;
