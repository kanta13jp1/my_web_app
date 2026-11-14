/// Header total read from the party's local-member directory.
/// verifiedOn is an observation date, not the directory's publication date.
/// This does not replace the older person/prefecture snapshot or its history.
class KokuminMemberDirectoryObservation {
  const KokuminMemberDirectoryObservation({
    required this.listedMemberCount,
    required this.verifiedOn,
    required this.sourceUrl,
  });

  final int listedMemberCount;
  final String verifiedOn;
  final String sourceUrl;
}

const kokuminMemberDirectoryObservation20261114 =
    KokuminMemberDirectoryObservation(
  listedMemberCount: 416,
  verifiedOn: '2026-11-14',
  sourceUrl: 'https://new-kokumin.jp/member',
);
