/// Untrusted experiment labels, never authentication, price or purchase rights.
/// Invalid labels stay unavailable rather than becoming a different post/direct.
class ShopAttribution {
  const ShopAttribution._(this.source, this.campaign, this.contentId)
      : isValid = true;

  const ShopAttribution.unavailable()
      : source = '',
        campaign = '',
        contentId = '',
        isValid = false;

  final String source;
  final String campaign;
  final String contentId;
  final bool isValid;

  static const unavailableQueryKey = 'shop_attribution';
  static final _tagPattern = RegExp(r'^[a-z0-9_.-]{0,64}$');

  factory ShopAttribution.parse({
    String? source,
    String? campaign,
    String? contentId,
  }) {
    final normalizedSource = (source ?? '').trim().toLowerCase();
    final normalizedCampaign = (campaign ?? '').trim().toLowerCase();
    final normalizedContent = (contentId ?? '').trim().toLowerCase();
    if (![normalizedSource, normalizedCampaign, normalizedContent]
        .every(_tagPattern.hasMatch)) {
      return const ShopAttribution.unavailable();
    }
    return ShopAttribution._(
      normalizedSource.isEmpty ? 'direct' : normalizedSource,
      normalizedCampaign,
      normalizedContent,
    );
  }

  factory ShopAttribution.fromUri(Uri uri) {
    final query = uri.queryParametersAll;
    // Repeated labels are ambiguous; do not arbitrarily choose first or last.
    const keys = ['utm_source', 'utm_campaign', 'utm_content'];
    if (query.containsKey(unavailableQueryKey) ||
        keys.any((key) => (query[key]?.length ?? 0) > 1)) {
      return const ShopAttribution.unavailable();
    }
    return ShopAttribution.parse(
      source: uri.queryParameters['utm_source'],
      campaign: uri.queryParameters['utm_campaign'],
      contentId: uri.queryParameters['utm_content'],
    );
  }

  Map<String, Object> toRequest() => isValid
      ? {'source': source, 'campaign': campaign, 'content_id': contentId}
      : {'attribution_valid': false};

  Map<String, String> toQuery() => isValid
      ? {
          'utm_source': source,
          if (campaign.isNotEmpty) 'utm_campaign': campaign,
          if (contentId.isNotEmpty) 'utm_content': contentId,
        }
      : {unavailableQueryKey: 'unavailable'};
}
