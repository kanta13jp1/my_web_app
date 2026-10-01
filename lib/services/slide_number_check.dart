class SlideNumberCheck {
  const SlideNumberCheck({required this.growthPercent, required this.pointDifference});

  final double growthPercent;
  final double pointDifference;

  static SlideNumberCheck calculate(String beforeText, String afterText) {
    final before = double.tryParse(beforeText.trim());
    final after = double.tryParse(afterText.trim());
    if (before == null || after == null || !before.isFinite || !after.isFinite ||
        before <= 0 || after < 0 || before > 1e12 || after > 1e12) {
      throw const FormatException('基準は0より大きく、比較値は0以上の数値を入力してください。上限は1兆です。');
    }
    final growth = (after / before - 1) * 100;
    if (!growth.isFinite) {
      throw const FormatException('値の差が大きすぎて計算できません。');
    }
    return SlideNumberCheck(growthPercent: growth, pointDifference: after - before);
  }
}
