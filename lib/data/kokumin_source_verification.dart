/// Source-specific review dates, separate from source/publication dates.
/// These fixed keys do not inherit page fetch times or the day a card is opened.
/// A new source URL, date or PDF digest requires a separate review entry.
String? kokuminSourceVerifiedOn({
  required String sourceUrl,
  required String sourceDate,
  String sourceDocumentSha256 = '',
}) {
  // Public PDF review on 2026-11-18 JST; document dated 2026-11-18.
  if (sourceUrl == 'https://new-kokumin.jp/local-election-list' &&
      sourceDate == '2026-11-18' &&
      sourceDocumentSha256 ==
          'cf5caad9b1faa9df6bb3c1b2aa6ed25799c0a3818c1c8b06831229a8dc6bad7a') {
    return '2026-11-18';
  }
  // Public PDF reviews on 2026-11-12 JST; documents dated 2026-11-11.
  // The newer digest was fetched and matched against main independently.
  const reviewedPdfDigests = <String>{
    '8132d6c24659aa340c846d12b97114e092e32d5ecde295f2236b9b44f93ead25',
    '25e432b06b4f1ba860db772dae5de4d647a82a20a7eaae4050460526d00f3af5',
  };
  if (sourceUrl == 'https://new-kokumin.jp/local-election-list' &&
      sourceDate == '2026-11-11' &&
      reviewedPdfDigests.contains(sourceDocumentSha256)) {
    return '2026-11-12';
  }
  // Representative X thread read directly in Chrome on 2026-11-22 JST:
  // - status/2124504534995341736 (23:05 JST): 空白県解消・47都道府県達成 (鳥取市議選)
  // - status/2124507662427856990 (23:17 JST): 現職 421名・新人、元職 292名 / 700名目標
  const verifiedPosts20261122 = <String>{
    'https://x.com/tamakiyuichiro/status/2124507662427856990',
    'https://x.com/tamakiyuichiro/status/2124504534995341736',
  };
  if (verifiedPosts20261122.contains(sourceUrl) &&
      sourceDate == '2026-11-22' &&
      sourceDocumentSha256.isEmpty) {
    return '2026-11-22';
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
