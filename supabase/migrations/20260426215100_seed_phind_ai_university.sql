-- PS#3 S67: AI大学 228→229社化 — Phind 追加
-- Phind: 開発者特化AI検索エンジン / コード検索 / 独自LLM / StackOverflow超え

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'phind',
  'overview',
  'Phind — 開発者特化AI検索エンジン (独自LLM/コード検索/GPT-4超え/技術Q&A特化)',
  $$## Phind — 開発者特化AI検索エンジン

**カテゴリ**: AI Developer Search / Code Search / Developer Tool
**設立**: 2022年 / 本社: San Francisco, CA / 資金調達: ~$7M (未公開 / Bootstrapに近い)
**特徴**: 開発者のための技術的な質問に特化したAI検索エンジン。独自のPhind-70B/CodeLlama-34Bモデルを活用し、コーディング質問でGPT-4を上回るベンチマーク結果を記録
**ユーザー**: ソフトウェアエンジニア / フロントエンド・バックエンド開発者 / DevOps / セキュリティ研究者
**評価**: 8/9

### 概要
Phind は **「開発者がGoogle/Stack Overflowで検索する代わりに使うAI」** として設計された技術特化検索エンジン。「React useEffect の依存配列が無限ループになる原因は?」「PostgreSQLでN+1問題を解決するSQLは?」など、開発現場での具体的な技術質問に対して、実際のコード例と詳細な説明を即座に提供する。

2023年に独自の **Phind-CodeLlama-34B** と **Phind-70B** モデルをリリースし、HumanEval (コード生成ベンチマーク) でGPT-4 Turboに匹敵するスコアを達成した。Perplexityがリアルタイム検索特化なのに対し、Phindはコードと技術文書の深い理解に特化している。

### 主な機能

**AI コード検索**
- 自然言語 → コードスニペット + 解説の組み合わせで回答
- 複数のソースを統合: Stack Overflow / GitHub / 公式ドキュメント / arXiv
- コードブロックのシンタックスハイライト / コピー / 実行
- 「なぜこのエラーが出るか」「どのライブラリを使うべきか」に最適

**Pair Programmer モード**
- コードを貼り付けて質問: 「このコードのバグを見つけて」「Rustに書き直して」
- エラーメッセージをそのまま貼れば原因と修正方法を即提示
- リファクタリング提案 / ドキュメント生成 / テストコード生成
- 長いコードファイルのコンテキスト理解 (100K+ トークン)

**Phind独自モデル**
- **Phind-70B**: 汎用コード特化LLM (Llama 3 70Bベースにファインチューニング)
- **Phind-CodeLlama-34B-v2**: コード生成特化 / HumanEval 73.8% (GPT-4 67%)
- GPT-4 / Claude 3.5 Sonnet も選択可能

**テクニカル検索の深さ**
- クエリに関連するGitHub Issueを自動参照
- 公式ドキュメントのバージョン別回答 (「React 18の並行機能は?」)
- セキュリティ脆弱性 (CVE) の説明と対処法
- パフォーマンスベンチマーク比較

### 競合との差別化
| 項目 | Phind | Perplexity | ChatGPT | GitHub Copilot |
|------|-------|-----------|---------|---------------|
| 技術質問特化 | ✅ 開発者専用 | △ (汎用) | △ | ✅ (IDE内) |
| Web検索統合 | ✅ | ✅ | △ | ❌ |
| 独自LLM | ✅ Phind-70B | ❌ | ❌ | ❌ |
| コード実行 | △ | ❌ | ✅ (有料) | ✅ |
| 無料利用 | ✅ 充実 | △ (制限) | △ | ❌ |
| IDE統合 | ✅ VS Code | ❌ | ✅ (有料) | ✅ |

### 導入コスト
- **Free**: 無制限質問 / Phind-70B / GPT-4 (1日2回) / Pair Programmer (基本)
- **Pro**: 月$20 / GPT-4 無制限 / Claude 3.5 無制限 / Pair Programmer (フル) / プライベートモード$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'phind',
  'api',
  'Phind API — コード検索・技術Q&A自動化・VS Code拡張連携 (Python/TypeScript)',
  $$## Phind API / 統合

### 概要
Phind は OpenAI互換 API を提供 (ベータ)。技術Q&A・コード生成を自動化できる。

### OpenAI互換 API
```bash
export PHIND_API_KEY="your_api_key_here"
```

```python
from openai import OpenAI
import os

# Phind は OpenAI 互換 API を提供
client = OpenAI(
    api_key=os.environ["PHIND_API_KEY"],
    base_url="https://https.extension.phind.com/agent/",
)

def ask_phind(question: str, model: str = "Phind-70B") -> str:
    """Phindに技術質問を投げてコード付き回答を取得"""
    response = client.chat.completions.create(
        model=model,
        messages=[
            {
                "role": "system",
                "content": "You are a senior software engineer. Provide concise, accurate technical answers with code examples.",
            },
            {
                "role": "user",
                "content": question,
            },
        ],
        max_tokens=2000,
        stream=False,
    )
    return response.choices[0].message.content

# 技術質問の自動回答
answer = ask_phind(
    "Flutter WebでSupabase RLSポリシーのデバッグ方法は? エラーコード42501が出ている"
)
print(answer)
```

### Pair Programmer API (コード解析)
```python
def analyze_code(code: str, task: str) -> str:
    """コードをPhindで解析・改善"""
    prompt = f"""以下のコードについて: {task}

```dart
{code}
```

具体的な修正案とその理由を説明してください。"""

    return ask_phind(prompt)

# Flutter Dartコードのレビュー
dart_code = """
Future<void> fetchData() async {
  final response = await supabase.from('users').select();
  setState(() {
    data = response as List;
  });
}
"""

review = analyze_code(
    code=dart_code,
    task="エラーハンドリングが不十分な箇所と、null安全性の問題を指摘して修正案を提示してください",
)
print(review)
```

### VS Code 拡張連携 (Phind for VS Code)
```json
// .vscode/settings.json — Phind VS Code拡張設定
{
  "phind.apiKey": "${env:PHIND_API_KEY}",
  "phind.defaultModel": "Phind-70B",
  "phind.enableInlineCompletion": true,
  "phind.contextLines": 50,
  "phind.languages": ["dart", "python", "typescript", "sql"]
}
```

```typescript
// VS Code拡張API経由でPhindを呼び出す例
import * as vscode from 'vscode';

async function askPhindAboutSelection() {
  const editor = vscode.window.activeTextEditor;
  if (!editor) return;

  const selection = editor.document.getText(editor.selection);
  const question = await vscode.window.showInputBox({
    prompt: "Phindに何を聞きますか?",
    placeHolder: "例: このコードのバグを見つけて",
  });

  if (question && selection) {
    // Phind APIを呼び出して回答をWebviewに表示
    const answer = await callPhindAPI(selection, question);
    showPhindPanel(answer);
  }
}
```

### GHA × Phind コードレビュー自動化
```yaml
# .github/workflows/phind-code-review.yml
# PR作成時 → Phindで変更コードを自動レビュー → コメント投稿
on:
  pull_request:
    types: [opened, synchronize]

steps:
  - name: Phind automated code review
    env:
      PHIND_API_KEY: ${{ secrets.PHIND_API_KEY }}
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    run: python scripts/phind_code_review.py --pr-number ${{ github.event.number }}
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'phind',
  'models',
  'Phind AI技術詳細 — Phind-70B/CodeLlama-34B独自モデル + HumanEvalベンチマーク + 開発者LLMの進化',
  $$## Phind AI 技術詳細

### Phind独自モデルの系譜
```
Phind独自モデル開発史:

2023年6月: Phind-CodeLlama-34B-v1
  - Meta CodeLlama-34B をベースに開発者Q&Aデータでファインチューニング
  - HumanEval: 59.5% (GPT-3.5 Turbo の 48.1% を上回る)

2023年8月: Phind-CodeLlama-34B-v2
  - 高品質コーディングデータセットで追加学習
  - HumanEval: 73.8% (当時の GPT-4 の 67.0% を超過!)
  - Python特化サブモデル: HumanEval Python 82.0%

2024年: Phind-70B
  - Llama 3 70B ベースに独自ファインチューニング
  - コード生成・デバッグ・技術Q&Aの全方面で性能向上
  - 実用的なコーディングタスクでGPT-4o比較で互角以上
```

### 技術検索アーキテクチャ
```
[Phindの検索パイプライン]

ユーザーの技術クエリ
       ↓
Query Analysis:
  - 技術スタック検出 (React/Python/Go/Dart 等)
  - エラーコード抽出 (SQLSTATE/HTTP code/Exception type)
  - バージョン推定 (「React 18の...」→ React 18 context)
       ↓
Source Selection & Retrieval:
  優先度: 公式ドキュメント > GitHub Issues/PRs > Stack Overflow > ブログ
  - 公式ドキュメント: React.dev / docs.python.org / pkg.go.dev 等
  - GitHub: 実際のバグ修正コミット・Issueの解決策
  - Stack Overflow: 高スコア回答 (投票数 / 承認済み優先)
  - arXiv: アルゴリズム・ML技術の場合
       ↓
Answer Synthesis (Phind-70B):
  - 複数ソースを統合してコーディング文脈で回答生成
  - コードブロックは必ず動作確認済みパターンを使用
  - 複数解法がある場合はトレードオフを明示
       ↓
Citation & Verification:
  - 全コードスニペットにソースURLを付与
  - バージョン対応情報を明示 (「React 18以降は...」)
       ↓
出力: コード例 + 説明 + ソースリンク
```

### コード生成ベンチマーク比較 (2024年)
```
HumanEval (コード生成正解率):
  Phind-CodeLlama-34B-v2: 73.8% ★
  GPT-4 (2023年):          67.0%
  GPT-4o (2024年):         90.2%
  Claude 3.5 Sonnet:       92.0%
  Phind-70B:               ~85% (推定)

→ Phind-34B は2023年に一時GPT-4超えを達成
→ 2024年以降はGPT-4o/Claude 3.5が再リード
→ Phind の競争優位は「モデル精度」より「開発者向けUX + 検索統合」
```

### 開発者LLM市場の変化
```
2022年以前: Stack Overflow 一強時代
  → 人間が書いた回答 / 検索・閲覧 / コミュニティ投票

2023年: GitHub Copilot + ChatGPT で転換
  → IDE内補完 + 汎用チャット / Stack Overflow流入激減

2024年以降: 専門特化AI検索が台頭
  → Phind: コード検索特化
  → Perplexity: リアルタイム検索
  → Cursor/Windsurf: IDE統合深化

→ Stack Overflow の月間訪問者数が2022年比で40%減少 (2024年)
→ 開発者のQ&A消費行動がAIシフトしている
```

### 自分株式会社での活用可能性
- **Flutter/Dart開発加速**: Phind VS Code拡張 → Dart/Flutter の型エラー・null safety問題をリアルタイム解決
- **Supabase SQL最適化**: 「このクエリのN+1問題を解決するSQL」をPhindで即座に取得
- **AI大学コンテンツ**: Phind APIでコード例の品質チェック → ai_university_contentのAPIセクションをPhindで検証
- **GHA自動コードレビュー**: PR作成時にPhindで変更コードをレビュー → 初期品質向上 (claude-agent-review.ymlの補完)
- **Deno/Edge Function開発**: TypeScript/Deno特有の型エラーをPhindが解決 (Denoドキュメント統合)$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 228→229社化: Phind 追加',
  'PS#3 S67。Phind (開発者特化AI検索/独自Phind-70B/Phind-CodeLlama-34B HumanEval73.8%/Web検索統合/Pair Programmer/VS Code拡張/無料充実/8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
