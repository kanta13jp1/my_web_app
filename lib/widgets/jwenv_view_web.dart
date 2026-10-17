import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class JwenvView extends StatefulWidget {
  const JwenvView({super.key});

  @override
  State<JwenvView> createState() => _JwenvViewState();
}

class _JwenvViewState extends State<JwenvView> {
  late final web.HTMLIFrameElement _frame;
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'jwenv-lab-${identityHashCode(this)}';
    _frame = web.HTMLIFrameElement()
      ..src = '/labs/jwenv/index.html'
      ..title = 'Jwenv WebGPU Lab'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = '0';
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (_) => _frame);
  }

  @override
  void dispose() {
    _frame.src = 'about:blank';
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewId);
}
