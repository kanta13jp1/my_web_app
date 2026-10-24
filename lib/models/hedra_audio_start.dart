const int hedraAudioStartMinMs = -30000;
const int hedraAudioStartMaxMs = 30000;

int? parseHedraAudioStartMs(String input) {
  final value = int.tryParse(input.trim());
  if (value == null ||
      value < hedraAudioStartMinMs ||
      value > hedraAudioStartMaxMs) {
    return null;
  }
  return value;
}

String? validateHedraAudioStartMs(String? input) {
  final value = input?.trim() ?? '';
  if (value.isEmpty || int.tryParse(value) == null) {
    return 'ミリ秒を整数で入力してください';
  }
  if (parseHedraAudioStartMs(value) == null) {
    return '$hedraAudioStartMinMs〜$hedraAudioStartMaxMs msの範囲で入力してください';
  }
  return null;
}
