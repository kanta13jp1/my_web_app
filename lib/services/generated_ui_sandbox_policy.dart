import 'dart:convert';

class GeneratedUiSandboxCandidate {
  const GeneratedUiSandboxCandidate({
    required this.html,
    required this.rejectionReasons,
  });

  final String html;
  final List<String> rejectionReasons;

  bool get isPreviewAllowed => rejectionReasons.isEmpty;
}

class GeneratedUiSandboxPolicy {
  const GeneratedUiSandboxPolicy._();

  static const iframeSandbox = 'allow-scripts';

  static const csp = "default-src 'none'; "
      "script-src 'unsafe-inline'; "
      "style-src 'unsafe-inline'; "
      'img-src data: blob:; '
      'font-src data:; '
      "connect-src 'none'; "
      'media-src data: blob:; '
      "object-src 'none'; "
      "base-uri 'none'; "
      "form-action 'none'; "
      "frame-ancestors 'none'";

  static final _htmlFence = RegExp(
    r'```(?:html|sandbox-html|ui-html)\s*([\s\S]*?)```',
    caseSensitive: false,
  );

  static final List<({RegExp pattern, String reason})> _denyPatterns = [
    (
      pattern: RegExp(
        r'\b(fetch|XMLHttpRequest|WebSocket|EventSource)\s*\(',
        caseSensitive: false,
      ),
      reason: 'network API call',
    ),
    (
      pattern: RegExp(
        r'\b(localStorage|sessionStorage|indexedDB|document\.cookie|cookie)\b',
        caseSensitive: false,
      ),
      reason: 'browser credential or storage access',
    ),
    (
      pattern: RegExp(
        r'\b(supabase|createClient|Authorization|Bearer|service[_-]?role|apikey)\b',
        caseSensitive: false,
      ),
      reason: 'Supabase/Auth/secret keyword',
    ),
    (
      pattern: RegExp(
        r'\b(window\.parent|window\.top|parent\.|top\.|postMessage)\b',
        caseSensitive: false,
      ),
      reason: 'parent-window bridge',
    ),
    (
      pattern: RegExp(r'<\s*iframe\b', caseSensitive: false),
      reason: 'nested iframe',
    ),
    (
      pattern: RegExp(r'<\s*form\b', caseSensitive: false),
      reason: 'form submission surface',
    ),
    (
      pattern: RegExp(r'<\s*script\b[^>]*\bsrc\s*=', caseSensitive: false),
      reason: 'external script source',
    ),
    (
      pattern: RegExp(r'\bimport\s*\(', caseSensitive: false),
      reason: 'dynamic import',
    ),
  ];

  static GeneratedUiSandboxCandidate? extractFirstPreviewCandidate(
    String message,
  ) {
    final match = _htmlFence.firstMatch(message);
    if (match == null) return null;
    final html = (match.group(1) ?? '').trim();
    if (html.isEmpty) return null;
    return evaluate(html);
  }

  static GeneratedUiSandboxCandidate evaluate(String html) {
    final reasons = <String>[];
    for (final entry in _denyPatterns) {
      if (entry.pattern.hasMatch(html)) {
        reasons.add(entry.reason);
      }
    }
    return GeneratedUiSandboxCandidate(
      html: html,
      rejectionReasons: List.unmodifiable(reasons),
    );
  }

  static String buildSrcDoc({
    required String htmlFragment,
    String title = 'Generated UI preview',
  }) {
    const attributeEscape = HtmlEscape(HtmlEscapeMode.attribute);
    const textEscape = HtmlEscape();
    return '''
<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="Content-Security-Policy" content="${attributeEscape.convert(csp)}">
  <title>${textEscape.convert(title)}</title>
  <style>
    :root { color-scheme: light dark; font-family: system-ui, sans-serif; }
    html, body { margin: 0; min-height: 100%; background: transparent; }
    body { box-sizing: border-box; padding: 12px; overflow-wrap: anywhere; }
    *, *::before, *::after { box-sizing: border-box; }
  </style>
</head>
<body data-vibe-sandbox="leaf-preview">
$htmlFragment
</body>
</html>
''';
  }

  static bool get cspBlocksBackendAccess =>
      csp.contains("default-src 'none'") &&
      csp.contains("connect-src 'none'") &&
      csp.contains("form-action 'none'") &&
      csp.contains("base-uri 'none'");

  static bool get iframeUsesUniqueOpaqueOrigin =>
      !iframeSandbox.contains('allow-same-origin') &&
      !iframeSandbox.contains('allow-top-navigation') &&
      !iframeSandbox.contains('allow-popups');
}
