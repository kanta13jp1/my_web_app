/// Public data only: no account identifiers or purchase details.
class ShopReview {
  const ShopReview({
    required this.id,
    required this.rating,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.postedVersion = '',
    this.isVisible = true,
  });

  factory ShopReview.fromRow(Map<String, dynamic> row) => ShopReview(
        id: row['id'] as String,
        rating: (row['rating'] as num).toInt(),
        body: row['body'] as String? ?? '',
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
        postedVersion: row['posted_version'] as String? ?? '',
        isVisible: row['is_visible'] as bool? ?? true,
      );

  final String id;
  final int rating;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String postedVersion;
  final bool isVisible;
}

class ShopReviewPage {
  const ShopReviewPage({
    required this.items,
    required this.count,
    required this.average,
    required this.hasMore,
  });

  factory ShopReviewPage.fromRow(Map<String, dynamic> row) {
    final items = (row['items'] as List)
        .map(
          (item) => ShopReview.fromRow(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
    final count = (row['count'] as num).toInt();
    final average = (row['average'] as num?)?.toDouble();
    if (count < 0 ||
        (count > 0 && (average == null || average < 1 || average > 5)) ||
        (count == 0 && average != null)) {
      throw const FormatException('Invalid review summary');
    }
    return ShopReviewPage(
      items: List.unmodifiable(items.take(10)),
      count: count,
      average: average,
      hasMore: items.length > 10,
    );
  }

  final List<ShopReview> items;
  final int count;
  final double? average;
  final bool hasMore;
}

class ShopReviewContext {
  const ShopReviewContext({this.review, this.canReview = false});
  final ShopReview? review;
  final bool canReview;
}

class ShopProductRelease {
  const ShopProductRelease({
    required this.id,
    required this.version,
    required this.title,
    required this.notes,
    this.sha256,
    this.publishedAt,
  });

  factory ShopProductRelease.fromRow(Map<String, dynamic> row) =>
      ShopProductRelease(
        id: row['id'] as String,
        version: row['version'] as String,
        title: row['title_ja'] as String,
        notes: row['notes_ja'] as String,
        sha256: row['sha256'] as String?,
        publishedAt: DateTime.tryParse(row['published_at'] as String? ?? ''),
      );

  final String id;
  final String version;
  final String title;
  final String notes;
  final String? sha256;
  final DateTime? publishedAt;
}
