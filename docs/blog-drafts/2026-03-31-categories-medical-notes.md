---
title: FlutterとSupabaseでカテゴリ管理・医療メモ機能を実装した話
emoji: 🗂️
type: tech
topics: [Flutter, Supabase, Flutter Web, PostgreSQL]
published: false
---

# FlutterとSupabaseでカテゴリ管理・医療メモ機能を実装した話

## はじめに

自分株式会社（https://my-web-app-b67f4.web.app/）はNotion・Evernote・MoneyForward・Slack など21競合を1つに統合するAI統合ライフマネジメントアプリです。

本日は「カテゴリ管理」と「医療メモ」の2機能を追加実装しました。どちらも実データをSupabaseから取得し、ダミーデータなしで動作します。

## カテゴリ管理機能

### 概要

メモ・タスクを整理するためのカテゴリを管理する機能です。ユーザーは自分だけのカテゴリを作成・削除できます。

### Supabaseテーブル設計

```sql
CREATE TABLE categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  color text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
```

RLSポリシーを設定し、ユーザーは自分のカテゴリのみ操作可能にしています。

### Flutterの実装

```dart
Future<void> _fetchCategories() async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return;

  final response = await supabase
      .from('categories')
      .select()
      .eq('user_id', userId)
      .order('created_at', ascending: true);

  setState(() {
    _categories = List<Map<String, dynamic>>.from(response);
    _isLoading = false;
  });
}
```

### ポイント

- `ON DELETE CASCADE`でユーザー削除時にカテゴリも自動削除
- RLSで他ユーザーのカテゴリにはアクセス不可
- `gen_random_uuid()`でIDを自動生成

## 医療メモ機能

### 概要

服薬・通院・健康診断などの医療記録を管理する機能です。既存の`notes`テーブルを活用し、タイトルに`[Medical]`プレフィックスを付けることで医療メモを識別します。

### 実装上の工夫

新テーブルを作らず既存の`notes`テーブルを流用することで、バックエンドへの変更を最小限に抑えました。

```dart
final data = await _supabase
    .from('notes')
    .select()
    .eq('user_id', userId)
    .ilike('title', '[Medical]%')
    .order('created_at', ascending: false)
    .limit(50);
```

カテゴリは`['通院記録', '処方薬', '健康診断', '手術・処置', 'その他']`の5種類に対応。

## 業務メニューへの統合

両機能は`home_tool_catalog.dart`の業務メニューカタログに追加し、キーワード検索でも発見できるようにしました。

```dart
HomeToolEntry(
  id: 'categories',
  sectionId: 'knowledge',
  title: 'カテゴリ管理',
  subtitle: 'メモ・タスクのカテゴリを整理・編集する',
  icon: Icons.category_outlined,
  color: Colors.blueGrey,
  keywords: const ['カテゴリ', 'タグ', '分類', '整理'],
  onOpen: (context) => _pushPage(context, const CategoriesPage()),
),
```

## flutter analyze 0件維持

今回の実装でも`flutter analyze`の0件を維持しています。

## まとめ

- カテゴリ管理: SupabaseにRLS付きのテーブルを作成し、ユーザー別にカテゴリを管理
- 医療メモ: 既存テーブルの流用でバックエンド変更を最小化
- 業務メニューへの統合でユーザーが検索・発見しやすく

今後はカテゴリをノートやタスクと紐づける機能を実装予定です。

---

URL: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic
