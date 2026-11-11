/// Fixed facts from the representative's 2026-11-09 announcement.
/// This snapshot is independent of candidate-list, roster and planning totals.
class KokuminRepresentativeAnnouncement {
  const KokuminRepresentativeAnnouncement({
    required this.publishedOn,
    required this.incumbentCount,
    required this.newcomerNominationCount,
    required this.nationwideMemberTarget,
    required this.originalPostUrl,
    required this.officialSiteUrl,
  });

  final String publishedOn;
  final int incumbentCount;
  final int newcomerNominationCount;
  final int nationwideMemberTarget;
  final String originalPostUrl;
  final String officialSiteUrl;
}

const kokuminRepresentativeAnnouncement20261109 =
    KokuminRepresentativeAnnouncement(
  publishedOn: '2026-11-09',
  incumbentCount: 420,
  newcomerNominationCount: 243,
  nationwideMemberTarget: 700,
  originalPostUrl: 'https://x.com/tamakiyuichiro/status/2119639251365294529',
  officialSiteUrl: 'https://tamakinet.jp/',
);
