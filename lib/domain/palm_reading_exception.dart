class PalmReadingException implements Exception {
  const PalmReadingException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
