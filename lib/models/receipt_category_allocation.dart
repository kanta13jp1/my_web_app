/// Uses only explicit, reconciled receipt components; never guesses tax or change.
class ReceiptCategoryAllocation {
  static Map<String, double>? parse(String description, double total) {
    final marker = description.lastIndexOf('内訳:');
    if (marker < 0 || !total.isFinite || total <= 0) return null;
    final section = description.substring(marker + 3).split('。').first;
    final matches = RegExp(r'(食品|飲酒|喫煙)([0-9,]+)円').allMatches(section).toList();
    if (matches.length < 2) return null;
    final values = <String, double>{};
    for (final match in matches) {
      final key = match.group(1)!;
      final amount = double.tryParse(match.group(2)!.replaceAll(',', ''));
      if (values.containsKey(key) || amount == null || amount <= 0) return null;
      values[key] = amount;
    }
    if (values.values.fold<double>(0, (a, b) => a + b) != total) return null;
    return values;
  }
}
