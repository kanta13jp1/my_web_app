# Supabase URL設定の修正

**作成日**: 2025年11月9日
**問題**: 確認メールのリンクがlocalhostを指している
**優先度**: 🔴 高

---

## 🔴 問題

サインアップは成功するが、確認メールのリンクが以下のようになっている：

```
http://localhost:3000/?error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired
```

**原因**: SupabaseプロジェクトのサイトURLがlocalhostに設定されている

---

## ✅ 解決方法

### ステップ1: Supabaseダッシュボードにアクセス

1. [Supabase Dashboard](https://supabase.com/dashboard) にアクセス
2. プロジェクト **smmkxxavexumewbfaqpy** を選択
3. 左サイドバーから **Settings** → **Authentication** をクリック

### ステップ2: サイトURLを修正

**Authentication Settings**ページで以下を確認・修正：

#### Site URL（最重要）
```
現在: http://localhost:3000
修正: https://my-web-app-b67f4.web.app
```

#### Redirect URLs
以下を**すべて**追加：

```
https://my-web-app-b67f4.web.app
https://my-web-app-b67f4.web.app/**
https://my-web-app-b67f4.firebaseapp.com
https://my-web-app-b67f4.firebaseapp.com/**
http://localhost:3000
http://localhost:3000/**
```

※ `**` はワイルドカードで、すべてのパスを許可します

### ステップ3: 保存

1. **Save** ボタンをクリック
2. 変更が反映されるまで数秒待つ

---

## 🧪 テスト

### 1. 新規サインアップをテスト

1. 既存のメールアドレスとは**別の**メールアドレスでサインアップ
2. 確認メールを確認
3. リンクが `https://my-web-app-b67f4.web.app/...` になっていることを確認
4. リンクをクリックしてメール確認が成功することを確認

### 2. パスワードリセットをテスト

1. ログインページで「パスワードを忘れた」をクリック
2. メールアドレスを入力
3. 確認メールのリンクが正しいURLになっていることを確認

---

## 📋 設定値まとめ

| 設定項目 | 値 |
|:--------|:---|
| **Site URL** | `https://my-web-app-b67f4.web.app` |
| **Redirect URLs** | `https://my-web-app-b67f4.web.app/**`<br>`https://my-web-app-b67f4.firebaseapp.com/**`<br>`http://localhost:3000/**` |

---

## 🔧 オプション: 環境変数での管理（将来的に）

将来的には、複数の環境（開発・本番）で異なるURLを使い分けられるように、環境変数で管理することを推奨：

```dart
// lib/config/supabase_config.dart
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://smmkxxavexumewbfaqpy.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-anon-key',
  );

  static const String redirectUrl = String.fromEnvironment(
    'REDIRECT_URL',
    defaultValue: 'https://my-web-app-b67f4.web.app',
  );
}
```

---

## 🎯 期待される結果

✅ サインアップ成功
✅ 確認メールが送信される
✅ 確認メールのリンクが `https://my-web-app-b67f4.web.app/...` を指している
✅ リンクをクリックして確認が成功する
✅ ログインが可能になる

---

## 📝 トラブルシューティング

### 問題: リンクが依然としてlocalhostを指している

**対処法**:
1. ブラウザのキャッシュをクリア
2. Supabase設定が正しく保存されているか再確認
3. 数分待ってから再度サインアップを試す

### 問題: 「Invalid link」エラーが出る

**対処法**:
1. リンクの有効期限（通常24時間）が切れていないか確認
2. 新しいメールアドレスでサインアップし直す
3. リンクを1回だけクリックする（複数回クリックすると無効になる）

### 問題: メールが届かない

**対処法**:
1. スパムフォルダを確認
2. Supabase Dashboard → Authentication → Email Templates で設定を確認
3. 別のメールアドレスで試す

---

## 🔗 関連ドキュメント

- [Supabase Authentication Settings](https://supabase.com/docs/guides/auth/auth-helpers/auth-ui)
- [Supabase Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls)

---

**最終更新**: 2025年11月9日
**作成者**: Claude Code
