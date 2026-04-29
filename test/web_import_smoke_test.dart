@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/main.dart' as app;
import 'package:my_web_app/pages/ai_assistant_chat_page.dart';
import 'package:my_web_app/pages/election_victory_page.dart';
import 'package:my_web_app/pages/gemini_university_v2_page.dart';
import 'package:my_web_app/pages/guitar_recording_studio_page.dart';
import 'package:my_web_app/pages/home_page.dart';
import 'package:my_web_app/pages/work_menu_page.dart';

void main() {
  test('web-only app imports compile on Chrome', () {
    expect(app.MyApp, isNotNull);
    expect(HomePage, isNotNull);
    expect(WorkMenuPage, isNotNull);
    expect(AiUniversityPage, isNotNull);
    expect(ElectionVictoryPage, isNotNull);
    expect(GuitarRecordingStudioPage, isNotNull);
    expect(AiAssistantChatPage, isNotNull);
  });
}
