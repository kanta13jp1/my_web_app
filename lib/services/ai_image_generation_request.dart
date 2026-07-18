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

class AiImageStructuredPrompt {
  const AiImageStructuredPrompt({
    required this.sceneAndSubject,
    required this.detailsAndStyle,
    required this.constraints,
    required this.imageText,
  });

  final String sceneAndSubject;
  final String detailsAndStyle;
  final String constraints;
  final String imageText;

  bool get hasInput =>
      sceneAndSubject.trim().isNotEmpty ||
      detailsAndStyle.trim().isNotEmpty ||
      constraints.trim().isNotEmpty ||
      imageText.trim().isNotEmpty;

  String buildPrompt() {
    final parts = <String>[];
    final scene = sceneAndSubject.trim();
    final details = detailsAndStyle.trim();
    final constraintText = constraints.trim();
    final typographyText = imageText.trim();

    if (scene.isNotEmpty) {
      parts.add('Scene and subject:\n$scene');
    }
    if (details.isNotEmpty) {
      parts.add('Details and style:\n$details');
    }
    if (constraintText.isNotEmpty) {
      parts.add('Constraints to preserve or avoid:\n$constraintText');
    }
    if (typographyText.isNotEmpty) {
      parts.add(
        'Image text:\n"${typographyText.toUpperCase()}" in clean, readable typography.',
      );
    }

    return parts.join('\n\n');
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
