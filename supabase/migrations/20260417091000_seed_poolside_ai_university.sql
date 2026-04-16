-- Windowsアプリ版#本セッション: Poolside AI 大学コンテンツ seed
-- コーディング特化の次世代LLM — Malibu & Point モデル

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

('poolside', 'overview',
'Poolside AI: ソフトウェア開発専用の次世代LLM',
$$# Poolside AI

Poolsideは「ソフトウェアエンジニアリングに特化したフロンティアモデル」を開発するスタートアップ。
Devin (Cognition) と並ぶ「AIソフトウェアエンジニア」分野のパイオニアで、
コーディング能力に徹底的に絞り込んだ独自アーキテクチャが特徴。

## 設立背景

- **創業**: 2023年、Jason Warner (前GitHub CTO) × Eiso Kant (GitSensors CEO)
- **資金調達**: $500M+ (a16z / Salesforce Ventures / Dell Technologies Capital 等)
- **評価額**: $3B+ (2024年)
- **哲学**: 「汎用AIより、ソフトウェア開発に特化したAIを極める」

## 主要製品

| 製品 | 説明 |
|------|------|
| **Malibu** | フラッグシップ。複雑なコード生成・テスト・リファクタリング向け。最大のコーディングLLM |
| **Point** | コード補完特化。リアルタイムで開発者の手元に届けることを優先 |

## Devinとの違い

```
Cognition Devin   → タスク実行エージェント (Issue→PR 自律完結)
Poolside Malibu   → 基盤モデル (LLM自体を提供。エージェントは別途構築)
                    ≒ 「コーディング版 Claude/GPT-4」
```

## 展開方法

1. **AWS Bedrock**: Amazon Bedrock上でMalibu/Pointが利用可能
2. **オンプレミス**: お客様環境内にデプロイ (データが外に出ない)
3. **エンタープライズ**: VPC/ワークステーション内での完全隔離展開

**評価**: 技術革新性8/9 · API利用可能性6/9 (Bedrock経由) · 話題性7/9
$$,
'https://poolside.ai/',
'2026-04-17', 1),

('poolside', 'models',
'Malibu & Point: Poolside のモデル体系',
$$# Poolside モデル体系

## Malibu (フラッグシップ)

| 項目 | 詳細 |
|------|------|
| **用途** | 複雑なコード生成・アーキテクチャ設計・大規模リファクタリング |
| **特徴** | コーディングベンチマーク(HumanEval/SWE-bench)で高スコア |
| **訓練手法** | RL (強化学習) + 合成データ生成による独自アプローチ |
| **展開** | AWS Bedrock / オンプレミス |
| **得意** | 複雑なバグ修正・型安全なコード変換・テスト生成 |

## Point (コード補完特化)

| 項目 | 詳細 |
|------|------|
| **用途** | リアルタイムコード補完 (GitHub Copilot的な用途) |
| **特徴** | 低レイテンシ・高精度のコンテキスト補完 |
| **統合** | VS Code / JetBrains IDEプラグイン対応 |

## 独自訓練アプローチ

Poolsideの強みは「合成訓練データ生成」にある:

```
1. 実際のコードベースから問題を自動生成
2. 正解コードを自動検証 (テスト実行で判定)
3. 強化学習でモデルを繰り返し改善
4. 人手によるラベル付けを最小化 → スケールが容易
```

これにより「コードの実行可否」という客観的な評価軸で学習できる。

## 他モデルとの比較

| モデル | コーディング | 汎用性 | 展開形態 |
|--------|-------------|--------|----------|
| **Malibu** | 🏆 最高特化 | 限定的 | Bedrock/オンプレ |
| GPT-4.1 | 高 | 高 | API |
| Claude Sonnet 4.6 | 高 | 高 | API |
| Devin | エージェント | エージェント | SaaS |
$$,
'https://poolside.ai/',
'2026-04-17', 2),

('poolside', 'api',
'Poolside API: AWS Bedrock 経由アクセスガイド',
$$# Poolside API (AWS Bedrock 経由)

## 概要

Poolsideのモデルは**AWS Bedrock**経由でアクセス可能。
直接APIは現在エンタープライズ契約が必要だが、Bedrock経由であれば標準的なAWS権限で利用可。

## AWS Bedrock 経由の使い方

```python
import boto3
import json

bedrock = boto3.client(
    service_name='bedrock-runtime',
    region_name='us-east-1'
)

# Poolside Malibu を呼び出す
response = bedrock.invoke_model(
    modelId='poolside.malibu-v1',
    body=json.dumps({
        "prompt": "以下のDartコードにユニットテストを書いてください:\n\n" +
                  "Future<User> fetchUser(String userId) async { ... }",
        "max_tokens": 2048,
        "temperature": 0.1  # コード生成は低温度推奨
    })
)

result = json.loads(response['body'].read())
print(result['completion'])
```

## オンプレミス展開 (エンタープライズ)

```yaml
# Poolside の特徴: データが外部に出ない完全隔離展開
deployment:
  type: "on-premises"  # または "vpc" / "workstation"
  model: "malibu-v1"
  hardware: "A100 x8"  # 推奨GPU構成

# Supabase Edge Functionから呼び出す場合
# 自社環境のPoolsideエンドポイントにHTTP POSTするだけ
```

## コスト比較 (AWS Bedrock 経由)

| モデル | Input ($/1MTok) | Output ($/1MTok) |
|--------|-----------------|------------------|
| Poolside Malibu | ~$5 (推定) | ~$15 (推定) |
| Claude Sonnet 4.6 | $3 | $15 |
| GPT-4.1 | $2 | $8 |

※ Malibu の料金はエンタープライズ交渉ベース。Bedrock定価は要確認。

## このプロジェクトとの関連

- `ai-assistant` EF の `synthesisModel` にPoolside Malibuを選択肢として追加可能
- Flutter/Dart コードのリファクタリング → Malibuは特化訓練のため品質が高い可能性
- データセキュリティ重視のプロジェクトではオンプレ展開が魅力
$$,
'https://aws.amazon.com/bedrock/poolside/',
'2026-04-17', 3),

('poolside', 'news',
'Poolside AI 最新ニュース (2026-04-17)',
$$# Poolside AI 最新動向 (2026-04-17)

## 主要アップデート

### AWS Bedrock での提供開始
PoolsideとAWSの戦略的パートナーシップにより、MalibuとPointがAmazon Bedrockで利用可能に。
AWS顧客は既存のAWS資格情報でPoolsideモデルにアクセスできる。

### エンタープライズ向け展開強化
オンプレミス・VPC内展開がより簡単になる管理ツールのリリース。
金融・医療・国防などセキュリティ重視の業界での採用が加速。

### 合成データ生成技術の公開
Poolsideの独自アプローチ「実行可能コードを評価軸にした強化学習」の技術的詳細を一部公開。
「正しく動くコードを生成する」ことに特化した訓練パイプラインがAI業界の注目を集める。

## 競合比較: コーディングAI 2026年版

| ツール | 種別 | 特化度 | 利用形態 |
|--------|------|--------|----------|
| **Poolside Malibu** | 基盤モデル | コーディング最特化 | Bedrock/オンプレ |
| **Cognition Devin** | エージェント | ソフトウェアエンジニア | SaaS |
| **Cursor** | IDE | コーディング補助 | SaaS |
| **GitHub Copilot** | IDE補完 | コーディング補助 | SaaS |
| **Claude Code** | CLIエージェント | 汎用コーディング | CLI/API |

## このプロジェクトへの示唆

- **Claude Code の立ち位置確認**: Poolside/Devinの台頭により「コーディングAI」競争が激化
  → Claude Codeの差別化は「プロジェクト文脈の深い理解」と「マルチインスタンス協調」
- **将来の ai-assistant EF**: Poolside MalibuをDartコード生成オプションとして組み込む余地あり
- **4インスタンス体制の競争優位**: Poolside/Devinは単一エージェント。当プロジェクトのMulti-AIアーキテクチャは独自の強み
$$,
'https://poolside.ai/',
'2026-04-17', 4)

ON CONFLICT (provider, category) DO UPDATE
  SET content = EXCLUDED.content,
      source_url = EXCLUDED.source_url,
      published_at = EXCLUDED.published_at,
      updated_at = now();
