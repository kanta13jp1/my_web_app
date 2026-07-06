import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/generated_ui_sandbox_policy.dart';
import '../utils/platform_view.dart' as platform_view;

class GeneratedUiSandboxPreview extends StatefulWidget {
  const GeneratedUiSandboxPreview({
    super.key,
    required this.htmlFragment,
    this.title = 'AI generated UI preview',
    this.height = 260,
  });

  final String htmlFragment;
  final String title;
  final double height;

  @override
  State<GeneratedUiSandboxPreview> createState() =>
      _GeneratedUiSandboxPreviewState();
}

class _GeneratedUiSandboxPreviewState extends State<GeneratedUiSandboxPreview> {
  static int _nextViewId = 0;

  late String _viewType;

  @override
  void initState() {
    super.initState();
    _registerView();
  }

  @override
  void didUpdateWidget(covariant GeneratedUiSandboxPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.htmlFragment != widget.htmlFragment ||
        oldWidget.title != widget.title) {
      _registerView();
    }
  }

  void _registerView() {
    _viewType = 'generated-ui-sandbox-${_nextViewId++}';
    platform_view.registerSandboxedSrcDocIframeViewFactory(
      _viewType,
      GeneratedUiSandboxPolicy.buildSrcDoc(
        htmlFragment: widget.htmlFragment,
        title: widget.title,
      ),
      sandbox: GeneratedUiSandboxPolicy.iframeSandbox,
      csp: GeneratedUiSandboxPolicy.csp,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: 180, maxHeight: widget.height),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF111827),
            child: const Row(
              children: [
                Icon(
                  Icons.security_outlined,
                  size: 16,
                  color: Color(0xFF22C55E),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sandbox preview',
                    style: TextStyle(
                      color: Color(0xFFE5E7EB),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: kIsWeb
                ? HtmlElementView(viewType: _viewType)
                : const Center(
                    child: Text(
                      'Sandbox preview is available on Flutter Web.',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
