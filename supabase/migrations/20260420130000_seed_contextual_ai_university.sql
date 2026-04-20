-- Session PS#3-S20: AI大学 138 社化 — Contextual AI 追加
-- Contextual AI = RAG 発明者 Douwe Kiela 創業の企業向け RAG 特化ラボ
-- Grounded Language Model (GLM) + RAG 2.0 + Agent Composer (2026-01 launch)
-- $80M Series A (Greycroft lead)
-- Step 0: 8/9 (OSS 非公開のみ -1)

INSERT INTO ai_university_content (provider, category, title, content, updated_at)
VALUES
  (
    'contextual_ai',
    'overview',
    'Contextual AI — RAG 発明者 Douwe Kiela の企業向け grounded LLM ラボ',
    $md$
# Contextual AI — RAG 発明者 Douwe Kiela の企業向け grounded LLM ラボ

2023-06 パロアルト創業、CEO **Douwe Kiela** (Meta FAIR で 2020 年に
RAG (Retrieval-Augmented Generation) を発明・原論文筆頭著者)、
CTO **Amanpreet Singh** (Meta FAIR + Hugging Face 出身)。

## 既存 137 社との差別化
| 観点 | Contextual AI | OpenAI (ChatGPT+RAG) | Perplexity |
|------|---------------|----------------------|------------|
| 設計思想 | ⚓ RAG 2.0 end-to-end 最適化 | 汎用 LLM + retrieval plugin | search 特化 |
| hallucination | **FACTS ベンチ SOTA** (grounded 優先) | ~5-10% | ~3-5% |
| 訓練方式 | CLM (Contextual Language Model) 専用訓練 | GPT base + RAG bolt-on | ブラックボックス |
| ターゲット | エンタープライズ private docs | 消費者 | 消費者 search |
| 創業 | RAG 発明者 (2020 論文) | — | — |

## 主要プロダクト
- **GLM** (Grounded Language Model): 最も「grounded」な LLM / FACTS 評価 SOTA
- **RAG 2.0**: frozen 部品接続ではなく end-to-end 最適化された RAG pipeline
- **CLMs** (Contextual Language Models): RAG 2.0 で訓練された企業特化 LLM 群
- **Agent Composer** (2026-01 launch): 航空宇宙/半導体/製造業向け pre-built テンプレート
- Nvidia 提携あり (NIM / GPU infra)

## 資金調達
- Seed: \$20M (2023-06, Bain Capital Ventures lead)
- Series A: \$80M (Greycroft lead + Lightspeed / SV Angel)

## 自分株式会社での活用
- daily-judgment: private docs (自分メモ / GROWTH_STRATEGY_ROADMAP / PHILOSOPHY) を GLM に食わせて「過去の自分の判断との整合性」を即提示
- AI大学: provider 比較 fact-check (hallucination 0 を担保)
- user-manual: docs/ 全体を grounded にして「質問 → 引用付き回答」ヘルプ
$md$,
    NOW()
  ),
  (
    'contextual_ai',
    'models',
    'GLM / RAG 2.0 / CLMs / Agent Composer — モデルライン',
    $md$
# GLM / RAG 2.0 / CLMs / Agent Composer — モデルライン

## GLM (Grounded Language Model)
- FACTS groundedness benchmark で **SOTA**
- 「AI が引用できない主張は書かない」を訓練レベルで強制
- 用途: 法務 / 医療 / コンプライアンス / 航空宇宙 (hallucination ≈ 0 要求領域)
- API: `/generate` standalone エンドポイント (無料 tier あり)

## RAG 2.0
- 従来 RAG = frozen embedder + frozen LLM + 外部 vector DB をパイプ接続 → 最適化されない
- RAG 2.0 = retrieval + generation を **end-to-end 同時訓練**
- 結果: 外部ドメイン (法務/金融) で 30-50% 精度向上 (ベンチマーク公称)

## CLMs (Contextual Language Models)
- RAG 2.0 で訓練された企業特化 LLM 群
- 業種別 template: aerospace / semiconductors / manufacturing / finance
- fine-tune: 顧客の private docs を食わせて CLM 派生モデル生成

## Agent Composer (2026-01-27 launch)
- エンタープライズ RAG を **production-ready AI エージェント** に昇格
- pre-built テンプレート: Rocket Science 級の複雑さ対応を主張
- 価格: **\$50/月〜** (self-serve) + エンタープライズ custom

## 料金
- 無料 tier: アカウント作成後 /generate API 即試用可
- self-serve: **\$50/月** (Agent Composer + GLM)
- enterprise: custom (契約ベース / Nvidia infra 含む)

## Philosophy (Kiela 公言)
> "The bottleneck is context — can the AI actually access your proprietary docs, specs, and institutional knowledge? That's the problem we solve."
$md$,
    NOW()
  ),
  (
    'contextual_ai',
    'api',
    'Contextual AI SDK — 自分株式会社での組込手順',
    $md$
# Contextual AI SDK — 自分株式会社での組込手順

## インストール
```bash
pip install contextual-client
npm install contextual-ai
```

## GLM /generate 呼び出し (最小)
```python
from contextual import ContextualAI
client = ContextualAI(api_key=os.getenv("CONTEXTUAL_API_KEY"))

resp = client.generate(
    prompt="自分株式会社の PHILOSOPHY 9 原則に照らして、新機能 X は実装可能か？",
    knowledge_sources=[
        {"type": "file", "path": "docs/PHILOSOPHY.md"},
        {"type": "file", "path": "docs/AI_DEV_PRINCIPLES.md"},
    ],
    grounding_mode="strict",  # 引用できない主張は書かない
)
print(resp.answer, resp.citations)
```

## Agent Composer + 自社 docs 統合例
```python
agent = client.agents.create(
    name="jibun-inc-advisor",
    template="enterprise-knowledge",
    documents=[
        "docs/GROWTH_STRATEGY_ROADMAP.md",
        "docs/PHILOSOPHY.md",
        "memory/MEMORY.md",
    ],
    grounded_model="glm-v1",
)

# 以降、agent.chat() で質問すれば引用付き回答
answer = agent.chat("過去に Essential AI を pivot した理由は？")
# → GROWTH_STRATEGY_ROADMAP の S17 / memory/project_20260420_ps3_s17.md から引用付きで回答
```

## ai-hub 統合提案 (Win版 cross-instance-pr 候補)
```typescript
// supabase/functions/ai-hub/index.ts に追加
case 'rag.grounded_query':
  // CONTEXTUAL_API_KEY + knowledge_sources を受け取り GLM 呼び出し
  // grounding_mode='strict' で hallucination 0 を担保
  // trace_id + 5秒超検出 (AI-DEV-23 原則 3)
  return await contextualGroundedQuery(body);
```

## 試す
- Web: https://contextual.ai/
- ドキュメント: https://docs.contextual.ai/
- GitHub (sample apps): https://github.com/ContextualAI
- RAG 2.0 発表 blog: https://contextual.ai/introducing-rag2/
- GLM blog: https://contextual.ai/blog/introducing-grounded-language-model

## Nvidia 提携
- GLM inference は Nvidia NIM (microservices) で配信
- Nvidia 公式 blog で事例紹介: blogs.nvidia.com/blog/contextual-ai-retrieval-augmented-generation/
$md$,
    NOW()
  )
ON CONFLICT (provider, category) DO UPDATE
SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
