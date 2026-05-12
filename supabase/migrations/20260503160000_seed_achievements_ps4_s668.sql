-- PS#4 S668: 競合9社追加 LLM評価フレームワーク (DeepEval/promptfoo/lm-eval-harness/LightEval/Ragas/TruLens/Giskard/Braintrust/HELM)
-- bc58b50b (Codex vs Claude Code Synergy) 推奨: LLM評価ツール群をAI大学競合として追加
-- SEO: "DeepEval代替"/"LLMテスト"/"RAG評価フレームワーク"/"LLM-as-Judge" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S668: 競合9社追加 (DeepEval/promptfoo/lm-eval-harness/LightEval/Ragas/TruLens/Giskard/Braintrust/HELM)',
  'comparison_page.dartにDeepEval(Confident AI/Python/pytest互換/RAG評価/LLM-as-Judge/14+メトリクス/00D0A0)/promptfoo(OSS/YAML設定/レッドチーミング/脆弱性スキャン/CI統合/00A8E8)/lm-evaluation-harness(EleutherAI/200+タスク/MMLU/HumanEval/Hugging Face統合/6B4FFF)/LightEval(HuggingFace/軽量/Transformers統合/カスタムタスク/FF9B00)/Ragas(RAG Faithfulness/Answer Relevancy/Context Precision/LangChain統合/FF6B6B)/TruLens(TruEra/RAGトライアド/ハルシネーション検出/LlamaIndex対応/4B9AF9)/Giskard(OSS/LLMバイアス検出/OWASP LLM Top10/CI統合/9B59B6)/Braintrust(LLMエバル統合/ロギング/トレーシング/A/Bテスト/FF5A00)/HELM(Stanford/100+シナリオ/30+メトリクス/公平性・堅牢性・校正度/3D5AFE)の9社追加(1834→1843社)。sitemap 1930→1939 URLs。llm-evalカテゴリ新設。bc58b50b推奨ツール群。',
  '2026-05-03'
)
ON CONFLICT DO NOTHING;
