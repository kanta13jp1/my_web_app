-- PS#3 S123: AI大学 341→342社化 — Tabnine (エンタープライズ向けプライベートAIコード補完)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'tabnine', 'overview',
  'Tabnine — エンタープライズ向けプライベートAIコード補完・ローカル実行・コード非送信・全IDE対応 (9/9)',
  $$## Tabnine とは

**Tabnine** は**エンタープライズ向けのプライベート AI コード補完ツール**。2018年に登場した AI コーディングアシスタントの先駆者で、**コードをサーバーに送信しない（ローカル実行）** を最大の差別化ポイントとしている。

GitHub Copilot / Cursor が台頭する中、**セキュリティ・プライバシー・コンプライアンス重視の企業**（金融・医療・政府・防衛）に根強い需要がある。「コードを外部に出せない」企業のための GitHub Copilot 代替。

## Tabnine の特徴

```
Tabnine のアーキテクチャ:

  デプロイモデル (選択可):
    ・Cloud: Tabnine のクラウドで処理 (コード送信あり)
    ・On-premise: 企業のサーバーで完全自己ホスト
    ・Air-gapped: インターネット完全切断環境でも動作

  プライバシー保護:
    ・コードの機械学習への使用禁止 (デフォルト)
    ・テレメトリーのオフ設定
    ・SOC 2 Type II 取得
    ・GDPR / CCPA 対応
    ・IP 保護: 生成コードの著作権を企業に帰属

  パーソナライゼーション:
    ・自社コードベースで追加学習 (Fine-tuning)
    ・コーディングスタイル・命名規則を学習
    ・チーム固有のパターンを習得
```

## 対応 IDE

- **JetBrains 全製品** (IntelliJ / PyCharm / WebStorm / GoLand / Rider 等)
- **VS Code**
- **Visual Studio**
- **Neovim / Vim**
- **Eclipse**
- **Jupyter Notebook**

合計 15+ IDE に対応 (GitHub Copilot より多い)

## 料金体系

| プラン | 月額/人 | 特徴 |
|--------|---------|------|
| Free | $0 | 基本補完 (クラウド) |
| Pro | $12 | 高精度補完 + Chat |
| Enterprise | 要問い合わせ | オンプレ / Fine-tuning / SSO |

## セキュリティ規制対応

Tabnine が特に強い規制業種:

| 業種 | 主な要件 | Tabnine の対応 |
|------|----------|----------------|
| 金融 | コード外部送信禁止 | オンプレ対応 |
| 医療 | HIPAA 準拠 | BAA 締結可 |
| 政府・防衛 | エアギャップ環境 | Air-gapped 対応 |
| 製造 | 知的財産保護 | IP 保証 |

## GitHub Copilot vs Tabnine 比較

| 項目 | Tabnine | GitHub Copilot |
|------|---------|----------------|
| ローカル実行 | ○ (Enterprise) | × |
| オンプレ | ○ | ○ (GHE) |
| Fine-tuning | ○ | ○ (Copilot Enterprise) |
| 価格 | $12/月〜 | $10/月〜 |
| IDE 対応 | 15+ | VS Code / JetBrains等 |
| エアギャップ | ○ | × |

## 歴史と現在

- **2018年**: DeepTabNine として登場 (LSTM モデル)
- **2020年**: GPT-2 ベースモデルに移行
- **2022年**: LLM ベースに刷新、エンタープライズ注力
- **2024年**: Chat 機能 / コード説明 / テスト生成を追加
- **現在**: GitHub 14k+ stars / 100万+ 開発者が利用

## 自分株式会社との関連

Tabnine のアプローチ (プライバシー重視 / エンタープライズ) は、自分株式会社の B2B 展開フェーズで参考になる。顧客企業の「コードを外部に出したくない」というニーズへの対応策として、Tabnine の事業モデルを研究する価値がある。
$$,
  'https://www.tabnine.com',
  NOW(),
  342
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
