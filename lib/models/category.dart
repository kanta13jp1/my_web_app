class Category {
  final String id;
  final String userId;
  final String name;
  final String color;
  final String icon;
  final DateTime createdAt;

  Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.color,
    required this.icon,
    required this.createdAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'].toString(),
      userId: json['user_id'],
      name: json['name'] ?? '',
      color: json['color'] ?? '#2196F3',
      icon: json['icon'] ?? '📁',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'color': color,
      'icon': icon,
    };
  }
}