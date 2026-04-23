-- Session PS#3-S29: AI大学 153社化 — E2B 追加
-- Vasek Mlejnsky (元 Google) が 2022 年に創業した AI エージェント向けコード実行サンドボックス インフラ。
-- $21M Series A (Insight Partners 主導) / 累計 $43.8M / Fortune 100 の 88% が採用済み。
-- Linux microVM ベースのサンドボックスが 200ms 未満で起動・Python/JS SDK で即時制御可能。
-- Hobby (無料 + $100 クレジット) / Pro $150/月 / Enterprise $3,000/月〜 の段階プラン。
-- 既存 152 社に空白だった「AI エージェント コード実行サンドボックス インフラ」軸を埋める。
-- Step 0: 8.5/9 (AI エージェント開発必須ツール / Fortune 100 実績)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'e2b',
  'overview',
  'E2B — AI エージェントのためのセキュアなコード実行クラウドインフラ',
  $md$
# E2B — The Enterprise AI Agent Cloud

2022 年創業。**Vasek Mlejnsky** (元 Google) が「AI エージェントが生成したコードを
安全かつ高速に実行できるクラウドインフラ」を目指して設立。

Linux マイクロ VM ベースの **セキュアサンドボックス** を 200ms 未満で起動し、
AI エージェントが Python・JavaScript・TypeScript・Shell など任意の言語で
コードを実行・データ処理・ツール呼び出しを行える環境を API として提供。

OpenAI Codex Interpreter・Anthropic Claude Code・Google Gemini など
主要 AI システムのコード実行バックエンドとして実績を持つ。

## 主要プロダクト
- **E2B Sandbox** — 汎用コード実行サンドボックス (任意言語・カスタムテンプレート対応)
- **E2B Code Interpreter** — Python / JS/TS 向け Jupyter 互換のコード実行 SDK
- **E2B Desktop** — GUI デスクトップ環境付きサンドボックス (Computer Use 対応)
- **E2B Fragments** — Next.js 製のオープンソースコードサンドボックス UI
- **カスタムテンプレート** — Dockerfile ベースで独自環境を定義・再利用可能

## 強み
- **Fortune 100 の 88%** が採用済み — エンタープライズグレードの信頼性
- **200ms 未満**でサンドボックス起動 — エージェントのレスポンス速度を維持
- **完全分離** — ホスト環境と隔離された Linux microVM で安全なコード実行
- **オープンソース** — GitHub で公開 (e2b-dev/E2B)、ベンダーロックイン回避可能
$md$,
  'https://e2b.dev/',
  '2026-04-24',
  1
),

(
  'e2b',
  'models',
  'E2B サンドボックス ランタイム一覧 (2026)',
  $md$
## E2B サンドボックスの種類

E2B は「モデル」ではなく「実行環境 (サンドボックス)」を提供する。

## 標準サンドボックス

| サンドボックス | 対応言語 | セッション上限 | 特徴 |
| :--- | :--- | :--- | :--- |
| **Sandbox (汎用)** | 任意 (Dockerfile) | Hobby: 1時間 / Pro: 24時間 | カスタムテンプレート対応 |
| **Code Interpreter** | Python / JS / TS | 同上 | Jupyter 互換・グラフ出力対応 |
| **Desktop** | 任意 | 同上 | GUI・ブラウザ操作・Computer Use |

## カスタムテンプレート

Dockerfile を使って独自の実行環境を定義できる。

```dockerfile
FROM e2bdev/code-interpreter:latest

# 追加パッケージのインストール
RUN pip install pandas numpy matplotlib scikit-learn

# カスタムファイルの配置
COPY ./data /home/user/data
```

## プラン別同時実行数

| プラン | 同時サンドボックス数 | セッション最大時間 |
| :--- | :--- | :--- |
| **Hobby** (無料) | 20 | 1 時間 |
| **Pro** ($150/月) | 100 | 24 時間 |
| **Enterprise** ($3,000/月〜) | 無制限 | 24 時間 |

## 対応 AI フレームワーク

LangChain・LlamaIndex・CrewAI・AutoGen・Mastra など主要エージェントフレームワークと統合済み。
$md$,
  'https://e2b.dev/docs',
  '2026-04-24',
  2
),

(
  'e2b',
  'api',
  'E2B API 入門',
  $md$
## E2B API の始め方

```python
# pip install e2b-code-interpreter
from e2b_code_interpreter import Sandbox

# サンドボックス起動 (200ms 未満)
with Sandbox() as sandbox:
    # Python コードを実行
    execution = sandbox.run_code("print('Hello from E2B!')")
    print(execution.text)  # Hello from E2B!

    # データ分析の例
    result = sandbox.run_code("""
import pandas as pd
import matplotlib.pyplot as plt

df = pd.DataFrame({'x': range(10), 'y': [i**2 for i in range(10)]})
print(df.describe())
""")
    print(result.text)
```

## AI エージェントとの統合例

```python
from e2b_code_interpreter import Sandbox
from anthropic import Anthropic

client = Anthropic()
sandbox = Sandbox()

# Claude にコード生成させて E2B で実行
response = client.messages.create(
    model="claude-opus-4-7-20251101",
    max_tokens=1024,
    messages=[{
        "role": "user",
        "content": "フィボナッチ数列の最初の10項を計算する Python コードを書いて"
    }]
)

# E2B でコードを実行
code = response.content[0].text
execution = sandbox.run_code(code)
print(execution.text)

sandbox.kill()
```

## 料金 (2026年4月時点)

| プラン | 料金 | サンドボックス時間 |
| :--- | :--- | :--- |
| **Hobby** | 無料 + $100 クレジット | $0.000014 / 秒 (vCPU×秒) |
| **Pro** | $150 / 月 | 同上 |
| **Enterprise** | $3,000 / 月〜 | カスタム |

## クイックスタート

1. [e2b.dev](https://e2b.dev) でアカウント作成 → API キー取得
2. `pip install e2b-code-interpreter` または `npm install @e2b/code-interpreter`
3. 環境変数 `E2B_API_KEY` を設定
4. `Sandbox()` でサンドボックスを起動してコードを実行

## JavaScript/TypeScript

```typescript
import { Sandbox } from "@e2b/code-interpreter";

const sandbox = await Sandbox.create();
const result = await sandbox.runCode("console.log('Hello from E2B!')");
console.log(result.text);
await sandbox.kill();
```
$md$,
  'https://e2b.dev/docs',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
