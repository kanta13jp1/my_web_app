# 自分株式会社 — DESIGN.md
# デザインシステム定義 (AI エージェント参照用)

> このファイルは [Awesome Design MD JP](https://github.com/kzhrknt/awesome-design-md-jp) フォーマットに準拠しています。
> Flutter/Dart コードを生成する際は、このファイルのデザイントークンを参照してください。
> 更新日: 2026-04-06

---

## ブランドアイデンティティ

**コンセプト**: 「プロフェッショナルなダーク × 生命力のあるオレンジ」

自分株式会社は「ギタリスト・クリエイター・経営者の全機能をひとつに」する AI 統合プラットフォーム。
ダークテーマで集中力を高め、オレンジアクセントでエネルギーと行動を喚起する。

---

## カラーパレット

### ベースカラー (ダークテーマ)

```dart
// 背景レイヤー
static const Color background = Color(0xFF0A0A0A);          // メイン背景 (最暗)
static const Color surface1    = Color(0xFF1A1A1A);          // カード背景・AppBar
static const Color surface2    = Color(0xFF1E1E1E);          // カードコンテンツ背景
static const Color surface3    = Color(0xFF2A2A2A);          // チップ・インプット背景
static const Color surface4    = Color(0xFF333333);          // ホバー・セレクト状態
static const Color divider     = Color(0xFF2A2A2A);          // 区切り線
```

### アクセントカラー

```dart
// オレンジ — メインアクション・CTA・ギタースタジオ
static const Color orange      = Color(0xFFFF6B35);
static const Color orangeLight = Color(0xFFFF8C5A);
static const Color orangeDark  = Color(0xFFCC4A1A);
static const Color orangeGlow  = Color(0x33FF6B35);          // alpha 0.2 — グロー効果用

// インディゴ — AI 機能・プレミアム機能
static const Color indigo      = Color(0xFF3D5AFE);
static const Color indigoLight = Color(0xFF7986CB);
static const Color indigoGlow  = Color(0x333D5AFE);

// グリーン — 成功・完了・ポジティブKPI
static const Color green       = Color(0xFF4CAF50);
static const Color greenLight  = Color(0xFF81C784);
static const Color greenGlow   = Color(0x334CAF50);

// レッド — エラー・アラート・削除
static const Color red         = Color(0xFFE53935);
static const Color redLight    = Color(0xFFEF9A9A);

// アンバー — 警告・進行中
static const Color amber       = Color(0xFFFFC107);

// ゴールド — ランキング1位・トップ表示
static const Color gold        = Color(0xFFFFD700);
```

### テキストカラー

```dart
static const Color textPrimary   = Colors.white;             // メインテキスト
static const Color textSecondary = Color(0xFFB0B0B0);        // サブテキスト
static const Color textTertiary  = Color(0xFF707070);        // プレースホルダー・ヒント
static const Color textDisabled  = Color(0xFF404040);        // 無効状態
```

### グラジエント

```dart
// ヘッダー・LP ヒーローセクション
static const LinearGradient heroGradient = LinearGradient(
  colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// オレンジ CTA ボタン
static const LinearGradient orangeGradient = LinearGradient(
  colors: [Color(0xFFFF6B35), Color(0xFFFF8C5A)],
);

// AI 機能バナー
static const LinearGradient aiGradient = LinearGradient(
  colors: [Color(0xFF1A0A2E), Color(0xFF0A1A3E)],
);
```

---

## タイポグラフィ

> 日本語タイポグラフィ仕様は [awesome-design-md-jp](https://github.com/kzhrknt/awesome-design-md-jp) テンプレートに従っています。

### 1. 和文フォント (Japanese Font Stack)

**ゴシック体** (アプリ全体のデフォルト):
- Noto Sans JP (Google Fonts — Flutter Web メインフォント)
- ヒラギノ角ゴ ProN (macOS フォールバック)
- メイリオ (Windows フォールバック)

**等幅** (コードブロック・数値表示):
- SFMono-Regular, Consolas, Menlo, monospace

**明朝体**: 使用しない (ダークテーマで可読性が低いため)

### 2. font-family 指定 (Flutter Web — `web/index.html`)

```css
/* 本文・UI テキスト */
font-family: "Noto Sans JP", "Hiragino Kaku Gothic ProN",
  "Hiragino Sans", Meiryo, Arial, sans-serif;

/* 等幅 (コード表示) */
font-family: SFMono-Regular, Consolas, Menlo, Courier, monospace;
```

**フォールバックの考え方**:
- Noto Sans JP を先頭 (Flutter Web でロード済み)
- macOS → Windows の順でシステムフォントを列挙
- 欧文は Noto Sans JP 内の欧文グリフを利用 (Inter は別指定不要)

### 3. 行間・字間 (Japanese-optimized)

| Role | Font Size | line-height (height) | letter-spacing | palt | 備考 |
|------|-----------|----------------------|---------------|------|------|
| Heading 1 | 24px | 1.4 | 0.04em 相当 | 推奨 | ページタイトル |
| Heading 2 | 18px | 1.4 | 0.04em 相当 | 推奨 | セクション見出し |
| Heading 3 | 15px | 1.4 | normal | なし | カードタイトル |
| Body | 14px | **1.7** | normal | なし | 日本語本文 (1.5以上必須) |
| Body Small | 12px | 1.6 | normal | なし | サブテキスト |
| Label | 11px | 1.5 | 0.5px | なし | チップ・バッジ |
| Caption | 10px | 1.5 | normal | なし | 日付・メタ |

**重要ルール** (awesome-design-md-jp 準拠):
- `letter-spacing: 0.04em` と `palt` は**見出し (h1/h2) にのみ**適用する
- 日本語本文の `line-height` (Flutter: `height`) は **1.5 以上** (推奨 1.7〜2.0)
- 本文に `letter-spacing` を指定しない (`normal` のまま)

### 4. フォントレンダリング (Flutter Web)

```css
/* web/index.html の <style> に追加推奨 */
body {
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  word-wrap: break-word;     /* 長いURLや英単語の折り返し */
}
```

### 5. 禁則処理 (Kinsoku Shori)

Flutter の `Text` ウィジェットはデフォルトで禁則処理を行う。
Web 向けには `SelectableText` + CSS `line-break: strict` を追加推奨:

```css
/* 厳格な禁則処理 */
line-break: strict;
overflow-wrap: break-word;
```

**行頭禁止**: `）」』】〕〉》、。，．・：；？！`
**行末禁止**: `（「『【〔〈《`

### テキストスタイル

```dart
// 見出し (H1) — ページタイトル
// letter-spacing: 0.04em ≈ 24px × 0.04 = 0.96px (日本語見出し推奨)
static const TextStyle heading1 = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.bold,
  color: Colors.white,
  letterSpacing: 0.96,  // 0.04em × 24px — 見出しのみ適用
  height: 1.4,
);

// 見出し (H2) — セクションタイトル
// letter-spacing: 0.04em ≈ 18px × 0.04 = 0.72px (日本語見出し推奨)
static const TextStyle heading2 = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.bold,
  color: Colors.white,
  letterSpacing: 0.72,  // 0.04em × 18px — 見出しのみ適用
  height: 1.4,
);

// 見出し (H3) — カードタイトル
static const TextStyle heading3 = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.bold,
  color: Colors.white,
);

// 本文 (Body) — 標準テキスト
// height (line-height) は日本語本文の最低基準 1.5 以上。推奨 1.7
static const TextStyle body = TextStyle(
  fontSize: 14,
  color: Colors.white,
  height: 1.7,  // 日本語本文推奨 (1.5以上、1.7〜2.0が最適)
  // letterSpacing: 指定しない (日本語本文は normal が推奨)
);

// 本文 (Body Small) — サブテキスト
static const TextStyle bodySmall = TextStyle(
  fontSize: 12,
  color: Color(0xFFB0B0B0),
  height: 1.6,  // 日本語本文規則に準じる
);

// ラベル — チップ・バッジ
static const TextStyle label = TextStyle(
  fontSize: 11,
  color: Color(0xFFB0B0B0),
  letterSpacing: 0.5,
);

// キャプション — 日付・メタ情報
static const TextStyle caption = TextStyle(
  fontSize: 10,
  color: Color(0xFF707070),
);
```

---

## スペーシング

```dart
// 基本単位: 4px
static const double spacing2  = 2.0;
static const double spacing4  = 4.0;
static const double spacing8  = 8.0;
static const double spacing12 = 12.0;
static const double spacing16 = 16.0;
static const double spacing20 = 20.0;
static const double spacing24 = 24.0;
static const double spacing32 = 32.0;
static const double spacing48 = 48.0;
static const double spacing64 = 64.0;

// ページパディング
static const EdgeInsets pagePadding = EdgeInsets.all(16.0);
static const EdgeInsets sectionPadding = EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0);
```

---

## 角丸 (Border Radius)

```dart
static const double radiusSmall  = 8.0;    // チップ・バッジ・小ボタン
static const double radiusMedium = 12.0;   // カード・ダイアログ (標準)
static const double radiusLarge  = 16.0;   // モーダルシート・大カード
static const double radiusXL     = 24.0;   // ボトムシート・フルスクリーンモーダル
static const double radiusCircle = 999.0;  // 円形ボタン・アバター
```

---

## シャドウ・グロー効果

```dart
// カードシャドウ (通常)
static final List<BoxShadow> cardShadow = [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.3),
    blurRadius: 8,
    offset: Offset(0, 2),
  ),
];

// オレンジグロー (CTA・アクティブ状態)
static final List<BoxShadow> orangeGlow = [
  BoxShadow(
    color: Color(0xFFFF6B35).withValues(alpha: 0.3),
    blurRadius: 12,
    offset: Offset(0, 4),
  ),
];

// インディゴグロー (AI 機能)
static final List<BoxShadow> indigoGlow = [
  BoxShadow(
    color: Color(0xFF3D5AFE).withValues(alpha: 0.3),
    blurRadius: 12,
    offset: Offset(0, 4),
  ),
];
```

---

## コンポーネントスタイル

### カード

```dart
// 標準ダークカード
Card(
  color: Color(0xFF1E1E1E),
  margin: EdgeInsets.symmetric(vertical: 6),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    side: BorderSide(color: Color(0xFFFF6B35).withValues(alpha: 0.2)),
  ),
  child: Padding(
    padding: EdgeInsets.all(16),
    child: content,
  ),
)

// KPI サマリーカード (グラジエント背景)
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)]),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Color(0xFF3D5AFE).withValues(alpha: 0.3)),
  ),
)
```

### ボタン

```dart
// プライマリ CTA ボタン (オレンジ)
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: Color(0xFFFF6B35),
    foregroundColor: Colors.white,
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
  ),
  onPressed: onPressed,
  child: Text('アクション'),
)

// セカンダリボタン (アウトライン)
OutlinedButton(
  style: OutlinedButton.styleFrom(
    side: BorderSide(color: Color(0xFFFF6B35)),
    foregroundColor: Color(0xFFFF6B35),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  onPressed: onPressed,
  child: Text('セカンダリ'),
)

// テキストボタン
TextButton(
  style: TextButton.styleFrom(foregroundColor: Color(0xFFFF6B35)),
  onPressed: onPressed,
  child: Text('リンク'),
)
```

### チップ・バッジ

```dart
// インフォチップ (グレー)
Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: Color(0xFF2A2A2A),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: Color(0xFFB0B0B0)),
      SizedBox(width: 4),
      Text(label, style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 11)),
    ],
  ),
)

// タグチップ (オレンジ)
Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: Color(0xFFFF6B35).withValues(alpha: 0.15),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text('#tag', style: TextStyle(color: Color(0xFFFF6B35), fontSize: 11)),
)

// AI バッジ (インディゴ)
Container(
  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  decoration: BoxDecoration(
    color: Color(0xFF3D5AFE).withValues(alpha: 0.2),
    borderRadius: BorderRadius.circular(6),
  ),
  child: Text('AI', style: TextStyle(color: Color(0xFF7986CB), fontSize: 10, fontWeight: FontWeight.bold)),
)

// LIVE バッジ (グリーン・点滅)
Container(
  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  decoration: BoxDecoration(
    color: Color(0xFF4CAF50).withValues(alpha: 0.2),
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: Color(0xFF4CAF50).withValues(alpha: 0.5)),
  ),
  child: Text('LIVE', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 9, fontWeight: FontWeight.bold)),
)
```

### テキストフィールド

```dart
TextField(
  style: TextStyle(color: Colors.white),
  decoration: InputDecoration(
    hintText: 'プレースホルダー',
    hintStyle: TextStyle(color: Color(0xFF707070)),
    filled: true,
    fillColor: Color(0xFF2A2A2A),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Color(0xFFFF6B35), width: 1.5),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  ),
)
```

### AppBar

```dart
AppBar(
  backgroundColor: Color(0xFF1A1A1A),
  elevation: 0,
  title: Text(
    'ページタイトル',
    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
  ),
  iconTheme: IconThemeData(color: Colors.white),
  actions: [...],
)
```

### SnackBar

```dart
// 成功
SnackBar(
  content: Text('操作が完了しました'),
  backgroundColor: Color(0xFF4CAF50),
  duration: Duration(seconds: 2),
)

// エラー
SnackBar(
  content: Text('エラーが発生しました'),
  backgroundColor: Colors.red,
  duration: Duration(seconds: 3),
)
```

---

## アイコンガイドライン

| 用途 | アイコン | カラー |
|------|---------|--------|
| ギタースタジオ | Icons.music_note | #FF6B35 |
| AI 機能 | Icons.psychology | #3D5AFE |
| 成長・グロース | Icons.trending_up | #4CAF50 |
| カレンダー | Icons.calendar_today | #FF6B35 |
| 設定 | Icons.settings | #B0B0B0 |
| 検索 | Icons.search | #B0B0B0 |
| お気に入り | Icons.favorite | Colors.red |
| シェア | Icons.share | #FF6B35 |
| 公開 | Icons.public | #4CAF50 |
| 非公開 | Icons.lock | #B0B0B0 |
| 削除 | Icons.delete_outline | Colors.red |
| 追加 | Icons.add_circle | #FF6B35 |
| 完了 | Icons.check_circle | #4CAF50 |

---

## アニメーション

```dart
// 標準トランジション
Duration(milliseconds: 150)   // ホバー・フォーカス
Duration(milliseconds: 300)   // ページ遷移
Duration(milliseconds: 500)   // モーダル表示

// Curves
Curves.easeInOut    // 標準
Curves.easeOut      // 表示アニメーション
Curves.easeIn       // 非表示アニメーション
```

---

## ダークテーマ特有のパターン

### グロー効果 (光が漏れているような表現)

```dart
// アクティブなカード・重要な要素に適用
BoxDecoration(
  color: Color(0xFF1E1E1E),
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: Color(0xFFFF6B35).withValues(alpha: 0.3)),
  boxShadow: [
    BoxShadow(
      color: Color(0xFFFF6B35).withValues(alpha: 0.1),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ],
)
```

### セパレーター

```dart
Divider(color: Color(0xFF2A2A2A), height: 1)
```

### 空状態 (Empty State)

```dart
// データがない場合の表示パターン
Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Icon(Icons.xxx, color: Color(0xFFFF6B35), size: 64),
    SizedBox(height: 16),
    Text('まだデータがありません', style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 16)),
    SizedBox(height: 8),
    Text('説明テキスト', style: TextStyle(color: Color(0xFF707070))),
    SizedBox(height: 16),
    ElevatedButton(/* CTA */),
  ],
)
```

---

## 日本語タイポグラフィ詳細ガイド

> Source: [awesome-design-md-jp](https://github.com/kzhrknt/awesome-design-md-jp) — note / freee / SmartHR デザインシステムより抽出

### フォントフォールバックチェーン (Flutter Web)

```dart
// Flutter Web の場合、Google Fonts を使用
// pubspec.yaml に追記済み: google_fonts: ^6.x
// 必ず NotoSansJP を第一候補にすること
fontFamily: GoogleFonts.notoSansJp().fontFamily,

// CSS での宣言参考 (index.html / web向け)
// font-family: "Noto Sans JP", "Hiragino Sans", "Yu Gothic", "Meiryo", sans-serif;
```

### 日本語固有の行間・文字間隔ルール

```dart
// 本文テキスト — 日本語は Western より広い行間が必要
// 参考: note.com = 2.0, freee = 1.5, SmartHR = 1.5
// 自分株式会社は読みやすさ重視で 1.7 を基準に
static const double lineHeightBody    = 1.7;  // 本文 (note基準: 2.0, 短文UI: 1.5)
static const double lineHeightHeading = 1.25; // 見出し (SmartHR基準)
static const double lineHeightCaption = 1.5;  // キャプション・チップ

// 文字間隔 — 日本語本文には設定しない (0)
// 見出しのみ 0.02em〜0.04em で少し開ける (note基準: 0.04em)
// Flutter では letterSpacing (px単位) を使用:
//   fontSize 16px × 0.04em = 0.64px ≒ 0.5
static const double letterSpacingHeading = 0.5;  // H1〜H3
static const double letterSpacingBody    = 0.0;  // 本文・ボタン (設定しない)
```

### 禁則処理と改行ルール

```dart
// Flutterでは自動で日本語禁則処理が適用される。
// ただし長い英単語やURLが含まれる場合は softWrap: true を明示
Text(
  content,
  softWrap: true,
  overflow: TextOverflow.ellipsis, // 1行制限の場合のみ
  maxLines: null,                  // 多行テキストは制限しない
)

// カード本文の最大行数: 3〜4行 (UI密度に合わせて)
// 長文表示エリア (ノート・ブログ) の最大幅: 660px (note基準: 620px)
```

### 日本語UIで避けるべきパターン

```
❌ letter-spacing を全テキストに適用 (本文が読みにくくなる)
❌ font-weight: 700 を多用 (日本語フォントは 500 でも十分太い)
❌ 純粋な白 (#FFFFFF) のテキスト on ダーク (目が疲れる → textPrimary 参照)
❌ 英語UIの行間 (1.4) をそのまま日本語に適用
✅ 見出し: 700〜800, 本文: 400〜500
✅ 行間: 本文 1.6〜1.8, 短文UI 1.4〜1.5
✅ 文字間隔: 見出し 0.02〜0.04em のみ, 本文 0
```

### 参考サービスのキーカラー (競合分析用)

| サービス | ブランドカラー | 本文色 | 用途参考 |
|---------|-------------|-------|---------|
| note.com | `#41C9B0` (teal) | `#08131a` | コンテンツ投稿・ライト |
| freee | `#2864F0` (blue) | `#595959` | 会計・HR・企業向け |
| SmartHR | `#0077C7` (blue) | warm gray | HR・給与管理 |

---

## 参考デザイン

自分株式会社のデザインは以下を参考にしています:

### 海外サービス (awesome-design-md より)
- **Spotify** — 漆黒の背景、鮮やかなアクセント、アートワーク主役のレイアウト
- **Linear** — 極限まで削ぎ落としたミニマル、精密な余白、アクセントカラー
- **GitHub** — 機能的で情報密度が高い、ダークモード完全対応

### 国内サービス ([awesome-design-md-jp](https://github.com/kzhrknt/awesome-design-md-jp) より)
- **note.com** — 日本語コンテンツ投稿、行間 2.0、本文 18px の読みやすさ基準
- **freee** — 日本のビジネス向けUI、4px ベーススペーシング、セマンティックカラー体系
- **SmartHR** — 日本語 HR プラットフォーム、Yu Gothic 対応、8px ベーススペーシング

---

## 禁止事項

1. ライトテーマの使用 (アプリ全体を常にダークモードで維持)
2. `withOpacity()` の使用 → 代わりに `withValues(alpha: x)` を使用
3. 白背景 (#FFFFFF) の使用 → surface1〜4 を使用
4. オレンジ以外のメインアクセントカラーの追加 (ブランド一貫性のため)
5. 日本語本文への `letterSpacing` 設定 (見出しのみ 0.5px まで許容)
6. 10px 未満のフォントサイズ (アクセシビリティのため)
7. `line-height` (Flutter: `height`) を 1.4 未満にする (日本語可読性が著しく低下)

---

## Agent Prompt Guide

> AI エージェントが素早くデザイントークンを参照できるクイックリファレンス。
> Source: [awesome-design-md-jp](https://github.com/kzhrknt/awesome-design-md-jp) テンプレート準拠

### クイックリファレンス

```
■ カラー
Background:     #0A0A0A  (最暗・メイン背景)
Surface Card:   #1E1E1E  (カード背景)
Surface Input:  #2A2A2A  (入力欄・チップ)
Accent Orange:  #FF6B35  (CTA・メインアクション)
Accent Indigo:  #3D5AFE  (AI機能・プレミアム)
Accent Green:   #4CAF50  (成功・完了・KPI)
Accent Red:     #E53935  (エラー・削除)
Text Primary:   #FFFFFF  (メインテキスト)
Text Secondary: #B0B0B0  (サブテキスト)
Text Tertiary:  #707070  (プレースホルダー)
Border Glow:    #FF6B35 @ alpha 0.2-0.3

■ タイポグラフィ (日本語最適化)
Font:           Noto Sans JP → Hiragino → Meiryo → sans-serif
Heading 1:      24px / bold / height: 1.4 / letterSpacing: 0.96px
Heading 2:      18px / bold / height: 1.4 / letterSpacing: 0.72px
Heading 3:      15px / bold / height: 1.4
Body:           14px / regular / height: 1.7  ← 日本語: 1.5以上必須
Body Small:     12px / regular / height: 1.6
Label (chip):   11px / regular / letterSpacing: 0.5px
Caption:        10px / regular / height: 1.5
※ 本文 (Body) に letterSpacing を設定しない (日本語規則)
※ palt (プロポーショナル字詰め) は見出しのみ推奨

■ スペーシング (4px ベース)
XS: 4px  S: 8px  M: 12px  L: 16px  XL: 24px  XXL: 32px
pagePadding: 16px  sectionPadding: 24px vertical / 16px horizontal

■ 角丸
Small: 8px (チップ)  Medium: 12px (カード)  Large: 16px (モーダル)  XL: 24px

■ API エンドポイント
Project URL: https://my-web-app-b67f4.web.app/
Supabase:    https://smmkxxavexumewbfaqpy.supabase.co/
```

### Flutter コードプロンプト例

```
自分株式会社のデザインシステムに従って Flutter Widget を作成してください。
- 背景: Color(0xFF0A0A0A)
- カード: Color(0xFF1E1E1E) + BorderRadius.circular(12)
- CTAボタン: Color(0xFFFF6B35) → orangeGradient + borderRadius 12
- 日本語フォント: NotoSansJP / height: 1.7 (本文) / 1.4 (見出し)
- 見出し letterSpacing: 0.96px (H1) / 0.72px (H2) / 0 (本文)
- deprecated withOpacity() を使わず withValues(alpha: x) を使用
- ライトテーマ不可 (常にダークテーマ)
- Edge Function 呼び出し: Supabase Edge Function ファースト
```
