enum CardTemplate {
  minimal('ミニマル'),
  modern('モダン'),
  gradient('グラデーション'),
  darkMode('ダークモード'),
  colorful('カラフル');

  const CardTemplate(this.label);
  final String label;
}

enum AspectRatio {
  square('1:1 正方形', 1080, 1080),
  portrait('4:5 縦長', 1080, 1350),
  landscape('16:9 横長', 1200, 675);

  const AspectRatio(this.label, this.width, this.height);
  final String label;
  final int width;
  final int height;
}

enum ContentMode {
  full('全文表示', 800),
  smart('スマート分割', 500),
  summary('要約モード', 300);

  const ContentMode(this.label, this.maxCharsPerPage);
  final String label;
  final int maxCharsPerPage;
}

enum FontSizeOption {
  small('小', 0.8),
  medium('中', 1.0),
  large('大', 1.2);

  const FontSizeOption(this.label, this.scale);
  final String label;
  final double scale;
}

class CardStyle {
  final CardTemplate template;
  final bool includeStats;
  final bool includeQRCode;
  final bool includeLogo;
  final AspectRatio aspectRatio;
  final ContentMode contentMode;
  final FontSizeOption fontSize;
  final bool autoHashtags;

  const CardStyle({
    required this.template,
    this.includeStats = true,
    this.includeQRCode = false,
    this.includeLogo = true,
    this.aspectRatio = AspectRatio.square,
    this.contentMode = ContentMode.smart,
    this.fontSize = FontSizeOption.medium,
    this.autoHashtags = true,
  });

  CardStyle copyWith({
    CardTemplate? template,
    bool? includeStats,
    bool? includeQRCode,
    bool? includeLogo,
    AspectRatio? aspectRatio,
    ContentMode? contentMode,
    FontSizeOption? fontSize,
    bool? autoHashtags,
  }) {
    return CardStyle(
      template: template ?? this.template,
      includeStats: includeStats ?? this.includeStats,
      includeQRCode: includeQRCode ?? this.includeQRCode,
      includeLogo: includeLogo ?? this.includeLogo,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      contentMode: contentMode ?? this.contentMode,
      fontSize: fontSize ?? this.fontSize,
      autoHashtags: autoHashtags ?? this.autoHashtags,
    );
  }
}