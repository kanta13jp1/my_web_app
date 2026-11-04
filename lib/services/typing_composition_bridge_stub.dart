/// Native editors already supply composition ranges in TextEditingValue.
class TypingCompositionBridge {
  TypingCompositionBridge({
    required bool Function() ownsInput,
    required void Function() onCommitted,
  });

  bool get isComposing => false;
  String? consume(String value) => null;
  String? takePending() => null;
  void reset() {}
  void dispose() {}
}
