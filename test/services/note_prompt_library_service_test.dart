import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/note_prompt_library_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saves, sorts, and deletes prompt templates', () async {
    const service = NotePromptLibraryService();
    final prefs = await SharedPreferences.getInstance();

    final first = NotePromptTemplate(
      id: 'board-brief',
      title: 'Board Brief',
      prompt: 'Summarize {{note_content}}',
      updatedAt: DateTime.parse('2026-03-20T09:00:00.000'),
    );
    final second = NotePromptTemplate(
      id: 'follow-up',
      title: 'Follow-up',
      prompt: 'Draft a follow-up for {{note_title}}',
      updatedAt: DateTime.parse('2026-03-20T10:00:00.000'),
    );

    await service.saveTemplate(first, prefs: prefs);
    final saved = await service.saveTemplate(second, prefs: prefs);

    expect(saved.map((template) => template.id).toList(), [
      'follow-up',
      'board-brief',
    ]);

    final loaded = await service.loadTemplates(prefs: prefs);
    expect(loaded.first.prompt, 'Draft a follow-up for {{note_title}}');

    final remaining = await service.deleteTemplate('follow-up', prefs: prefs);
    expect(remaining.map((template) => template.id).toList(), ['board-brief']);
  });
}
