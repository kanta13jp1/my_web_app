-- Session PS#3-S48: AI大学 192→193社化 — Codeium 追加
-- 無料 AI コード補完ツール。VS Code/JetBrains/Vim を含む 70+ エディタに対応。
-- Windsurf IDE (AI ネイティブエディタ) も同社 Exafunction 製。70k+ 開発者が利用。
-- $150M Series C 調達。企業向け Codeium Enterprise もあり。
-- Step 0: 8/9 (GitHub Copilot 無料代替 / 70+エディタ / Windsurf同社 / $150M / 70k+ユーザー)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'codeium',
  'overview',
  'Codeium — 無料 AI コード補完・70+ エディタ対応・Windsurf IDE 同社製',
  $md$
# Codeium — AI-Powered Code Completion (Free)

**GitHub Copilot の無料代替**として人気の AI コード補完ツール。

VS Code・JetBrains・Vim・Emacs など **70+ エディタ**に対応し、
個人利用は永続無料。Exafunction 社が開発し、同社は **Windsurf IDE** も提供する。

**70,000+ 開発者**が利用。$150M Series C 調達済み。

## GitHub Copilot との比較

| 機能 | Codeium | GitHub Copilot |
| :--- | :--- | :--- |
| **個人利用** | **永続無料** | 月 $10 (無料枠あり) |
| **対応エディタ** | **70+** | VS Code・JetBrains 中心 |
| **速度** | 高速 (独自推論基盤) | 標準 |
| **プライバシー** | コードを学習に使用しない | 設定可能 |
| **Chat 機能** | ✅ (無料) | ✅ (有料) |
| **コマンドライン** | ✅ | 限定的 |

## 主要機能

### Autocomplete (コード補完)
- 文脈に応じたマルチライン補完
- 70+ プログラミング言語対応
- 現在開いているファイルを文脈として使用

### Chat (会話型 AI)
- コードについて質問・説明を要求
- バグ修正・テスト生成・ドキュメント生成
- コードブロックを選択して質問

### Command (コマンド補完)
- ターミナルでの Shell コマンド補完
- 自然言語でコマンドを生成

### Search (コード検索)
- 自然言語でコードベースを検索
- 関数・クラスの意味的な検索

## エディタ対応一覧 (主要)

| カテゴリ | エディタ |
| :--- | :--- |
| **VSCode 系** | VS Code, Cursor, Windsurf, VSCodium |
| **JetBrains 系** | IntelliJ, PyCharm, WebStorm, GoLand, Rider, CLion |
| **Vim 系** | Vim, Neovim |
| **その他** | Emacs, Eclipse, Sublime Text, Jupyter Lab |

## Codeium Enterprise

企業向け機能:
- **オンプレミスデプロイ**: 社内サーバーで完全自己完結
- **プライベートコンテキスト**: 社内コードベースで Fine-tuning
- **SSO/SAML**: Okta・Azure AD 連携
- **使用状況ダッシュボード**: チーム全体の利用状況可視化
- **コードポリシー**: 特定パターンを補完候補から除外

## Windsurf IDE との関係

同社 Exafunction が開発した AI ネイティブエディタ。
Codeium の補完機能に加え、**Cascade** (AI エージェント) が搭載され、
ファイルをまたいだ大規模なコード変更を自律実行できる。
$md$,
  'https://codeium.com/',
  '2026-04-25',
  1
),

(
  'codeium',
  'api',
  'Codeium セットアップ — VS Code・JetBrains・Windsurf インストール・Enterprise 設定',
  $md$
## VS Code へのインストール

```bash
# 方法 1: VS Code 拡張機能マーケットプレイス
# 検索: "Codeium" → Install

# 方法 2: コマンドラインから
code --install-extension Codeium.codeium

# アカウント作成 & ログイン
# VS Code を開く → Codeium アイコン → Sign In → ブラウザでアカウント作成
```

---

## 基本的な使い方 (VS Code)

```dart
// Dart でのコード補完例
// クラス名を書き始めると自動的に補完候補が表示される

class UserProfile {
  final String name;
  final String email;
  // Tab キーで補完を受け入れる
  // ↓ Codeium が以下を自動提案
  final DateTime createdAt;

  const UserProfile({
    required this.name,
    required this.email,
    required this.createdAt,
  });

  // "fromJson" と入力するだけで fromJson メソッドを生成
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String,
      email: json['email'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
```

---

## Chat 機能の使い方

```
# VS Code で Ctrl+Shift+P → "Codeium: Open Chat"
# または左サイドバーの Codeium アイコン → Chat

質問例:
- "このコードのバグを探して修正してください"
- "このクラスにユニットテストを追加して"
- "このAPIの使い方を日本語で説明して"
- "このコードをリファクタリングして"

# コードを選択してから Ctrl+I でインラインチャット
// ← ここを選択 →
void fetchUserData() {
  // 補完候補が不適切な場合は Codeium に直接指示
}
```

---

## JetBrains (IntelliJ / PyCharm / WebStorm) へのインストール

```
1. File → Settings → Plugins → Marketplace
2. "Codeium" を検索 → Install
3. IDE を再起動
4. ステータスバーの Codeium アイコン → Login
```

---

## Windsurf IDE (エージェントモード)

```
# Windsurf をダウンロード: https://codeium.com/windsurf
# VS Code の設定・拡張機能をほぼそのまま引き継げる

# Cascade エージェントの使い方:
Ctrl+L → Cascade パネルを開く

# 大規模タスクの例:
"lib/pages/ 配下の全ページでエラーハンドリングが抜けているものを
 修正して、共通の ErrorBoundary コンポーネントを追加してください"

# Cascade は複数ファイルを自律的に編集する
# → diff プレビューで確認 → Accept / Reject
```

---

## Enterprise セットアップ (オンプレミス)

```yaml
# docker-compose.yml (Codeium Enterprise)
version: '3'
services:
  codeium-server:
    image: ghcr.io/exafunction/codeium-enterprise:latest
    environment:
      - CODEIUM_API_KEY=${CODEIUM_ENTERPRISE_KEY}
      - CODEIUM_BASE_URL=https://your-domain.com
      - DATABASE_URL=postgresql://...
    ports:
      - "443:443"
    volumes:
      - ./certs:/certs
      - codeium-data:/data

# エディタ側の設定 (settings.json)
{
  "codeium.enterpriseMode": true,
  "codeium.enterpriseUrl": "https://your-domain.com"
}
```

---

## プライバシー設定

```json
// VS Code settings.json
{
  // テレメトリを無効化 (コードを Codeium に送信しない)
  "codeium.enableTelemetry": false,

  // 特定のファイルパターンで補完を無効化
  "codeium.excludeLanguageIds": ["plaintext"],

  // プロジェクト全体でのコンテキスト使用を制限
  "codeium.enableCodeLens": false
}
```
$md$,
  'https://codeium.com/documentation',
  '2026-04-25',
  2
),

(
  'codeium',
  'models',
  'Codeium 活用術 — Flutter/Dart 開発・生産性向上・Copilot からの移行',
  $md$
## Flutter/Dart 開発での活用 (このプロジェクト向け)

```dart
// Widget 生成: クラス名と extends を書くと補完
class AiProviderCard extends StatelessWidget {
  // Codeium が constructor・build メソッドを自動補完

  const AiProviderCard({
    super.key,
    required this.provider,
    this.onTap,
  });

  final AiProviderEntry provider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // "return Card(" と入力するだけで Card ウィジェットの骨格を補完
    return Card(
      elevation: 2,
      child: ListTile(
        title: Text(provider.displayName),
        subtitle: Text(provider.note),
        onTap: onTap,
        trailing: _StatusBadge(status: provider.status),
      ),
    );
  }
}
```

---

## Supabase クエリの補完

```dart
// "await supabase.from(" と入力すると Codeium がテーブル名・カラムを提案
final response = await supabase
    .from('ai_university_content')
    .select('provider, category, title, content')
    .eq('provider', providerId)
    .order('sort_order');

// RLS 対応クエリも自動補完
final userData = await supabase
    .from('profiles')
    .select()
    .eq('id', supabase.auth.currentUser!.id)
    .single();
```

---

## Edge Function (Deno) 開発での活用

```typescript
// Deno + Supabase EF での補完
// "serve(async (req" と入力すると EF のボイラープレートを補完
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request) => {
  // "const supabase = create" → createClient の補完
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  // レスポンスパターンも自動補完
  return new Response(
    JSON.stringify({ success: true }),
    { headers: { "Content-Type": "application/json" } }
  );
});
```

---

## GitHub Copilot からの移行チェックリスト

| 項目 | 手順 |
| :--- | :--- |
| 1. Copilot を無効化 | VS Code 拡張機能 → GitHub Copilot → Disable |
| 2. Codeium をインストール | Marketplace → "Codeium" → Install |
| 3. アカウント作成 | codeium.com → Sign Up (GitHub ログイン可) |
| 4. ログイン | VS Code → Codeium アイコン → Sign In |
| 5. 動作確認 | `// test` と入力して補完が出るか確認 |

**移行後の違い**:
- `Tab` で補完を受け入れる点は同じ
- Chat は `Ctrl+Shift+P → Codeium: Open Chat`
- デフォルトショートカットが若干異なる場合あり

## クイックスタート (3 ステップ)

1. VS Code Marketplace で "Codeium" を検索してインストール
2. サイドバーの Codeium アイコンからアカウント作成・ログイン (無料)
3. コードを書き始めると自動的に補完候補が表示される → `Tab` で受け入れ
$md$,
  'https://codeium.com/compare/comparison-copilot-codeium',
  '2026-04-25',
  3
)

ON CONFLICT DO NOTHING;
