import 'package:flutter/material.dart';

/// docs/DESIGN.md の Orange + Indigo ダークテーマ デザイントークン。
///
/// 色・余白・角丸をここへ集約し、各 Widget に散在するハードコード値を
/// 本クラス参照へ段階的に寄せることで、テーマ一貫性と将来の一括改修容易性を高める。
/// 値は DESIGN.md の正本トークンに一致する (挙動を変えずに名前を与える)。
abstract final class DesignTokens {
  DesignTokens._();

  // ── 背景 / サーフェス ───────────────────────────────
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface1 = Color(0xFF1A1A1A); // カード
  static const Color surface2 = Color(0xFF1E1E1E); // カード内
  static const Color surface3 = Color(0xFF2A2A2A); // チップ/入力
  static const Color divider = Color(0xFF2A2A2A);

  // ── アクセント ─────────────────────────────────────
  static const Color orange = Color(0xFFFF6B35); // CTA / メインアクション
  static const Color orangeLight = Color(0xFFFF8C5A);
  static const Color orangeDark = Color(0xFFCC4A1A);
  static const Color indigo = Color(0xFF3D5AFE); // AI / プレミアム
  static const Color indigoLight = Color(0xFF7986CB);
  static const Color green = Color(0xFF4CAF50); // 成功
  static const Color red = Color(0xFFE53935); // エラー
  static const Color amber = Color(0xFFFFC107);
  static const Color gold = Color(0xFFFFD700);
  static const Color blueLight = Color(0xFF90CAF9);

  // ── テキスト ───────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// 長文・本文向けのやや柔らかい白 (純白より眼にやさしい / a11y)。
  static const Color textOnDark = Color(0xFFE5E7EB);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textTertiary = Color(0xFF707070);
  static const Color textDisabled = Color(0xFF404040);

  // ── 余白 (4px ベース) ──────────────────────────────
  static const double space2 = 2;
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;

  // ── 角丸 ───────────────────────────────────────────
  static const double radiusSmall = 8; // チップ / バッジ
  static const double radiusMedium = 12; // カード (標準)
  static const double radiusLarge = 16; // モーダル
  static const double radiusXl = 24; // ボトムシート
  static const double radiusCircle = 999;
}
