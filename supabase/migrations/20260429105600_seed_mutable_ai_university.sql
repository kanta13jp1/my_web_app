-- PS#3 S127: AI大学 348→349社化 — Mutable AI (コードベース文書化・自動ドキュメント生成)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'mutable-ai', 'overview',
  'Mutable AI — コードベース自動文書化・Wiki生成・コード理解加速・技術的負債削減 (9/9)',
  $$## Mutable AI とは

**Mutable AI** は**コードベースの自動文書化・Wiki 生成**に特化した AI ツール。コード補完や PR レビューではなく、「**コードを読んで理解する**」作業を AI が支援する。

大規模レガシーコードベースに新規参加したエンジニアが「このコードが何をしているか」を理解するまでのオンボーディング時間を大幅に短縮。技術的負債として蓄積されたドキュメント不足を AI が補完する。

## Mutable AI のコア機能

```
Mutable AI のプロダクト:

  Auto-Wiki:
    ・コードベースを読み込んでWikiを自動生成
    ・モジュール・クラス・関数の説明を自動作成
    ・アーキテクチャ図の自動生成
    ・依存関係グラフの可視化
    ・Confluence / Notion / GitHub Wiki に出力

  Codebase Chat:
    ・「この関数は何をしていますか？」
    ・「auth モジュールのフローを説明して」
    ・「このバグはなぜ起きていますか？」
    ・自然言語でコードベースに質問

  Documentation as Code:
    ・コード変更時にドキュメントを自動更新
    ・PR に含まれる変更のドキュメント影響を分析
    ・ドキュメントの陳腐化を防ぐ
```

## Auto-Wiki の生成例

```markdown
# AuthService (lib/services/auth_service.dart)

## 概要
JWT ベースの認証を管理するサービスクラス。
ユーザーのログイン・ログアウト・トークン更新を担当。

## メソッド一覧
| メソッド | 説明 | 入力 | 出力 |
|----------|------|------|------|
| signIn() | メールアドレスでサインイン | email, password | AuthResult |
| signOut() | 現在のセッションを終了 | - | void |
| refreshToken() | JWTトークンを更新 | - | String |

## 依存関係
- SupabaseClient: データベース認証
- SecureStorage: トークン保存
- LoggingService: 認証イベントのログ

## 使用箇所
- LoginPage: サインイン処理
- SplashScreen: 自動ログイン確認
- ProfilePage: ログアウト処理
```

## 料金体系

| プラン | 月額 | 特徴 |
|--------|------|------|
| Free | $0 | 5 リポジトリまで |
| Pro | $20/人 | 無制限 + Confluence統合 |
| Enterprise | 要問い合わせ | オンプレ / SSO |

## 対象ユーザー

- **新規参加エンジニア**: オンボーディング時間 70% 削減
- **技術リード**: ドキュメント作成工数削減
- **CTO / アーキテクト**: システム全体像の可視化

## 競合との差別化

他の AI コーディングツール（Copilot / Cursor）は「コードを書く」補助。Mutable AI は「**コードを理解する**」補助に特化。競合しない、補完的な位置づけ。

## 自分株式会社との関連

自分株式会社の 12 インスタンスフリートでは「新しいインスタンスがコードベースを理解する」コストが高い。Mutable AI の Auto-Wiki を適用することで、各インスタンスの起動時コンテキスト構築が効率化される。COMPRESSED_PROMPT_V3.md の役割を部分的に代替できる。
$$,
  'https://mutable.ai',
  NOW(),
  349
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
