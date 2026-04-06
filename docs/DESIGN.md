# 自分株式会社 — DESIGN.md
# デザインシステム定義 (AI エージェント参照用)

> このファイルは Awesome Design MD フォーマットに準拠しています。
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

### フォント

```dart
// 日本語: Noto Sans JP (Google Fonts)
// 英数字: Inter (Google Fonts) — 日本語フォントにフォールバック
fontFamily: 'NotoSansJP',
```

### テキストスタイル

```dart
// 見出し (H1) — ページタイトル
static const TextStyle heading1 = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.bold,
  color: Colors.white,
  letterSpacing: -0.5,
);

// 見出し (H2) — セクションタイトル
static const TextStyle heading2 = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.bold,
  color: Colors.white,
);

// 見出し (H3) — カードタイトル
static const TextStyle heading3 = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.bold,
  color: Colors.white,
);

// 本文 (Body) — 標準テキスト
static const TextStyle body = TextStyle(
  fontSize: 14,
  color: Colors.white,
  height: 1.5,
);

// 本文 (Body Small) — サブテキスト
static const TextStyle bodySmall = TextStyle(
  fontSize: 12,
  color: Color(0xFFB0B0B0),
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

## 参考デザイン

自分株式会社のデザインは以下を参考にしています:

- **Spotify** — 漆黒の背景、鮮やかなアクセント、アートワーク主役のレイアウト
- **Linear** — 極限まで削ぎ落としたミニマル、精密な余白、アクセントカラー
- **GitHub** — 機能的で情報密度が高い、ダークモード完全対応

---

## 禁止事項

1. ライトテーマの使用 (アプリ全体を常にダークモードで維持)
2. `withOpacity()` の使用 → 代わりに `withValues(alpha: x)` を使用
3. 白背景 (#FFFFFF) の使用 → surface1〜4 を使用
4. オレンジ以外のメインアクセントカラーの追加 (ブランド一貫性のため)
5. 10px 未満のフォントサイズ (アクセシビリティのため)
