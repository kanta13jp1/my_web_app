/// Parses yen amounts without changing the user's in-progress text.
class AssetFlowAmountParser {
  static int? parse(String input) {
    final normalized = input
        .replaceAllMapped(RegExp(r'[０-９]'), (match) {
          return String.fromCharCode(match[0]!.codeUnitAt(0) - 0xfee0);
        })
        .replaceAll('，', ',')
        .trim();
    if (!RegExp(r'^(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+)$').hasMatch(normalized)) {
      return null;
    }
    return int.tryParse(normalized.replaceAll(',', ''));
  }
}
