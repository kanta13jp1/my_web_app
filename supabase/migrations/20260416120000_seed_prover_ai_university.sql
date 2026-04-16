-- Prover: 定理証明・形式検証特化型AI (2026-04-16)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('prover', 'overview', 'Prover 概要 — 定理証明と形式検証の AI',
$$## Prover とは

Prover は定理証明（Theorem Proving）と形式検証（Formal Verification）に特化した AI エンジンです。
数学や科学領域で最先端の正確性を求められるタスクに対応し、
汎用 LLM では到達できない SOTA（最先端技術）を達成しています。

数学の証明検証、ソフトウェアの形式的正確性保証、
暗号プロトコルの検証など、エラーが許されないドメインでユニークな価値を発揮します。

## 主要サービス

- **Theorem Prover**: Lean / Coq などの証明言語で定理の正確性を機械的に検証
- **Formal Verification**: スマートコントラクト・組み込みシステムの形式的安全性証明
- **Mathematical AI Assistant**: 複雑な数学問題の段階的解法とその正確性保証
- **Logic Analysis Engine**: 論理的矛盾の検出と形式システムの正当性検証

## 強み

- **数学領域での高精度**: GPT-4 や Claude を遥かに上回る定理証明成功率
- **検証可能性**: AI の出力が機械的に検証可能な形で提示される
- **業界標準ツール統合**: Lean 4、Coq、Isabelle など標準形式言語に対応
- **形式検証による安全性**: ブロックチェーン・航空宇宙など安全性クリティカルな業界に対応
$$,
'https://www.prover.io/', '2026-04-16', 1),

('prover', 'models', 'Prover エンジン一覧 (2026)',
$$## Theorem Prover コア

| エンジン | 特性 | 対応言語 | 用途 |
| :--- | :--- | :--- | :--- |
| **Lean 4 Integration** | 依存型の完全検証 | Lean 4 / Lean 3 | 高度な数学定理 |
| **Coq Companion** | 構成的証明支援 | Coq 8.x | 型理論・カテゴリー理論 |
| **SMT Solver Hub** | 制約充足・充足可能性判定 | SMT-LIB 2.0 | 形式検証の基礎 |
| **Symbolic Math Engine** | 数式の厳密変形 | SymPy / Mathematica | 解析的計算 |

## 特徴的な機能

- **インタラクティブ証明**: ユーザーの手が止まったとき自動的に証明ステップを提案
- **証明の可視化**: 複雑な証明を段階的に図表化、理解を助ける
- **多言語証明変換**: Lean ↔ Coq などの標準形式間での証明移植
- **バックトラック機能**: 証明の行き止まりから自動的に別解を探索
$$,
'https://www.prover.io/', '2026-04-16', 2),

('prover', 'api', 'Prover API 入門 — 定理証明をプログラムから呼び出す',
$$## Prover API の始め方

### API エンドポイント

\`\`\`bash
# ベータプログラム登録（申し込みフォーム）
https://www.prover.io/api-beta

# エンドポイント
POST https://api.prover.io/v1/theorems/verify
Authorization: Bearer YOUR_BETA_API_KEY
\`\`\`

### Python での使用例

\`\`\`python
import requests

api_key = "prv_beta_xxxxx"
headers = {"Authorization": f"Bearer {api_key}"}

# Lean 4 コードで定理を検証
theorem_code = """
theorem two_add_two_eq_four : 2 + 2 = 4 := by
  norm_num
"""

response = requests.post(
    "https://api.prover.io/v1/theorems/verify",
    json={
        "language": "lean4",
        "theorem": theorem_code,
        "timeout_seconds": 30
    },
    headers=headers
)

result = response.json()
# result: {"status": "valid", "proof_steps": [...], "error": null}
```

## 料金 (2026 年 4 月現在)

- **ベータ期間**: 無料（申し込み制）
- **本格運用**: 検証リクエスト数による従量課金
  - **基本層**: $0.01 ~ $0.05 / 定理
  - **エンタープライズ**: ボリュームディスカウント

## ベータプログラムへの登録

1. https://www.prover.io/api-beta にアクセス
2. 氏名・メール・ユースケースを入力
3. 数営業日以内に API キーが発行される
4. ドキュメント: https://docs.prover.io/api に従って統合開始
$$,
'https://www.prover.io/', '2026-04-16', 3)

ON CONFLICT DO NOTHING;
