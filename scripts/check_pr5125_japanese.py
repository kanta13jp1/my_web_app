"""Bounded copy regression gate for the synthetic PR 5125 preview only."""
import json
from pathlib import Path

PATHS = [
    'lib/pages/import_page.dart',
    'lib/pages/note_editor_page.dart',
    'lib/pages/note_list_page.dart',
    'lib/pages/note_collections_page.dart',
    'lib/pages/note_navigation_page.dart',
    'lib/pages/space_sharing_page.dart',
    'lib/widgets/evernote_cloud_migration_controls.dart',
    'lib/widgets/note_editor/ai_assistant_menu.dart',
    'lib/services/import_service.dart',
    'lib/services/note_collection_service.dart',
    'lib/services/evernote_migration_commit_service.dart',
]
translations = json.loads(Path('config/pr5125-ja-copy.json').read_text(encoding='utf-8'))
assert len(translations) >= 200
failures = []
for name in PATHS:
    source = Path(name).read_text(encoding='utf-8')
    for original in translations:
        if "'" + original + "'" in source:
            failures.append(f'{name}: untranslated copy {original}')
assert not failures, '\n'.join(failures)
print(f'PASS: Japanese copy regression guard ({len(translations)} entries, {len(PATHS)} source files)')
