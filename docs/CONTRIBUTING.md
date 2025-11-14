# Contributing Guide

このプロジェクトへのコントリビューションに興味を持っていただき、ありがとうございます！

## 📋 目次

1. [開発環境セットアップ](#開発環境セットアップ)
2. [コーディング規約](#コーディング規約)
3. [コミットメッセージ規約](#コミットメッセージ規約)
4. [PR作成ガイド](#pr作成ガイド)
5. [レビュー基準](#レビュー基準)
6. [コミュニティガイドライン](#コミュニティガイドライン)

## 開発環境セットアップ

### 必要なツール

以下のツールをインストールしてください:

- **Flutter SDK** (3.24.x以上)
- **Dart SDK** (Flutter SDKに含まれる)
- **Git**
- **Firebase CLI**
- **Supabase CLI**
- **Visual Studio Code** または **Android Studio** (推奨)

### セットアップ手順

#### 1. リポジトリのクローン

```bash
git clone https://github.com/kanta13jp1/my_web_app.git
cd my_web_app
```

#### 2. 依存関係のインストール

```bash
flutter pub get
```

#### 3. 環境変数の設定

```bash
# .env.example をコピーして .env.development を作成
cp .env.example .env.development

# エディタで .env.development を開いて必要な値を設定
```

#### 4. Supabaseのセットアップ

```bash
# Supabaseにログイン
supabase login

# ローカルSupabaseを起動（オプション）
supabase start

# プロジェクトにリンク（開発環境）
supabase link --project-ref <YOUR_PROJECT_ID>

# マイグレーションを適用
supabase db push
```

#### 5. 動作確認

```bash
# Webアプリを起動
flutter run -d chrome

# または
flutter run -d web-server
```

ブラウザで http://localhost:8080 にアクセスして動作確認してください。

### VS Code拡張機能（推奨）

- **Flutter** (Dart Code)
- **Dart**
- **GitLens**
- **Error Lens**
- **Better Comments**

## コーディング規約

### Dart / Flutter コーディングスタイル

基本的に [Effective Dart](https://dart.dev/guides/language/effective-dart) に従います。

#### ファイル・ディレクトリ構造

```
lib/
├── main.dart                 # アプリのエントリーポイント
├── models/                   # データモデル
├── pages/                    # ページ（画面）
├── widgets/                  # 再利用可能なウィジェット
├── services/                 # ビジネスロジック・API連携
└── utils/                    # ユーティリティ関数
```

#### 命名規則

```dart
// クラス名: UpperCamelCase
class UserProfile {}

// ファイル名: snake_case
// user_profile.dart

// 変数・関数: lowerCamelCase
String userName = 'John';
void fetchUserData() {}

// 定数: lowerCamelCase (constまたはfinal)
const apiEndpoint = 'https://api.example.com';

// プライベート変数・関数: _ で始める
String _privateVariable = 'secret';
void _privateMethod() {}
```

#### コードフォーマット

自動フォーマットを使用してください:

```bash
# すべてのDartファイルをフォーマット
dart format .

# 特定のファイルをフォーマット
dart format lib/main.dart
```

#### Lintルール

`analysis_options.yaml` で定義されたLintルールに従ってください:

```bash
# Lint チェック
flutter analyze

# 自動修正可能な問題を修正
dart fix --apply
```

### コメント規約

#### ドキュメントコメント

パブリックAPIには必ずドキュメントコメントを付けてください:

```dart
/// ユーザープロフィールを取得します。
///
/// [userId] にはSupabaseのユーザーIDを指定します。
/// ユーザーが見つからない場合は null を返します。
///
/// Example:
/// ```dart
/// final profile = await fetchUserProfile('user-123');
/// ```
Future<UserProfile?> fetchUserProfile(String userId) async {
  // 実装
}
```

#### インラインコメント

複雑なロジックには説明コメントを付けてください:

```dart
// ユーザーの最終ログイン日時から30日以上経過している場合は非アクティブと判定
if (daysSinceLastLogin > 30) {
  markUserAsInactive(userId);
}
```

### エラーハンドリング

適切なエラーハンドリングを実装してください:

```dart
try {
  final data = await supabase.from('users').select();
  return data;
} on PostgrestException catch (e) {
  AppLogger.error('Database error', error: e);
  rethrow;
} catch (e) {
  AppLogger.error('Unexpected error', error: e);
  rethrow;
}
```

## コミットメッセージ規約

### Conventional Commits

[Conventional Commits](https://www.conventionalcommits.org/) に従います。

#### フォーマット

```
<type>(<scope>): <subject>

<body>

<footer>
```

#### Type一覧

| Type | 説明 | 例 |
|------|------|-----|
| `feat` | 新機能 | `feat: Add user authentication` |
| `fix` | バグ修正 | `fix: Resolve login error` |
| `docs` | ドキュメント変更 | `docs: Update README` |
| `style` | フォーマット変更 | `style: Fix indentation` |
| `refactor` | リファクタリング | `refactor: Simplify user service` |
| `perf` | パフォーマンス改善 | `perf: Optimize image loading` |
| `test` | テスト追加・修正 | `test: Add user service tests` |
| `build` | ビルド関連 | `build: Update dependencies` |
| `ci` | CI/CD関連 | `ci: Add deploy workflow` |
| `chore` | その他 | `chore: Update .gitignore` |

#### 良い例

```
feat(auth): Add Google sign-in functionality

Implement Google OAuth authentication using Supabase Auth.
Users can now sign in with their Google account.

Closes #123
```

```
fix(notes): Prevent duplicate note creation

Fix race condition that caused duplicate notes when
clicking save button multiple times.

Fixes #456
```

#### 悪い例

```
updated files
```

```
fixed bug
```

### コミット単位

- **1つのコミットは1つの論理的な変更**にする
- **動作するコードのみをコミット**する
- **大きな変更は複数のコミットに分割**する

## PR作成ガイド

### PRを作成する前に

- [ ] ローカルでCIチェックを実行
  ```bash
  flutter analyze
  dart format --set-exit-if-changed .
  flutter test
  flutter build web --release
  ```
- [ ] 関連するIssueが存在する
- [ ] ブランチ名が規約に従っている (`feature/`, `bugfix/`, `hotfix/`)

### PRテンプレートの記入

`.github/PULL_REQUEST_TEMPLATE.md` のテンプレートに従って、以下の情報を記入してください:

1. **変更内容**: 何を変更したか簡潔に説明
2. **関連Issue**: `Closes #123` または `Related to #456`
3. **変更の目的**: なぜこの変更が必要か
4. **テスト結果**: どのようにテストしたか
5. **スクリーンショット**: UI変更がある場合は必須

### PR作成手順

```bash
# 1. featureブランチを作成
git checkout -b feature/your-feature

# 2. 変更を実装

# 3. コミット
git add .
git commit -m "feat: Add your feature"

# 4. プッシュ
git push -u origin feature/your-feature

# 5. GitHub上でPRを作成
# https://github.com/kanta13jp1/my_web_app/compare/develop...feature/your-feature
```

### PR作成時のベストプラクティス

1. **小さなPRを作成する**: レビューしやすいサイズに保つ
2. **セルフレビューする**: PR作成後、自分でコードを確認
3. **レビューコメントに迅速に対応する**
4. **レビュワーに感謝する**

## レビュー基準

### レビュアーとしての心構え

- **建設的なフィードバックを提供**する
- **コードの意図を理解**してからコメントする
- **代替案を提案**する
- **賞賛も忘れずに**（良いコードには "LGTM!" だけでなく理由も）

### レビュー観点

#### 1. 機能性

- [ ] 要件を満たしているか
- [ ] エッジケースが考慮されているか
- [ ] エラーハンドリングが適切か

#### 2. コード品質

- [ ] コーディング規約に従っているか
- [ ] 可読性が高いか
- [ ] 重複コードがないか
- [ ] 適切な抽象化がされているか

#### 3. パフォーマンス

- [ ] 不要な再レンダリングがないか
- [ ] メモリリークがないか
- [ ] 非同期処理が適切か

#### 4. セキュリティ

- [ ] 機密情報が漏洩していないか
- [ ] 入力値の検証が適切か
- [ ] XSS、SQLインジェクションなどの脆弱性がないか

#### 5. テスト

- [ ] 十分なテストカバレッジがあるか
- [ ] エッジケースのテストがあるか
- [ ] テストが壊れていないか

#### 6. ドキュメント

- [ ] 必要なコメントが追加されているか
- [ ] READMEやドキュメントの更新が必要か

### レビューコメントの例

#### 良いコメント

```
この実装は良いですが、パフォーマンスを考慮すると `useMemo` を使った方が
良いかもしれません。以下のように修正してはどうでしょうか：

```dart
// 修正案のコード
```

#### 改善が必要なコメント

```
これはダメです。
```

### ApproveとRequest Changesの基準

#### Approve

- すべての重要な問題が解決済み
- 軽微な問題のみ残っている（typoなど）
- コードの品質が高い

#### Request Changes

- 重大なバグがある
- セキュリティ上の問題がある
- 大幅な改善が必要

#### Comment

- 質問がある
- 提案がある（必須ではない）
- 情報共有

## コミュニティガイドライン

### 行動規範

- **敬意を持って接する**: 全ての参加者に敬意を払う
- **建設的である**: 批判的ではなく、建設的なフィードバックを提供
- **協力的である**: チームワークを重視する
- **オープンである**: 異なる意見や視点を歓迎する

### 質問の仕方

質問する前に:
1. ドキュメントを確認
2. 既存のIssueを検索
3. コードを読む

質問する際は:
- **具体的に**: 何が問題か明確に説明
- **再現可能に**: 再現手順を記載
- **環境情報を含める**: OS、ブラウザ、バージョンなど

### Issue報告

良いIssue報告の例:

```markdown
## 🐛 バグの概要
ログイン画面でメールアドレスを入力すると、エラーメッセージが表示されます。

## 📝 再現手順
1. ログイン画面にアクセス
2. メールアドレス欄に "test@example.com" を入力
3. パスワード欄に "password123" を入力
4. "ログイン" ボタンをクリック

## 🔍 期待される動作
ログインに成功し、ホーム画面に遷移する

## 🚨 実際の動作
"認証エラー" というメッセージが表示される

## 🌐 環境情報
- ブラウザ: Chrome 120.0.6099.109
- OS: macOS 14.2
- アカウント: test@example.com

## 📸 スクリーンショット
[スクリーンショットを添付]

## 📋 追加情報
コンソールに以下のエラーが表示されています:
```
Error: Invalid credentials
```
```

## 参考資料

- [Flutter公式ドキュメント](https://flutter.dev/docs)
- [Effective Dart](https://dart.dev/guides/language/effective-dart)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Supabase ドキュメント](https://supabase.com/docs)
- [Firebase ドキュメント](https://firebase.google.com/docs)

## 関連ドキュメント

- [CI_CD_GUIDE.md](./technical/CI_CD_GUIDE.md) - CI/CD パイプライン
- [DEPLOYMENT_GUIDE.md](./technical/DEPLOYMENT_GUIDE.md) - デプロイ手順
- [GROWTH_STRATEGY_ROADMAP.md](./GROWTH_STRATEGY_ROADMAP.md) - プロジェクト戦略

## ライセンス

このプロジェクトのライセンスについては、[LICENSE](../LICENSE) ファイルを参照してください。

---

貢献してくださる皆様に感謝します！ 🙏
