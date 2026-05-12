---
title: "Flutter Web × Supabase Edge Function で候補者Xハンドル・バイラル動画を選挙カードに統合した話"
tags: Flutter,Supabase,個人開発,buildinpublic,選挙
published: true
---

# ブログ下書き 2026-04-02 — 2026-04-02-election-x-handles-viral-video

## タイトル案

1. Flutter Web × Supabase Edge Function で候補者Xハンドルを選挙スケジュールカードに統合した話
2. 選挙スケジュールにXハンドル対応 + バイラル動画生成パイプラインを実装した実装記録
3. deno lint 0件維持しながら228 Edge Functions体制に拡張 — 選挙×SNSインフラ強化

## 投稿先候補
- [x] Zenn
- [ ] Qiita
- [x] note
- [ ] Medium
- [ ] dev.to
- [ ] Hashnode
- [x] X Article

## 本文下書き (1500〜3000字)

### はじめに

自分株式会社は「Notion・Evernote・MoneyForward・X など21競合を1つに統合する」をコンセプトに
Flutter Web + Supabase Edge Function で日々機能を拡張しています。

今回は 2026-04-02 の daily-development セッションで実施した3つの実装を解説します:

1. **選挙スケジュールカードにXハンドルを統合** (Flutter + Edge Function)
2. **deno lint 0件維持** (12→0エラー修正)
3. **バイラル動画生成パイプライン追加** (新規 Edge Function + 共有ユーティリティ)

---

### 1. 候補者Xハンドルを選挙スケジュールカードに統合

#### 背景

統一地方選の候補者700人必達目標管理室 (`ElectionVictoryPage`) では、
AI が取得した選挙スケジュールを表示しています。これまでは候補者名と状況ラベルを
テキストで表示するだけでしたが、候補者への直接アクセスを可能にするため
Xハンドルを追加しました。

#### Dart モデル変更

```dart
// lib/models/local_election_reality.dart
class LocalElectionScheduleEntry {
  // ... 既存フィールド
  final List<String> kokuminCandidateXHandles; // ← 追加

  factory LocalElectionScheduleEntry.fromJson(Map<String, dynamic> json) {
    return LocalElectionScheduleEntry(
      // ...
      kokuminCandidateXHandles:
          _readStringList(json['kokuminCandidateXHandles']),
    );
  }
}
```

#### Flutter UI 変更

選挙スケジュールカードに `ActionChip` でXハンドルを表示し、タップで `https://x.com/{handle}` を開きます:

```dart
if (candidateHandles.isNotEmpty) ...[
  const SizedBox(height: 12),
  Wrap(
    spacing: 8,
    runSpacing: 8,
    children: candidateHandles.map((handle) {
      return ActionChip(
        avatar: const Icon(Icons.alternate_email, size: 16),
        label: Text('@$handle'),
        onPressed: () => _openUrl('https://x.com/$handle'),
      );
    }).toList(),
  ),
],
```

#### CSV エクスポートの強化

未擁立・単騎の選挙スケジュールをCSVコピーする際に候補者名とXハンドルを追加:

```dart
buffer.writeln('投票日,都道府県,自治体,選挙名,候補者数,候補者一覧,Xハンドル');
// ...
final handles = _candidateHandles(s)
    .map((handle) => '@$handle')
    .join(' / ');
buffer.writeln('$date,$pref,$muni,$name,$count,$candidates,$handles');
```

#### Edge Function の `xHandle` フィールド追加

`local-election-intelligence` Edge Function に `ManualScheduleSupplement` 型を追加し、
手動で補完するデータにXハンドルを含められるようにしました:

```typescript
interface OfficialScheduledCandidate {
  name: string;
  statusLabel: string;
  detailUrl: string;
  sourceUrl: string;
  xHandle: string; // ← 追加
}
```

---

### 2. deno lint 0件維持 — 12エラーを一括修正

Supabase Edge Function 群 (240ファイル) のdeno lintが12件エラーになっていました。
主なエラーパターンとその修正方法を紹介します。

#### パターン1: no-unused-vars

```typescript
// Before
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
// → 使われていないので削除

// Before
const { data: overrides, error: overrideErr } = await adminClient...
// After
const { data: overrides, error: _overrideErr } = await adminClient...
// → アンダースコアプレフィックスで意図的な未使用を表明
```

#### パターン2: prefer-const

```typescript
// Before
let sorted = reviews.map(...);
// After
const sorted = reviews.map(...);
// → 再代入しない変数はconst
```

#### パターン3: no-explicit-any

```typescript
// Before
type AdminClient = any;
// After
// deno-lint-ignore no-explicit-any
type AdminClient = any;
// → 型推論が困難な場合はコメントで抑制
```

---

### 3. バイラル動画生成パイプライン実装

#### 共有ユーティリティ (_shared/)

複数のEdge Functionで共通利用するユーティリティを `_shared/` に整理しました:

- `edge.ts`: CORS ヘッダー・JSON レスポンス・型変換ヘルパー
- `viral-growth.ts`: バイラルブリーフ生成・動画レンダリングキュー
- `x-client.ts`: X (Twitter) OAuth 1.0a 署名・メディアアップロード

#### viral-video-generator Edge Function

短尺動画広告ブリーフを生成し、外部動画レンダラーへのキューイングをサポートする
新規 Edge Function です:

```typescript
// ブリーフ生成 (POST /viral-video-generator)
const brief = await generateViralBrief(input, admin);
const renderResult = await queueViralVideoRender(brief, admin);
return jsonResponse({ success: true, brief, render: renderResult });
```

#### config.toml と deploy-prod.yml への追加

Supabase の 100 Function デプロイ制限対策として、
`viral-video-generator` は Tier 2 (コードのみ) として管理:

```toml
[functions.viral-video-generator]
enabled = true
verify_jwt = true
entrypoint = "./functions/viral-video-generator/index.ts"
```

---

### 選挙管理ダッシュボード (/election-dashboard) を新設

`ElectionManagementDashboard` ページを routing に追加し、
業務メニューカタログ (`home_tool_catalog.dart`) からアクセス可能にしました。

- AIデータ取得・KPIタブ・時系列グラフの3タブ構成
- `fetch-local-politicians` Edge Function と連携 (追加予定)
- fl_chart を使った時系列チャート

---

### まとめ

今回の実装で:
- 候補者Xハンドルをカードに表示し、選挙管理のリーチアウト効率を向上
- deno lint 0件を維持し、240ファイルの Edge Function 群のコード品質を担保
- バイラル動画生成パイプラインの基盤を整備
- 選挙管理ダッシュボードを routing に統合

引き続き flutter analyze 0件 / deno lint 0件 を維持しながら、
21競合を超えるプラットフォームを目指して開発を継続します。

---
URL: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #選挙 #deno
