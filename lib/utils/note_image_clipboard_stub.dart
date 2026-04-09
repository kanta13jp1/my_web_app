import 'dart:typed_data';

typedef NoteImagePasteHandler = Future<void> Function(
  Uint8List bytes,
  String fileName,
  String mimeType,
);

abstract class NoteImagePasteRegistration {
  void dispose();
}

NoteImagePasteRegistration registerNoteImagePasteListener({
  required bool Function() isEnabled,
  required NoteImagePasteHandler onImagePasted,
}) {
  return const _NoopNoteImagePasteRegistration();
}

class _NoopNoteImagePasteRegistration implements NoteImagePasteRegistration {
  const _NoopNoteImagePasteRegistration();

  @override
  void dispose() {}
}
