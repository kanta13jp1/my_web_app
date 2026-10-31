import 'dart:convert';

import '../models/asset_calendar_reflection.dart';

List<AssetCalendarReflection> parseAssetCalendarReflectionImport(String input) {
  final dynamic data;
  try {
    data = jsonDecode(input);
  } on FormatException catch (error) {
    final position = error.offset;
    throw FormatException(
      position == null
          ? 'JSONの構文を確認してください。'
          : 'JSONの構文を確認してください（位置: ${position + 1}）。',
    );
  }
  if (data is! List || data.isEmpty || data.length > 200) {
    throw const FormatException('1〜200件のJSON配列を入力してください。');
  }
  final parsed = <AssetCalendarReflection>[];
  final keys = <String>{};
  for (var index = 0; index < data.length; index++) {
    final row = data[index];
    if (row is! Map<String, dynamic>) {
      throw FormatException('${index + 1}件目: JSONオブジェクトが必要です。');
    }
    final AssetCalendarReflection event;
    try {
      event = AssetCalendarReflection.fromJson(row);
    } on FormatException catch (error) {
      throw FormatException('${index + 1}件目: ${error.message}');
    }
    if (!keys.add(event.sourceKey)) {
      throw FormatException('${index + 1}件目: 出典キーが重複しています。');
    }
    parsed.add(event);
  }
  return parsed;
}
