import 'package:flutter/material.dart';

import '../widgets/jwenv_view_stub.dart'
    if (dart.library.js_interop) '../widgets/jwenv_view_web.dart';

class JwenvLabPage extends StatelessWidget {
  const JwenvLabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jwenv WebGPU Lab')),
      body: const SafeArea(child: JwenvView()),
    );
  }
}
