-- PS#3 S124: AI大学 343→344社化 — Amazon Q Developer (旧CodeWhisperer / AWS統合AIコーディング)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'amazon-q-developer', 'overview',
  'Amazon Q Developer — AWS製AIコーディング・旧CodeWhisperer・AWS統合最強・エンタープライズ向け (9/9)',
  $$## Amazon Q Developer とは

**Amazon Q Developer**（旧称: **Amazon CodeWhisperer**）は **AWS (Amazon Web Services)** が提供する AI コーディングアシスタント。2023年に CodeWhisperer から Q Developer にリブランディングされ、機能が大幅拡張された。

**AWS サービスとの深い統合**が最大の強み。Lambda / DynamoDB / S3 / CloudFormation / CDK などの AWS リソースを自然言語で操作・設定できる。AWS を使う企業にとって最も自然な AI コーディングアシスタント。

## Amazon Q Developer の機能

```
Q Developer の主要機能:

  コーディング支援:
    ・インライン補完 (コード補完)
    ・チャット (質問・説明・リファクタリング)
    ・テスト生成
    ・バグ修正提案

  AWS 特化機能:
    ・/dev: 自律的なコード実装 (マルチターン)
    ・/review: コードレビュー (セキュリティ・品質)
    ・/transform: コードの変換 (Java 8→17等)
    ・/doc: ドキュメント生成
    ・/test: テスト生成

  インフラ支援:
    ・CloudFormation テンプレート生成
    ・CDK コード生成
    ・AWS CLI コマンド提案
    ・IAM ポリシー最適化提案
    ・コスト最適化提案

  セキュリティスキャン:
    ・コードの脆弱性自動検出
    ・OWASP Top 10 対応
    ・AWS セキュリティベストプラクティス
```

## AWS 統合の深さ

Q Developer は AWS のサービスとシームレスに連携:

- **AWS Console**: コンソール上で直接 AI と対話
- **AWS CLI**: コマンドを自然言語で生成
- **CloudShell**: ブラウザベース CLI での AI 支援
- **CodeCatalyst**: AWS の統合開発環境
- **Lambda**: 関数の設計・デプロイを支援

## 料金体系

| プラン | 月額 | 特徴 |
|--------|------|------|
| Free | $0 | 補完無制限 + チャット 50回/月 |
| Pro | $19/人 | 無制限 + /dev + /transform |
| Enterprise | 要問い合わせ | IAM 統合 / 監査ログ / VPC |

**注目**: 無料プランの補完が**無制限**（GitHub Copilot は有料のみ）

## /transform 機能 (コード変換)

特に注目の機能が `/transform`:
- **Java 8 → Java 17** の自動アップグレード
- **コードベース全体を分析**して互換性を確保
- 大規模なレガシーコード移行を自動化

## セキュリティとコンプライアンス

- **SOC 2 / ISO 27001 / GDPR** 対応
- **コードはトレーニングに使用しない**（Enterprise）
- **AWS PrivateLink** 対応（VPC 内で完結）
- **Amazon CodeGuru Security** との統合

## 対応 IDE

- VS Code
- JetBrains 全製品
- Visual Studio
- AWS Cloud9
- AWS Lambda コンソール
- JupyterLab

## GitHub Copilot vs Amazon Q Developer

| 項目 | Amazon Q | GitHub Copilot |
|------|----------|----------------|
| AWS 特化 | ◎ | △ |
| 無料補完 | 無制限 | なし |
| /transform | ○ | × |
| セキュリティスキャン | ○ | Copilot Enterprise |
| 価格 Pro | $19/月 | $10/月 |
| 製造元 | Amazon | Microsoft/GitHub |

## 自分株式会社との関連

自分株式会社のインフラは **Firebase Hosting + Supabase** が主軸だが、将来的な AWS 移行や Lambda 活用時には Amazon Q Developer が重要ツールとなる。また、競合分析（Amazon が AI コーディングに本格参入）として AI 大学コンテンツに必須。
$$,
  'https://aws.amazon.com/q/developer/',
  NOW(),
  344
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
