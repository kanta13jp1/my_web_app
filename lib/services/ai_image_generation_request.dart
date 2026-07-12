enum AiImageGenerationQuality {
  low(value: 'low', label: '高速', description: 'アイデア出しや大量生成向け。待ち時間を短くします。'),
  medium(value: 'medium', label: '標準', description: '速度と品質のバランスを取った通常設定です。'),
  high(value: 'high', label: '高画質', description: '細部の忠実度を優先します。図解や仕上げ用途向けです。');

  const AiImageGenerationQuality({
    required this.value,
    required this.label,
    required this.description,
  });

  final String value;
  final String label;
  final String description;

  static AiImageGenerationQuality fromValue(String? value) {
    for (final quality in values) {
      if (quality.value == value) return quality;
    }
    return medium;
  }
}

Map<String, Object> buildAiImageGenerateBody({
  required String prompt,
  required String size,
  required String style,
  required AiImageGenerationQuality quality,
}) {
  return {
    'action': 'image.generate',
    'prompt': prompt,
    'size': size,
    'style': style,
    'quality': quality.value,
  };
}
