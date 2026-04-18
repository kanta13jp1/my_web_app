import 'package:flutter/material.dart';

class ClaudeDesignHandoff {
  final DesignTokens tokens;
  final List<DesignComponent> components;
  final List<DesignPage> pages;
  final String? sourceBundleId;
  final DateTime importedAt;

  const ClaudeDesignHandoff({
    required this.tokens,
    required this.components,
    required this.pages,
    this.sourceBundleId,
    required this.importedAt,
  });

  factory ClaudeDesignHandoff.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> asStrMap(Object? v) =>
        v == null ? {} : Map<String, dynamic>.from(v as Map);
    return ClaudeDesignHandoff(
      tokens: DesignTokens.fromJson(asStrMap(json['tokens'])),
      components: ((json['components'] as List<dynamic>?) ?? [])
          .map(
            (e) =>
                DesignComponent.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      pages: ((json['pages'] as List<dynamic>?) ?? [])
          .map((e) => DesignPage.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      sourceBundleId: json['sourceBundleId'] as String?,
      importedAt: json['importedAt'] != null
          ? DateTime.parse(json['importedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'tokens': tokens.toJson(),
        'components': components.map((c) => c.toJson()).toList(),
        'pages': pages.map((p) => p.toJson()).toList(),
        'sourceBundleId': sourceBundleId,
        'importedAt': importedAt.toIso8601String(),
      };
}

class DesignTokens {
  final Map<String, Color> colors;
  final Map<String, TextStyle> typography;
  final Map<String, double> spacing;
  final Map<String, double> radius;

  const DesignTokens({
    required this.colors,
    required this.typography,
    required this.spacing,
    required this.radius,
  });

  factory DesignTokens.fromJson(Map<String, dynamic> json) {
    final rawColors = (json['colors'] as Map<String, dynamic>?) ?? {};
    final colors = <String, Color>{};
    for (final entry in rawColors.entries) {
      final hex = (entry.value as String?)?.replaceAll('#', '');
      if (hex != null && hex.length == 6) {
        colors[entry.key] = Color(int.parse('FF$hex', radix: 16));
      } else if (hex != null && hex.length == 8) {
        colors[entry.key] = Color(int.parse(hex, radix: 16));
      }
    }

    final rawTypo = (json['typography'] as Map<String, dynamic>?) ?? {};
    final typography = <String, TextStyle>{};
    for (final entry in rawTypo.entries) {
      final map = entry.value as Map<String, dynamic>? ?? {};
      typography[entry.key] = TextStyle(
        fontSize: (map['fontSize'] as num?)?.toDouble(),
        fontWeight: _parseFontWeight(map['fontWeight']),
        letterSpacing: (map['letterSpacing'] as num?)?.toDouble(),
        height: (map['lineHeight'] as num?)?.toDouble(),
      );
    }

    final rawSpacing = (json['spacing'] as Map<String, dynamic>?) ?? {};
    final spacing = rawSpacing.map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    );

    final rawRadius = (json['radius'] as Map<String, dynamic>?) ?? {};
    final radius = rawRadius.map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    );

    return DesignTokens(
      colors: colors,
      typography: typography,
      spacing: spacing,
      radius: radius,
    );
  }

  Map<String, dynamic> toJson() => {
        'colors': colors.map(
          (k, v) => MapEntry(
            k,
            '#${v.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
          ),
        ),
        'typography': typography.map(
          (k, v) => MapEntry(k, {
            'fontSize': v.fontSize,
            'fontWeight': v.fontWeight != null
                ? '${(v.fontWeight!.index + 1) * 100}'
                : null,
            'letterSpacing': v.letterSpacing,
            'lineHeight': v.height,
          }),
        ),
        'spacing': spacing,
        'radius': radius,
      };

  static FontWeight? _parseFontWeight(dynamic value) {
    switch (value?.toString()) {
      case '100':
        return FontWeight.w100;
      case '200':
        return FontWeight.w200;
      case '300':
        return FontWeight.w300;
      case '400':
      case 'normal':
        return FontWeight.w400;
      case '500':
        return FontWeight.w500;
      case '600':
        return FontWeight.w600;
      case '700':
      case 'bold':
        return FontWeight.w700;
      case '800':
        return FontWeight.w800;
      case '900':
        return FontWeight.w900;
      default:
        return null;
    }
  }
}

class DesignComponent {
  final String name;
  final String htmlSnippet;
  final Map<String, dynamic> props;

  const DesignComponent({
    required this.name,
    required this.htmlSnippet,
    this.props = const {},
  });

  factory DesignComponent.fromJson(Map<String, dynamic> json) =>
      DesignComponent(
        name: json['name'] as String? ?? 'unnamed',
        htmlSnippet: json['htmlSnippet'] as String? ?? '',
        props: (json['props'] as Map<String, dynamic>?) ?? {},
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'htmlSnippet': htmlSnippet,
        'props': props,
      };
}

class DesignPage {
  final String name;
  final String route;
  final String description;

  const DesignPage({
    required this.name,
    required this.route,
    this.description = '',
  });

  factory DesignPage.fromJson(Map<String, dynamic> json) => DesignPage(
        name: json['name'] as String? ?? 'unnamed',
        route: json['route'] as String? ?? '/',
        description: json['description'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'route': route,
        'description': description,
      };
}
