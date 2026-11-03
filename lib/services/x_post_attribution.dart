/// Stable attribution attached to posts created by the viral ad generator.
///
/// Keeping the media axis and UTM content aligned lets `x_post_log`, metric
/// snapshots, and `x.performance_context` compare video/image/text posts
/// without inferring the variant from mutable caption text.
Map<String, String> buildViralAdXPostAttribution({
  String? videoUrl,
  String? imageUrl,
}) {
  final hasVideo = videoUrl?.trim().isNotEmpty == true;
  final hasImage = imageUrl?.trim().isNotEmpty == true;
  final mediaType = hasVideo ? 'video' : (hasImage ? 'image' : 'text');
  final variant = 'ai_$mediaType';

  return <String, String>{
    'variant': variant,
    'utmContent': variant,
    'mediaType': mediaType,
  };
}
