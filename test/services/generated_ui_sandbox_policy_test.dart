import 'package:my_web_app/services/generated_ui_sandbox_policy.dart';
import 'package:test/test.dart';

void main() {
  group('GeneratedUiSandboxPolicy', () {
    test('uses an opaque-origin iframe sandbox', () {
      expect(GeneratedUiSandboxPolicy.iframeSandbox, contains('allow-scripts'));
      expect(
        GeneratedUiSandboxPolicy.iframeSandbox,
        isNot(contains('allow-same-origin')),
      );
      expect(
        GeneratedUiSandboxPolicy.iframeSandbox,
        isNot(contains('allow-top-navigation')),
      );
      expect(
        GeneratedUiSandboxPolicy.iframeSandbox,
        isNot(contains('allow-popups')),
      );
      expect(GeneratedUiSandboxPolicy.iframeUsesUniqueOpaqueOrigin, isTrue);
    });

    test('CSP blocks backend, form, and secret exfiltration routes', () {
      expect(GeneratedUiSandboxPolicy.csp, contains("default-src 'none'"));
      expect(GeneratedUiSandboxPolicy.csp, contains("connect-src 'none'"));
      expect(GeneratedUiSandboxPolicy.csp, contains("form-action 'none'"));
      expect(GeneratedUiSandboxPolicy.csp, contains("base-uri 'none'"));
      expect(GeneratedUiSandboxPolicy.csp, contains("object-src 'none'"));
      expect(GeneratedUiSandboxPolicy.cspBlocksBackendAccess, isTrue);
    });

    test('extracts the first HTML code fence as a preview candidate', () {
      final candidate = GeneratedUiSandboxPolicy.extractFirstPreviewCandidate(
        'Here is a widget:\n```html\n<div>Hello</div>\n```',
      );

      expect(candidate, isNotNull);
      expect(candidate!.isPreviewAllowed, isTrue);
      expect(candidate.html, '<div>Hello</div>');
    });

    test('rejects code that attempts network or credential access', () {
      final candidate = GeneratedUiSandboxPolicy.evaluate('''
<button onclick="fetch('/rest/v1/user_profiles')">load</button>
<script>console.log(localStorage.getItem('supabase.auth.token'))</script>
''');

      expect(candidate.isPreviewAllowed, isFalse);
      expect(candidate.rejectionReasons, contains('network API call'));
      expect(
        candidate.rejectionReasons,
        contains('browser credential or storage access'),
      );
      expect(
        candidate.rejectionReasons,
        contains('Supabase/Auth/secret keyword'),
      );
    });

    test('rejects parent bridges and nested browsing contexts', () {
      final candidate = GeneratedUiSandboxPolicy.evaluate('''
<iframe src="https://example.com"></iframe>
<script>window.parent.postMessage({ok: true}, '*')</script>
''');

      expect(candidate.isPreviewAllowed, isFalse);
      expect(candidate.rejectionReasons, contains('nested iframe'));
      expect(candidate.rejectionReasons, contains('parent-window bridge'));
    });

    test('srcdoc wraps generated HTML with the sandbox CSP', () {
      final srcDoc = GeneratedUiSandboxPolicy.buildSrcDoc(
        htmlFragment: '<button>Run</button>',
        title: 'Preview',
      );

      expect(srcDoc, contains('Content-Security-Policy'));
      expect(srcDoc, contains("connect-src 'none'"));
      expect(srcDoc, contains('data-vibe-sandbox="leaf-preview"'));
      expect(srcDoc, contains('<button>Run</button>'));
    });
  });
}
