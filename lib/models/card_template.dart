enum CardTemplate {
  minimal('ミニマル'),
  modern('モダン'),
  gradient('グラデーション'),
  darkMode('ダークモード'),
  colorful('カラフル');

  const CardTemplate(this.label);
  final String label;
}

class CardStyle {
  final CardTemplate template;
  final bool includeStats;
  final bool includeQRCode;
  final bool includeLogo;

  const CardStyle({
    required this.template,
    this.includeStats = true,
    this.includeQRCode = false,
    this.includeLogo = true,
  });
}