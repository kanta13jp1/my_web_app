import 'package:flutter/material.dart';
import 'package:my_web_app/widgets/slide_number_check_card.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: SlideNumberCheckCard()),
      ),
    ),
  );
}
