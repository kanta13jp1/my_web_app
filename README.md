# マイメモ 🎮

メモが楽しいゲームに変わる！ゲーミフィケーション機能を備えたメモアプリケーション

## ✨ 特徴

- **📝 シンプルなメモ管理**: 直感的なUIで簡単にメモを作成・編集
- **🎮 ゲーミフィケーション**: レベルシステム、実績、ポイントでモチベーション向上
- **🔥 連続記録**: 毎日の使用でストリークを継続
- **📊 統計ダッシュボード**: 自分の成長を視覚化
- **🌐 PWA対応**: ブラウザからアプリとして利用可能
- **🔐 セキュア**: Supabaseによる認証とデータ管理

## 🚀 技術スタック

- **フロントエンド**: Flutter Web
- **バックエンド**: Supabase (PostgreSQL + Edge Functions)
- **ホスティング**: Firebase Hosting
- **認証**: Supabase Auth
- **状態管理**: Provider

## 📚 ドキュメント

- [ゲーミフィケーション機能](docs/GAMIFICATION_README.md) - レベル、実績、ポイントシステムの詳細
- [サイト改善レポート](docs/IMPROVEMENTS.md) - 最近の改善内容とパフォーマンス最適化
- [Supabase Edge Functions デプロイ手順](docs/SUPABASE_EDGE_FUNCTIONS_DEPLOY.md) - 動的OGP画像生成の設定方法

## 🎯 主な機能

### メモ管理
- メモの作成、編集、削除
- カテゴリによる整理
- お気に入り機能
- リマインダー設定
- 添付ファイル対応

### ゲーミフィケーション
- **28種類の実績**: 様々な目標を達成して実績を解除
- **レベルシステム**: ポイントを貯めてレベルアップ
- **連続記録**: 毎日メモを作成してストリークを維持
- **統計表示**: 自分の成長を可視化

### SNS共有
- Twitter、Facebook、LINEへの共有
- 動的OGP画像生成
- 哲学者の名言付きシェア

## 🛠️ セットアップ

### 1. 依存関係のインストール

```bash
flutter pub get
```

### 2. Supabaseの設定

プロジェクトで使用するSupabaseプロジェクトを作成し、以下のマイグレーションを実行してください。

詳細は [ゲーミフィケーション機能ドキュメント](docs/GAMIFICATION_README.md) を参照。

### 3. ビルド

```bash
flutter build web
```

### 4. デプロイ

```bash
firebase deploy --only hosting
```

## 📖 開発ガイド

### プロジェクト構成

```
lib/
├── models/          # データモデル
├── services/        # ビジネスロジック
├── pages/           # 画面
├── widgets/         # 再利用可能なウィジェット
└── main.dart        # エントリーポイント
```

### 主要サービス

- `GamificationService`: ゲーミフィケーション機能の管理
- `NoteCardService`: メモの共有と管理
- `AppLogger`: ログ管理

## 🤝 コントリビューション

プルリクエストを歓迎します！大きな変更の場合は、まずissueを開いて変更内容を議論してください。

## 📄 ライセンス

このプロジェクトはMITライセンスの下で公開されています。

## 🔗 リンク

- [Flutter Documentation](https://docs.flutter.dev/)
- [Supabase Documentation](https://supabase.com/docs)
- [Firebase Hosting](https://firebase.google.com/docs/hosting)
