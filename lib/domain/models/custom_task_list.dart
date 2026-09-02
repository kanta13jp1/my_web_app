class CustomTaskItem {
  final String id;
  final String title;
  final bool isCompleted;

  const CustomTaskItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  CustomTaskItem copyWith({String? title, bool? isCompleted}) {
    return CustomTaskItem(
      id: id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  factory CustomTaskItem.fromJson(Map<String, dynamic> json) {
    return CustomTaskItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      isCompleted: json['is_completed'] == true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'is_completed': isCompleted,
      };
}

class CustomTaskListSnapshot {
  final String goal;
  final String situation;
  final List<CustomTaskItem> items;
  final String source;
  final DateTime generatedAt;

  const CustomTaskListSnapshot({
    required this.goal,
    required this.situation,
    required this.items,
    required this.source,
    required this.generatedAt,
  });

  CustomTaskListSnapshot copyWith({List<CustomTaskItem>? items}) {
    return CustomTaskListSnapshot(
      goal: goal,
      situation: situation,
      items: items ?? this.items,
      source: source,
      generatedAt: generatedAt,
    );
  }

  factory CustomTaskListSnapshot.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return CustomTaskListSnapshot(
      goal: json['goal']?.toString() ?? '',
      situation: json['situation']?.toString() ?? '',
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map(
                (item) =>
                    CustomTaskItem.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
              .toList(growable: false)
          : const <CustomTaskItem>[],
      source: json['source']?.toString() ?? '',
      generatedAt: DateTime.tryParse(json['generated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'goal': goal,
        'situation': situation,
        'items': items.map((item) => item.toJson()).toList(growable: false),
        'source': source,
        'generated_at': generatedAt.toIso8601String(),
      };
}
