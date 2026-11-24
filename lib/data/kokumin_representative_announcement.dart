/// Fixed facts from the representative's announcements.
/// These snapshots are independent of candidate-list, roster and planning totals.
class KokuminRepresentativeAnnouncement {
  const KokuminRepresentativeAnnouncement({
    required this.publishedOn,
    required this.incumbentCount,
    required this.newcomerNominationCount,
    this.nominationMetricLabel = '新人擁立数',
    required this.nationwideMemberTarget,
    required this.originalPostUrl,
    required this.officialSiteUrl,
    this.milestoneSummary,
    this.milestonePostUrl,
  });

  final String publishedOn;
  final int incumbentCount;
  final int newcomerNominationCount;
  final String nominationMetricLabel;
  final int nationwideMemberTarget;
  final String originalPostUrl;
  final String officialSiteUrl;
  final String? milestoneSummary;
  final String? milestonePostUrl;
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

const kokuminRepresentativeAnnouncement20261122 =
    KokuminRepresentativeAnnouncement(
  publishedOn: '2026-11-22',
  incumbentCount: 421,
  newcomerNominationCount: 292,
  nominationMetricLabel: '新人・元職',
  nationwideMemberTarget: 700,
  originalPostUrl: 'https://x.com/tamakiyuichiro/status/2124507662427856990',
  officialSiteUrl: 'https://tamakinet.jp/',
  milestoneSummary: '空白県解消・47都道府県達成（鳥取市議選 村尾まさひこ候補 当確）',
  milestonePostUrl: 'https://x.com/tamakiyuichiro/status/2124504534995341736',
);

const kokuminRepresentativeAnnouncementLatest =
    kokuminRepresentativeAnnouncement20261122;
