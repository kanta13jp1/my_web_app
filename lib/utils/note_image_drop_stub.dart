import 'package:flutter/widgets.dart';

/// No-op wrapper on non-web platforms.
class NoteImageDropZone extends StatelessWidget {
  final Widget child;
  final Future<void> Function(List<int> bytes, String fileName, String mimeType)
      onImageDropped;

  const NoteImageDropZone({
    super.key,
    required this.child,
    required this.onImageDropped,
  });

  @override
  Widget build(BuildContext context) => child;
}
