import 'dart:typed_data';

enum PalmImageSource { camera, gallery }

class PalmReadingImage {
  const PalmReadingImage({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  final String fileName;
  final String mimeType;
  final Uint8List bytes;
}
