-- Session PS#3-S50: AI大学 196→197社化 — Tabnine 追加
-- エンタープライズ向け AI コード補完ツール。オンプレミス/VPC デプロイが可能で
-- SOC2・GDPR 準拠。学習データに顧客コードを使用しない保証が企業に人気。
-- 1M+ 開発者が利用。$53M 調達済み。VS Code・JetBrains 対応。
-- Step 0: 8/9 (GitHub Copilot Enterprise代替 / オンプレ / SOC2 / 学習非使用保証 / 1M+開発者)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'tabnine',
  'overview',
  'Tabnine — エンタープライズ AI コード補完 (オンプレミス・SOC2・学習データ非使用保証)',
  $md$
# Tabnine — Enterprise AI Code Completion

**企業セキュリティ要件を満たす AI コード補完ツール**。
GitHub Copilot と同様の AI コード補完を提供しながら、
**オンプレミス/VPC デプロイ・SOC2 Type II・GDPR 準拠**に対応。

**1,000,000+ 開発者**が利用。$53M 調達済み。VS Code・JetBrains を含む主要 IDE に対応。

## GitHub Copilot との比較 (Enterprise 向け)

| 機能 | Tabnine | GitHub Copilot Enterprise |
| :--- | :--- | :--- |
| **価格** | $12/月/ユーザー〜 | $19/月/ユーザー |
| **オンプレミスデプロイ** | ✅ | — |
| **VPC 内完結** | ✅ | — |
| **学習データ非使用** | ✅ 法的保証 | オプト アウト必要 |
| **SOC2 Type II** | ✅ | ✅ |
| **GDPR** | ✅ EU データ残存 | ✅ |
| **カスタムモデル** | ✅ 社内コードで学習可 | ✅ |
| **FedRAMP** | 対応中 | — |

## 主要機能

### コード補完 (Autocomplete)
- 文脈に応じたマルチライン補完 (最大 50 行)
- 80+ プログラミング言語対応
- ローカルコンテキスト (開くファイル) を活用
- リアルタイム補完 (50ms 未満)

### Tabnine Chat
- IDE 内でコードについて質問・説明要求
- コード生成・バグ修正・リファクタリング
- ドキュメント生成 (JSDoc/Docstring)

### コードレビュー支援
- PR 変更を分析して潜在的な問題を指摘
- セキュリティ脆弱性の検出

## セキュリティ・コンプライアンス

### オンプレミスデプロイ
```
デプロイオプション:
1. SaaS (cloud.tabnine.com)
2. VPC (顧客 AWS/GCP/Azure 内)
3. オンプレミス (社内サーバー)

オンプレミス構成:
[開発者 IDE] → [社内 Tabnine Server] → [社内コードベース]
                ↑ インターネット不要
```

### データポリシー
- **学習非使用保証**: 顧客コードを Tabnine のモデル学習に使用しない旨を契約に明記
- **ゼロリテンション**: コードは処理後即時削除
- **暗号化**: TLS 1.2+ で転送中データを暗号化
$md$,
  'https://www.tabnine.com/',
  '2026-04-25',
  1
),

(
  'tabnine',
  'api',
  'Tabnine セットアップ — VS Code・JetBrains インストール・Enterprise VPC デプロイ・カスタムモデル',
  $md$
## VS Code へのインストール

```bash
# VS Code 拡張機能マーケットプレイス
# 検索: "Tabnine AI" → Install

# コマンドラインから
code --install-extension TabNine.tabnine-vscode

# アカウント作成 & ログイン
# VS Code 左サイドバー → Tabnine アイコン → Login / Sign Up
```

---

## 基本的な使い方 (VS Code)

```dart
// Dart でのコード補完例
// クラス名と extends を書くと補完候補が表示される

class AiProviderCard extends StatelessWidget {
  // Tab キーで補完を受け入れる (GitHub Copilot と同じ操作感)

  const AiProviderCard({
    super.key,
    required this.provider,
  });

  final AiProviderEntry provider;

  // "build(" と入力するだけで build メソッドを自動補完
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(provider.displayName),
        subtitle: Text(provider.note),
      ),
    );
  }
}
```

---

## JetBrains へのインストール

```
1. File → Settings → Plugins → Marketplace
2. "Tabnine" を検索 → Install
3. IDE を再起動
4. Tools → Tabnine → Login
```

---

## Tabnine Chat の使い方

```
# VS Code で Ctrl+Shift+P → "Tabnine: Open Chat"
# または左サイドバーの Tabnine アイコン → Chat

質問例:
- "このコードのバグを探して"
- "このクラスのユニットテストを書いて"
- "このメソッドを最適化して"
- "このコードを Flutter の最新ベストプラクティスに合わせてリファクタリングして"

# コードを選択してから質問すると精度が上がる
```

---

## Enterprise VPC デプロイ

```yaml
# AWS EKS への Tabnine Enterprise デプロイ例
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tabnine-server
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: tabnine-server
        image: tabnine/enterprise-server:latest
        env:
        - name: TABNINE_LICENSE_KEY
          valueFrom:
            secretKeyRef:
              name: tabnine-secrets
              key: license-key
        - name: MODEL_PATH
          value: "/models"
        resources:
          requests:
            memory: "16Gi"
            cpu: "4"
          limits:
            memory: "32Gi"
            nvidia.com/gpu: "1"  # GPU 推論で高速化
        ports:
        - containerPort: 5000
```

---

## カスタムモデル (社内コードで Fine-tuning)

```bash
# Tabnine Enterprise でカスタムモデルを作成
# 1. 社内コードをエクスポート
tabnine-admin export --repo /path/to/company/repos --output ./training-data

# 2. Fine-tuning ジョブを実行 (Tabnine サーバー側で処理)
tabnine-admin train --data ./training-data --model-name "company-model-v1"

# 3. 開発者側: settings.json でカスタムモデルを指定
# {
#   "tabnine.enterpriseServer": "https://tabnine.company.internal",
#   "tabnine.customModel": "company-model-v1"
# }
```

---

## GitHub Copilot からの移行チェックリスト

| 項目 | 手順 |
| :--- | :--- |
| 1. Copilot を無効化 | VS Code 拡張機能 → GitHub Copilot → Disable |
| 2. Tabnine をインストール | Marketplace → "Tabnine AI" → Install |
| 3. アカウント作成 | tabnine.com → Sign Up → Enterprise プラン選択 |
| 4. ログイン | VS Code → Tabnine アイコン → Login |
| 5. 動作確認 | コードを書いてサジェストが出るか確認 |

**移行後の主な違い**:
- `Tab` で補完受け入れ (同じ)
- Chat は Ctrl+Shift+P → "Tabnine: Open Chat"
- インラインチャット: コード選択 → 右クリック → "Tabnine: Ask"
$md$,
  'https://docs.tabnine.com/',
  '2026-04-25',
  2
),

(
  'tabnine',
  'models',
  'Tabnine 本番活用 — Flutter/Dart 開発・セキュリティコンプライアンス・このプロジェクトへの適用',
  $md$
## Flutter/Dart 開発での活用 (このプロジェクト向け)

```dart
// Tabnine は Flutter の StatefulWidget パターンを学習している
// クラス名 + extends StatefulWidget と入力するだけで全体を補完

class AiUniversityPage extends StatefulWidget {
  // Tabnine が createState・State クラスを自動補完
  const AiUniversityPage({super.key});

  @override
  State<AiUniversityPage> createState() => _AiUniversityPageState();
}

class _AiUniversityPageState extends State<AiUniversityPage> {
  // "List<AiProviderEntry> _providers" と入力 → initState も自動補完
  List<AiProviderEntry> _providers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchProviders();
  }

  // "_fetchProviders" と入力するだけで Supabase クエリを補完
  Future<void> _fetchProviders() async {
    final response = await supabase
        .from('ai_university_content')
        .select()
        .order('sort_order');
    setState(() {
      _providers = response.map(AiProviderEntry.fromJson).toList();
      _isLoading = false;
    });
  }
}
```

---

## エンタープライズ セキュリティ 評価チェックリスト

```
✅ データ非使用保証: 契約書に明記
✅ SOC2 Type II: 年次監査済み証明書あり
✅ GDPR: EU データ処理が EU 内で完結
✅ オンプレ: VPC 内完結でインターネット通信なし
✅ IP 所有権: 生成コードの知的財産権は開発者に帰属
✅ ライセンスフィルタ: GPL 等のコードを補完候補から除外可能

要確認:
□ FedRAMP (2024年対応中)
□ HIPAA Business Associate Agreement (要交渉)
□ ISO 27001 (要確認)
```

---

## コスト比較 (100名チーム)

| プラン | 月額 | 年額 | 特記事項 |
| :--- | :--- | :--- | :--- |
| **Starter (無料)** | $0 | $0 | 基本補完のみ / Chat なし |
| **Pro** | $12/ユーザー | $144/ユーザー | Chat + 全機能 |
| **Enterprise** | カスタム | カスタム | オンプレ + カスタムモデル |
| GitHub Copilot Enterprise | $19/ユーザー | $228/ユーザー | (比較) |

→ Enterprise 100名: GitHub Copilot の ~63% のコストで同等機能

---

## このプロジェクト (自分株式会社) での評価

```
採用シナリオ: 開発チーム拡大時 (5名→20名) の標準 IDE ツール
推奨プラン: Pro ($12/ユーザー/月)
理由:
- Codeium の無料代替として、有料化後の選択肢
- Flutter/Dart の補完品質は Copilot と同等以上 (Dart 特化学習)
- HIPAA/SOC2 要件がある医療/金融クライアント案件で差別化

懸念点:
- Codeium が無料で同等機能を提供中 → 有料化の動機弱い
- GitHub Copilot がすでに GitHub との統合が深い
```

## クイックスタート (3 ステップ)

1. VS Code → 拡張機能 → "Tabnine AI" → Install
2. Tabnine アイコン → Login / Create Account (無料プランで開始)
3. コードを書くと自動でサジェスト表示 → `Tab` で受け入れ
$md$,
  'https://www.tabnine.com/enterprise',
  '2026-04-25',
  3
)

ON CONFLICT DO NOTHING;
