# UI Design Skill — 自分株式会社

## このスキルの目的

Flutter Web (Material3) で日本語SaaSの高品質UIを生成するためのガイドライン。
awesome-design-md-jp (note/freee/SmartHR/Apple JP/WIRED.jp) のデザイントークンを
このプロジェクトのデザインシステムに統合したもの。

---

## プロジェクト固有のデザイントークン

### カラーシステム

```dart
// Primary
const Color kPrimary = Color(0xFF6366F1);        // indigo-500
const Color kPrimaryDark = Color(0xFF4F46E5);    // indigo-600
const Color kPrimaryLight = Color(0xFFEEF2FF);   // indigo-50

// Semantic
const Color kSuccess = Color(0xFF22C55E);
const Color kWarning = Color(0xFFF59E0B);
const Color kDanger = Color(0xFFEF4444);

// Text
const Color kTextPrimary = Color(0xFF1E293B);    // slate-800
const Color kTextSecondary = Color(0xFF64748B);  // slate-500
const Color kTextDisabled = Color(0xFFCBD5E1);   // slate-300

// Surface
const Color kBgPage = Color(0xFFF8FAFC);         // slate-50
const Color kBgCard = Color(0xFFFFFFFF);
const Color kBorder = Color(0xFFE2E8F0);         // slate-200
```

### スペーシングスケール (8pxグリッド)

```dart
const double kSpaceXS = 4.0;
const double kSpaceSM = 8.0;
const double kSpaceMD = 16.0;
const double kSpaceLG = 24.0;
const double kSpaceXL = 40.0;
const double kSpaceXXL = 64.0;
```

### ボーダーラジウス (統一ルール)

```dart
// ❌ NG: 10, 14, 20, 999 を散在させない
// ✅ OK: 以下の3段階のみ使用
const double kRadiusSM = 8.0;    // チップ、バッジ、小アイコン背景
const double kRadiusMD = 12.0;   // ボタン、入力欄
const double kRadiusLG = 16.0;   // カード、セクションコンテナ
const double kRadiusPill = 999.0; // ピルバッジのみ
```

---

## 日本語タイポグラフィ ルール (厳守)

### Line Height

```dart
// ✅ 本文 (body text)
const double kLineHeightBody = 1.7;    // 16-18px用
const double kLineHeightCaption = 1.6; // 12-14px用

// ✅ 見出し
const double kLineHeightHeading = 1.4; // h1-h3用
const double kLineHeightDisplay = 1.25; // 大見出し用
```

### Letter Spacing — 最重要ルール

```dart
// ✅ 見出し (palt効果を補う)
// headlineLarge: letterSpacing 0.96 (= 0.04em × 24px)
// headlineMedium: letterSpacing 0.72 (= 0.04em × 18px)

// ❌ 絶対禁止: 本文・ラベル・バッジに letterSpacing を設定しない
// 違反例:
//   TextStyle(letterSpacing: 0.5)  // 本文系はすべて NG
//   labelMedium.copyWith(letterSpacing: 0.5)  // NG
//   TextStyle(fontSize: 12, letterSpacing: 0.5)  // NG
//
// 例外: 全大文字ラベル ("LIVE", "NEW", "BETA" など) は 0.5〜1.0 OK
```

---

## コンポーネント生成ガイド

### ✅ カード (標準)

```dart
Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),  // kRadiusLG
    border: Border.all(color: const Color(0xFFE2E8F0)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  ),
  child: ...,
)
```

### ✅ プライマリボタン

```dart
FilledButton(
  style: FilledButton.styleFrom(
    backgroundColor: const Color(0xFF6366F1),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),  // kRadiusMD
    ),
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
    minimumSize: const Size(0, 48),
  ),
  onPressed: onPressed,
  child: Text(
    label,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      // letterSpacing は設定しない
    ),
  ),
)
```

### ✅ セカンダリボタン

```dart
OutlinedButton(
  style: OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF6366F1),
    side: const BorderSide(color: Color(0xFF6366F1)),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
    minimumSize: const Size(0, 48),
  ),
  ...
)
```

### ✅ バッジ (ピル型)

```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  decoration: BoxDecoration(
    color: const Color(0xFFEEF2FF),
    borderRadius: BorderRadius.circular(999),
    border: Border.all(color: const Color(0xFFC7D2FE)),
  ),
  child: Text(
    label,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Color(0xFF4F46E5),
      // letterSpacing: 設定しない
    ),
  ),
)
```

### ✅ アイコン付きリストアイテム

```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),  // kRadiusSM
      ),
      child: Icon(icon, size: 18, color: iconColor),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B), height: 1.4)),
          Text(desc, style: TextStyle(fontSize: 12,
              color: const Color(0xFF64748B), height: 1.6)),
        ],
      ),
    ),
  ],
)
```

---

## アンチパターン (やってはいけないこと)

```dart
// ❌ Colors.black54 を直接使わない → Color(0xFF64748B) を使う
TextStyle(color: Colors.black54)  // NG
TextStyle(color: const Color(0xFF64748B))  // OK

// ❌ border-radius をバラバラに設定しない
BorderRadius.circular(14)  // NG
BorderRadius.circular(16)  // OK (kRadiusLG)

// ❌ 本文に letterSpacing を設定しない
TextStyle(letterSpacing: 0.5)  // NG (本文系はすべて)

// ❌ 日本語本文の line-height を 1.5 未満にしない
TextStyle(height: 1.3)  // NG (本文の場合)
TextStyle(height: 1.7)  // OK

// ❌ shadow を強くしすぎない
BoxShadow(blurRadius: 24, color: Colors.black.withValues(alpha: 0.3))  // NG (重すぎ)
BoxShadow(blurRadius: 8, color: Colors.black.withValues(alpha: 0.04))  // OK

// ❌ 1画面に3色以上のアクセントカラーを使わない
// NG: 紫+緑+黄+赤 が同一セクションに混在
// OK: 主色(indigo)+ 1つのアクセント
```

---

## Flutter Web 特有の注意点

1. **レスポンシブ**: `LayoutBuilder` か `MediaQuery.of(context).size.width` で breakpoint を判定
2. **最大幅**: コンテンツコンテナは `maxWidth: 440` (モバイルファースト)
3. **フォントローディング**: `NotoSansJP` は pubspec.yaml で宣言済み
4. **flutter analyze**: 変更後は必ず `flutter analyze lib/ 2>&1 | tail -5` で0エラーを確認
