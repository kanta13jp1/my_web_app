import 'package:flutter/material.dart';
import 'package:my_web_app/ui/features/beatles_guitar_tabs/views/widgets/chord_lyrics_studio_panel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: ChordLyricsStudioPanel(),
      ),
    ),
  );
}
