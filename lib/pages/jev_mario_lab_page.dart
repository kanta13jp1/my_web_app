import 'package:flutter/material.dart';

import '../widgets/jev_mario_view_stub.dart'
    if (dart.library.js_interop) '../widgets/jev_mario_view_web.dart';

class JevMarioLabPage extends StatelessWidget {
  const JevMarioLabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jev Mario Lab')),
      body: const SafeArea(child: JevMarioView()),
    );
  }
}
