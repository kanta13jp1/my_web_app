/// Source-specific review dates, separate from source/publication dates.
/// These fixed keys do not inherit page fetch times or the day a card is opened.
/// A new source URL, date or PDF digest requires a separate review entry.
String? kokuminSourceVerifiedOn({
  required String sourceUrl,
  required String sourceDate,
  String sourceDocumentSha256 = '',
}) {
  // Public PDF review on 2026-11-12 JST; original document dated 2026-11-11.
  if (sourceUrl == 'https://new-kokumin.jp/local-election-list' &&
      sourceDate == '2026-11-11' &&
      sourceDocumentSha256 ==
          '8132d6c24659aa340c846d12b97114e092e32d5ecde295f2236b9b44f93ead25') {
    return '2026-11-12';
  }
  // Original post identity and facts read in the official-site embedded feed.
  // Source review date: 2026-11-12 JST; no direct X-post read is claimed.
  if (sourceUrl == 'https://x.com/tamakiyuichiro/status/2119639251365294529' &&
      sourceDate == '2026-11-09' &&
      sourceDocumentSha256.isEmpty) {
    return '2026-11-12';
  }
  return null;
}

String kokuminSourceVerificationLabel({
  required String sourceUrl,
  required String sourceDate,
  String sourceDocumentSha256 = '',
}) {
  final verifiedOn = kokuminSourceVerifiedOn(
    sourceUrl: sourceUrl,
    sourceDate: sourceDate,
    sourceDocumentSha256: sourceDocumentSha256,
  );
  // Only fixed registry dates reach this formatting; unknown inputs stay unknown.
  final dateLabel = verifiedOn?.replaceAll('-', '/') ?? '未記録';
  return '出典確認日: $dateLabel';
}
