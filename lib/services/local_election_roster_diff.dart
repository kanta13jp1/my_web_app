import 'package:intl/intl.dart';

import '../models/local_election_reality.dart';
import '../models/public_memo.dart';

const List<String> localElectionAllPrefectures = <String>[
  '北海道',
  '青森県',
  '岩手県',
  '宮城県',
  '秋田県',
  '山形県',
  '福島県',
  '茨城県',
  '栃木県',
  '群馬県',
  '埼玉県',
  '千葉県',
  '東京都',
  '神奈川県',
  '新潟県',
  '富山県',
  '石川県',
  '福井県',
  '山梨県',
  '長野県',
  '岐阜県',
  '静岡県',
  '愛知県',
  '三重県',
  '滋賀県',
  '京都府',
  '大阪府',
  '兵庫県',
  '奈良県',
  '和歌山県',
  '鳥取県',
  '島根県',
  '岡山県',
  '広島県',
  '山口県',
  '徳島県',
  '香川県',
  '愛媛県',
  '高知県',
  '福岡県',
  '佐賀県',
  '長崎県',
  '熊本県',
  '大分県',
  '宮崎県',
  '鹿児島県',
  '沖縄県',
];

class LocalElectionRosterEntry {
  final String prefecture;
  final String detailUrl;
  final String assemblyLabel;
  final String constituency;
  final String municipality;
  final String name;
  final String kana;
  final String electionCountLabel;

  const LocalElectionRosterEntry({
    required this.prefecture,
    this.detailUrl = '',
    this.assemblyLabel = '',
    this.constituency = '',
    this.municipality = '',
    required this.name,
    this.kana = '',
    this.electionCountLabel = '',
  });

  factory LocalElectionRosterEntry.fromProfile(
    LocalElectionLegislatorProfile profile,
  ) {
    return LocalElectionRosterEntry(
      prefecture: profile.prefecture.trim(),
      detailUrl: profile.detailUrl.trim(),
      assemblyLabel: profile.assemblyLabel.trim(),
      constituency: profile.constituency.trim(),
      municipality: profile.municipality.trim(),
      name: profile.name.trim(),
      kana: profile.kana.trim(),
      electionCountLabel: profile.electionCountLabel.trim(),
    );
  }

  factory LocalElectionRosterEntry.fromJson(Map<String, dynamic> json) {
    return LocalElectionRosterEntry(
      prefecture: (json['prefecture'] as String? ?? '').trim(),
      detailUrl: (json['detailUrl'] as String? ?? '').trim(),
      assemblyLabel: (json['assemblyLabel'] as String? ?? '').trim(),
      constituency: (json['constituency'] as String? ?? '').trim(),
      municipality: (json['municipality'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      kana: (json['kana'] as String? ?? '').trim(),
      electionCountLabel: (json['electionCountLabel'] as String? ?? '').trim(),
    );
  }

  String get effectiveLocation {
    final c = constituency.trim();
    if (c.isNotEmpty) {
      return c;
    }
    final m = municipality.trim();
    if (m.isNotEmpty && m != prefecture.trim()) {
      return m;
    }
    return '';
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'prefecture': prefecture,
      'detailUrl': detailUrl,
      'assemblyLabel': assemblyLabel,
      'constituency': constituency,
      'municipality': municipality,
      'name': name,
      'kana': kana,
      'electionCountLabel': electionCountLabel,
    };
  }
}

class LocalElectionRosterChange {
  final LocalElectionRosterEntry before;
  final LocalElectionRosterEntry after;
  final bool nameChanged;
  final bool locationChanged;
  final bool assemblyChanged;
  final bool electionCountChanged;

  const LocalElectionRosterChange({
    required this.before,
    required this.after,
    required this.nameChanged,
    required this.locationChanged,
    required this.assemblyChanged,
    required this.electionCountChanged,
  });
}

class LocalElectionRosterDiff {
  final String previousDateLabel;
  final DateTime currentDate;
  final int previousMemberCount;
  final int currentMemberCount;
  final int netDelta;
  final int previousActivePrefectureCount;
  final int currentActivePrefectureCount;
  final List<String> newlyCoveredPrefectures;
  final List<String> newlyMissingPrefectures;
  final int currentMissingPrefectureCount;
  final List<LocalElectionRosterEntry> added;
  final List<LocalElectionRosterEntry> removed;
  final List<LocalElectionRosterChange> nameChanges;
  final List<LocalElectionRosterChange> locationChanges;
  final List<LocalElectionRosterChange> attributeChanges;

  const LocalElectionRosterDiff({
    required this.previousDateLabel,
    required this.currentDate,
    required this.previousMemberCount,
    required this.currentMemberCount,
    required this.netDelta,
    required this.previousActivePrefectureCount,
    required this.currentActivePrefectureCount,
    required this.newlyCoveredPrefectures,
    required this.newlyMissingPrefectures,
    required this.currentMissingPrefectureCount,
    required this.added,
    required this.removed,
    required this.nameChanges,
    required this.locationChanges,
    required this.attributeChanges,
  });

  bool get hasAnyChange =>
      added.isNotEmpty ||
      removed.isNotEmpty ||
      nameChanges.isNotEmpty ||
      locationChanges.isNotEmpty ||
      attributeChanges.isNotEmpty;

  bool get hasNotationChanges =>
      nameChanges.isNotEmpty ||
      locationChanges.isNotEmpty ||
      attributeChanges.isNotEmpty;

  Map<String, dynamic> toSummaryJson() {
    return <String, dynamic>{
      'previousDateLabel': previousDateLabel,
      'previousMemberCount': previousMemberCount,
      'currentMemberCount': currentMemberCount,
      'netDelta': netDelta,
      'addedCount': added.length,
      'removedCount': removed.length,
      'nameChangeCount': nameChanges.length,
      'locationChangeCount': locationChanges.length,
      'attributeChangeCount': attributeChanges.length,
      'newlyCoveredPrefectures': newlyCoveredPrefectures,
      'newlyMissingPrefectures': newlyMissingPrefectures,
      'addedNames': added.map((entry) => entry.name).toList(),
      'removedNames': removed.map((entry) => entry.name).toList(),
    };
  }
}

class _ScoredSnapshotMemo {
  final PublicMemo memo;
  final String snapshotDate;

  const _ScoredSnapshotMemo({
    required this.memo,
    required this.snapshotDate,
  });
}

String resolvePublicMemoSnapshotDate(PublicMemo memo) {
  final metaDate = (memo.metadata['snapshotDate'] as String? ?? '').trim();
  if (RegExp(r'^\d{4}/\d{2}/\d{2}$').hasMatch(metaDate)) {
    return metaDate;
  }
  final titleMatch = RegExp(r'(\d{4}/\d{2}/\d{2})').firstMatch(memo.title);
  if (titleMatch != null) {
    return titleMatch.group(1) ?? '';
  }
  return DateFormat('yyyy/MM/dd').format(memo.publishedAt.toLocal());
}

PublicMemo? selectPreviousSnapshotMemo({
  required List<PublicMemo> candidates,
  required String metadataType,
  required String excludeSourceKey,
  required String beforeSnapshotDate,
}) {
  final normalizedExcludeKey = excludeSourceKey.trim();
  final matching = <_ScoredSnapshotMemo>[];
  for (final memo in candidates) {
    final type = (memo.metadata['type'] as String? ?? '').trim();
    if (type != metadataType) {
      continue;
    }
    final sourceKey = (memo.metadata['source_key'] as String? ?? '').trim();
    if (normalizedExcludeKey.isNotEmpty && sourceKey == normalizedExcludeKey) {
      continue;
    }
    final snapshotDate = resolvePublicMemoSnapshotDate(memo);
    if (snapshotDate.isEmpty ||
        snapshotDate.compareTo(beforeSnapshotDate) >= 0) {
      continue;
    }
    matching.add(
      _ScoredSnapshotMemo(memo: memo, snapshotDate: snapshotDate),
    );
  }
  if (matching.isEmpty) {
    return null;
  }
  matching.sort((left, right) {
    final dateCompare = right.snapshotDate.compareTo(left.snapshotDate);
    if (dateCompare != 0) {
      return dateCompare;
    }
    final publishedCompare =
        right.memo.publishedAt.compareTo(left.memo.publishedAt);
    if (publishedCompare != 0) {
      return publishedCompare;
    }
    return right.memo.updatedAt.compareTo(left.memo.updatedAt);
  });
  return matching.first.memo;
}

List<LocalElectionRosterEntry> extractRosterEntriesFromPublicMemo(
  PublicMemo memo,
) {
  final rawSnapshot = memo.metadata['rosterSnapshot'];
  if (rawSnapshot is List && rawSnapshot.isNotEmpty) {
    final parsed = <LocalElectionRosterEntry>[];
    for (final item in rawSnapshot) {
      if (item is Map<String, dynamic>) {
        final entry = LocalElectionRosterEntry.fromJson(item);
        if (entry.name.isNotEmpty) {
          parsed.add(entry);
        }
      } else if (item is Map) {
        final entry = LocalElectionRosterEntry.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (entry.name.isNotEmpty) {
          parsed.add(entry);
        }
      }
    }
    if (parsed.isNotEmpty) {
      return parsed;
    }
  }

  final content = memo.content;
  if (content == null || content.trim().isEmpty) {
    return const <LocalElectionRosterEntry>[];
  }

  final lines = content.replaceAll('\r\n', '\n').split('\n');
  final startIdx = lines.indexWhere((line) => line.trim() == '現職地方議員名簿');
  if (startIdx < 0) {
    return const <LocalElectionRosterEntry>[];
  }

  final headingPattern = RegExp(
    r'^[◽◻□▫▪■\u25FD\u25FE]\uFE0F?\s*国民民主党(.+?)現職地方議員$',
  );
  final termPattern = RegExp(r'^(?:当選\d+回|\d+期|\d+回)$');

  final entries = <LocalElectionRosterEntry>[];
  var currentPrefecture = '';
  for (var i = startIdx + 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) {
      continue;
    }
    if (line == '公式ソース' || line == '---') {
      break;
    }
    final headingMatch = headingPattern.firstMatch(line);
    if (headingMatch != null) {
      currentPrefecture = (headingMatch.group(1) ?? '').trim();
      continue;
    }
    if (currentPrefecture.isEmpty ||
        line.startsWith('※') ||
        line.startsWith('- ') ||
        line.startsWith('http')) {
      continue;
    }

    var parts = line
        .split(' / ')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (parts.length < 2) {
      parts = line
          .split('/')
          .map((segment) => segment.trim())
          .where((segment) => segment.isNotEmpty)
          .toList();
    }
    if (parts.length < 2) {
      continue;
    }

    String assemblyLabel;
    String constituency;
    String name;
    String electionCountLabel;
    if (parts.length >= 4) {
      assemblyLabel = parts[0];
      constituency = parts[1];
      name = parts[2];
      electionCountLabel = parts[3];
    } else if (parts.length == 3) {
      if (termPattern.hasMatch(parts[2])) {
        assemblyLabel = parts[0];
        constituency = '';
        name = parts[1];
        electionCountLabel = parts[2];
      } else {
        assemblyLabel = parts[0];
        constituency = parts[1];
        name = parts[2];
        electionCountLabel = '';
      }
    } else {
      assemblyLabel = parts[0];
      constituency = '';
      name = parts[1];
      electionCountLabel = '';
    }

    if (name.isEmpty) {
      continue;
    }
    entries.add(
      LocalElectionRosterEntry(
        prefecture: currentPrefecture,
        assemblyLabel: assemblyLabel,
        constituency: constituency,
        name: name,
        electionCountLabel: electionCountLabel,
      ),
    );
  }

  final rawExpectedCount = memo.metadata['rosterCount'];
  final expectedCount = rawExpectedCount is int
      ? rawExpectedCount
      : int.tryParse('${rawExpectedCount ?? ''}');
  if (expectedCount != null &&
      expectedCount >= 10 &&
      entries.length < (expectedCount * 0.5).floor()) {
    return const <LocalElectionRosterEntry>[];
  }

  return entries;
}

LocalElectionRosterDiff? computeLocalElectionRosterDiff({
  required PublicMemo previousMemo,
  required LocalElectionRealitySnapshot currentSnapshot,
  required List<LocalElectionLegislatorProfile> currentMembers,
  required List<LocalElectionPrefectureReality> currentPrefectures,
}) {
  final previousEntries = extractRosterEntriesFromPublicMemo(previousMemo);
  if (previousEntries.isEmpty) {
    return null;
  }

  final currentEntries = currentMembers
      .map(LocalElectionRosterEntry.fromProfile)
      .where((entry) => entry.name.isNotEmpty)
      .toList();

  final unmatchedPrev = Set<int>.from(
    List<int>.generate(previousEntries.length, (index) => index),
  );
  final unmatchedCurr = Set<int>.from(
    List<int>.generate(currentEntries.length, (index) => index),
  );

  final nameChanges = <LocalElectionRosterChange>[];
  final locationChanges = <LocalElectionRosterChange>[];
  final attributeChanges = <LocalElectionRosterChange>[];

  void recordPair(int prevIdx, int currIdx) {
    unmatchedPrev.remove(prevIdx);
    unmatchedCurr.remove(currIdx);
    final before = previousEntries[prevIdx];
    final after = currentEntries[currIdx];
    final nameChanged =
        _normalizeText(before.name) != _normalizeText(after.name);
    final locationChanged = _normalizeText(before.effectiveLocation) !=
        _normalizeText(after.effectiveLocation);
    final assemblyChanged = _normalizeText(before.assemblyLabel) !=
        _normalizeText(after.assemblyLabel);
    final electionCountChanged = _normalizeText(before.electionCountLabel) !=
        _normalizeText(after.electionCountLabel);
    if (!nameChanged &&
        !locationChanged &&
        !assemblyChanged &&
        !electionCountChanged) {
      return;
    }
    final change = LocalElectionRosterChange(
      before: before,
      after: after,
      nameChanged: nameChanged,
      locationChanged: locationChanged,
      assemblyChanged: assemblyChanged,
      electionCountChanged: electionCountChanged,
    );
    if (nameChanged) {
      nameChanges.add(change);
    } else if (locationChanged) {
      locationChanges.add(change);
    } else {
      attributeChanges.add(change);
    }
  }

  // Pass 1: 1-to-1 invariant detailUrl match.
  final prevByUrl = <String, List<int>>{};
  for (final idx in unmatchedPrev) {
    final url = _normalizeUrl(previousEntries[idx].detailUrl);
    if (url.isNotEmpty) {
      prevByUrl.putIfAbsent(url, () => <int>[]).add(idx);
    }
  }
  final currByUrl = <String, List<int>>{};
  for (final idx in unmatchedCurr) {
    final url = _normalizeUrl(currentEntries[idx].detailUrl);
    if (url.isNotEmpty) {
      currByUrl.putIfAbsent(url, () => <int>[]).add(idx);
    }
  }
  for (final entry in prevByUrl.entries) {
    final currIndices = currByUrl[entry.key];
    if (entry.value.length == 1 &&
        currIndices != null &&
        currIndices.length == 1) {
      recordPair(entry.value.first, currIndices.first);
    }
  }

  // Pass 2: Exact tuple match on remaining entries.
  final prevByExact = <String, List<int>>{};
  for (final idx in unmatchedPrev) {
    final key = _exactTupleKey(previousEntries[idx]);
    prevByExact.putIfAbsent(key, () => <int>[]).add(idx);
  }
  final currByExact = <String, List<int>>{};
  for (final idx in unmatchedCurr) {
    final key = _exactTupleKey(currentEntries[idx]);
    currByExact.putIfAbsent(key, () => <int>[]).add(idx);
  }
  for (final entry in prevByExact.entries) {
    final currIndices = currByExact[entry.key];
    if (currIndices == null) {
      continue;
    }
    if (entry.value.length == 1 && currIndices.length == 1) {
      final prevIdx = entry.value.first;
      final currIdx = currIndices.first;
      if (!_hasConflictingDetailUrl(
        previousEntries[prevIdx],
        currentEntries[currIdx],
      )) {
        recordPair(prevIdx, currIdx);
      }
    }
  }

  // Pass 3a: Same prefecture + normalized name (location/assembly/term change).
  final prevByName = <String, List<int>>{};
  for (final idx in unmatchedPrev) {
    final e = previousEntries[idx];
    final pref = _normalizeText(e.prefecture);
    final name = _normalizeName(e.name);
    if (pref.isNotEmpty && name.isNotEmpty) {
      prevByName.putIfAbsent('$pref||$name', () => <int>[]).add(idx);
    }
  }
  final currByName = <String, List<int>>{};
  for (final idx in unmatchedCurr) {
    final e = currentEntries[idx];
    final pref = _normalizeText(e.prefecture);
    final name = _normalizeName(e.name);
    if (pref.isNotEmpty && name.isNotEmpty) {
      currByName.putIfAbsent('$pref||$name', () => <int>[]).add(idx);
    }
  }
  for (final entry in prevByName.entries) {
    final currIndices = currByName[entry.key];
    if (entry.value.length == 1 &&
        currIndices != null &&
        currIndices.length == 1) {
      final prevIdx = entry.value.first;
      final currIdx = currIndices.first;
      if (!_hasConflictingDetailUrl(
        previousEntries[prevIdx],
        currentEntries[currIdx],
      )) {
        recordPair(prevIdx, currIdx);
      }
    }
  }

  // Pass 3b: Same seat tuple + likely same-person name notation variation.
  final prevBySeat = <String, List<int>>{};
  for (final idx in unmatchedPrev) {
    final key = _seatTupleKey(previousEntries[idx]);
    if (key != null) {
      prevBySeat.putIfAbsent(key, () => <int>[]).add(idx);
    }
  }
  final currBySeat = <String, List<int>>{};
  for (final idx in unmatchedCurr) {
    final key = _seatTupleKey(currentEntries[idx]);
    if (key != null) {
      currBySeat.putIfAbsent(key, () => <int>[]).add(idx);
    }
  }
  for (final entry in prevBySeat.entries) {
    final currIndices = currBySeat[entry.key];
    if (entry.value.length == 1 &&
        currIndices != null &&
        currIndices.length == 1) {
      final prevIdx = entry.value.first;
      final currIdx = currIndices.first;
      final before = previousEntries[prevIdx];
      final after = currentEntries[currIdx];
      if ((before.detailUrl.isEmpty || after.detailUrl.isEmpty) &&
          _isLikelySamePersonNameNotation(before, after)) {
        recordPair(prevIdx, currIdx);
      }
    }
  }

  final added = unmatchedCurr.map((idx) => currentEntries[idx]).toList()
    ..sort(_compareEntries);
  final removed = unmatchedPrev.map((idx) => previousEntries[idx]).toList()
    ..sort(_compareEntries);

  nameChanges.sort((a, b) => _compareEntries(a.after, b.after));
  locationChanges.sort((a, b) => _compareEntries(a.after, b.after));
  attributeChanges.sort((a, b) => _compareEntries(a.after, b.after));

  final hasMissingMeta =
      previousMemo.metadata.containsKey('missingPrefectures') &&
          previousMemo.metadata['missingPrefectures'] is List;
  final currentMissingList = currentPrefectures
      .where((item) => item.currentMembers == 0)
      .map((item) => item.prefecture.trim())
      .where((pref) => pref.isNotEmpty)
      .toList();
  final currentActiveCount =
      currentPrefectures.where((item) => item.currentMembers > 0).length;

  var previousActiveCount =
      (previousMemo.metadata['activePrefectureCount'] as num?)?.toInt() ?? 0;
  final newlyCoveredPrefectures = <String>[];
  final newlyMissingPrefectures = <String>[];

  if (hasMissingMeta) {
    final previousMissingSet =
        (previousMemo.metadata['missingPrefectures'] as List<dynamic>)
            .map((item) => '$item'.trim())
            .where((pref) => pref.isNotEmpty)
            .toSet();
    if (previousActiveCount <= 0) {
      previousActiveCount =
          localElectionAllPrefectures.length - previousMissingSet.length;
    }
    final currentMissingSet = currentMissingList.toSet();
    for (final pref in localElectionAllPrefectures) {
      if (previousMissingSet.contains(pref) &&
          !currentMissingSet.contains(pref)) {
        newlyCoveredPrefectures.add(pref);
      } else if (!previousMissingSet.contains(pref) &&
          currentMissingSet.contains(pref)) {
        newlyMissingPrefectures.add(pref);
      }
    }
  } else if (previousEntries.length >= 50) {
    final previousPresentSet =
        previousEntries.map((entry) => entry.prefecture.trim()).toSet();
    previousActiveCount = previousPresentSet.length;
    final currentMissingSet = currentMissingList.toSet();
    for (final pref in localElectionAllPrefectures) {
      if (!previousPresentSet.contains(pref) &&
          !currentMissingSet.contains(pref)) {
        newlyCoveredPrefectures.add(pref);
      } else if (previousPresentSet.contains(pref) &&
          currentMissingSet.contains(pref)) {
        newlyMissingPrefectures.add(pref);
      }
    }
  } else {
    previousActiveCount =
        previousEntries.map((entry) => entry.prefecture.trim()).toSet().length;
  }

  return LocalElectionRosterDiff(
    previousDateLabel: resolvePublicMemoSnapshotDate(previousMemo),
    currentDate: currentSnapshot.fetchedAt.toLocal(),
    previousMemberCount: previousEntries.length,
    currentMemberCount: currentEntries.length,
    netDelta: currentEntries.length - previousEntries.length,
    previousActivePrefectureCount: previousActiveCount,
    currentActivePrefectureCount: currentActiveCount,
    newlyCoveredPrefectures: newlyCoveredPrefectures,
    newlyMissingPrefectures: newlyMissingPrefectures,
    currentMissingPrefectureCount: currentMissingList.length,
    added: added,
    removed: removed,
    nameChanges: nameChanges,
    locationChanges: locationChanges,
    attributeChanges: attributeChanges,
  );
}

String formatLocalElectionRosterDiffSection(LocalElectionRosterDiff diff) {
  final d = diff.currentDate;
  final headingTitle = diff.netDelta >= 0 ? '最新の増加履歴' : '最新の増減履歴';
  final heading = '$headingTitle（${d.year}年${d.month}月${d.day}日）';

  if (!diff.hasAnyChange) {
    return '$heading\n\n'
        '${diff.previousMemberCount} → ${diff.currentMemberCount}：±0'
        '（前回 ${diff.previousDateLabel} から名簿の変更なし）';
  }

  final deltaLabel = diff.netDelta > 0
      ? '+${diff.netDelta}'
      : (diff.netDelta < 0 ? '${diff.netDelta}' : '±0');
  final hasCountDelta = diff.added.isNotEmpty || diff.removed.isNotEmpty;
  final summaryLine = hasCountDelta
      ? '${diff.previousMemberCount} → ${diff.currentMemberCount}：$deltaLabel'
          '（追加${diff.added.length}人・名簿掲載なし${diff.removed.length}人）'
      : '${diff.previousMemberCount} → ${diff.currentMemberCount}：±0（表記変更のみ）';

  final buffer = StringBuffer()
    ..writeln(heading)
    ..writeln()
    ..writeln(summaryLine)
    ..writeln('前回共有メモ（${diff.previousDateLabel}）との比較');

  if (diff.added.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('【追加：${diff.added.length}人】');
    for (final entry in diff.added) {
      buffer.writeln(_formatMemberBullet(entry));
    }
  }

  if (diff.removed.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('【名簿掲載なし：${diff.removed.length}人】');
    for (final entry in diff.removed) {
      buffer.writeln(_formatMemberBullet(entry));
    }
  }

  if (diff.nameChanges.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('【氏名表記の変更：人数の増減なし】');
    for (final change in diff.nameChanges) {
      final details = _memberDetails(change.after);
      buffer.writeln(
        details.isEmpty
            ? '・${change.before.name} → ${change.after.name}'
            : '・${change.before.name} → ${change.after.name}（$details）',
      );
    }
  }

  if (diff.locationChanges.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('【所在地表記の変更：人数の増減なし】');
    for (final change in diff.locationChanges) {
      final headerParts = <String>[
        change.after.prefecture,
        change.after.assemblyLabel,
      ].where((item) => item.isNotEmpty).toList();
      final beforeLoc = change.before.effectiveLocation.isEmpty
          ? '(記載なし)'
          : change.before.effectiveLocation;
      final afterLoc = change.after.effectiveLocation.isEmpty
          ? '(記載なし)'
          : change.after.effectiveLocation;
      buffer
        ..writeln(
          headerParts.isEmpty
              ? '・${change.after.name}'
              : '・${change.after.name}（${headerParts.join('・')}）',
        )
        ..writeln('　$beforeLoc → $afterLoc');
    }
  }

  if (diff.attributeChanges.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('【議会・当選回数表記の変更：人数の増減なし】');
    for (final change in diff.attributeChanges) {
      final beforeAttr = <String>[
        change.before.assemblyLabel,
        change.before.electionCountLabel,
      ].where((item) => item.isNotEmpty).join('・');
      final afterAttr = <String>[
        change.after.assemblyLabel,
        change.after.electionCountLabel,
      ].where((item) => item.isNotEmpty).join('・');
      buffer.writeln(
        '・${change.after.name}（${change.after.prefecture}）：'
        '$beforeAttr → $afterAttr',
      );
    }
  }

  buffer
    ..writeln()
    ..writeln('※保存名簿の比較による増減です。');
  if (diff.added.isNotEmpty) {
    buffer.writeln('※「追加」は今回の名簿への新規掲載を意味します。');
  }
  if (diff.removed.isNotEmpty) {
    buffer.writeln('※「名簿掲載なし」は離党・辞職・落選などを確認したという意味ではありません。');
  }
  for (final entry in diff.added) {
    if (entry.effectiveLocation.isEmpty) {
      buffer.writeln('※${entry.name}氏は自治体名が名簿に記載されていません。');
    }
  }
  if (diff.hasNotationChanges) {
    buffer.writeln('※氏名・所在地等の表記変更は人数の増減に含めていません。');
  }

  if (diff.newlyCoveredPrefectures.isNotEmpty) {
    final prefsLabel = diff.newlyCoveredPrefectures.join('・');
    if (diff.currentMissingPrefectureCount == 0) {
      buffer.writeln(
        '注目点: $prefsLabelに初めて地方議員が掲載され、議員在籍県数は'
        '${diff.previousActivePrefectureCount}県から'
        '${diff.currentActivePrefectureCount}県になり、議員不在県がなくなりました。',
      );
    } else {
      buffer.writeln(
        '注目点: $prefsLabelに地方議員が掲載され、議員在籍県数は'
        '${diff.previousActivePrefectureCount}県から'
        '${diff.currentActivePrefectureCount}県になりました'
        '（議員不在県: 残り${diff.currentMissingPrefectureCount}県）。',
      );
    }
  } else if (diff.newlyMissingPrefectures.isNotEmpty) {
    final prefsLabel = diff.newlyMissingPrefectures.join('・');
    buffer.writeln(
      '注目点: $prefsLabelの掲載議員が0人となり、議員在籍県数は'
      '${diff.previousActivePrefectureCount}県から'
      '${diff.currentActivePrefectureCount}県になりました。',
    );
  }

  return buffer.toString().trimRight();
}

String _memberDetails(LocalElectionRosterEntry entry) {
  final parts = <String>[
    entry.prefecture,
    entry.effectiveLocation,
    entry.assemblyLabel,
    entry.electionCountLabel,
  ].where((item) => item.trim().isNotEmpty).toList();
  return parts.join('・');
}

String _formatMemberBullet(LocalElectionRosterEntry entry) {
  final details = _memberDetails(entry);
  return details.isEmpty ? '・${entry.name}' : '・${entry.name}（$details）';
}

String _normalizeText(String value) {
  return value.replaceAll(RegExp(r'[\s　]+'), ' ').trim();
}

String _normalizeName(String value) {
  return value.replaceAll(RegExp(r'[\s　]+'), '').trim();
}

String _normalizeUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  return trimmed.endsWith('/')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
}

bool _hasConflictingDetailUrl(
  LocalElectionRosterEntry before,
  LocalElectionRosterEntry after,
) {
  final beforeUrl = _normalizeUrl(before.detailUrl);
  final afterUrl = _normalizeUrl(after.detailUrl);
  return beforeUrl.isNotEmpty && afterUrl.isNotEmpty && beforeUrl != afterUrl;
}

String _exactTupleKey(LocalElectionRosterEntry entry) {
  return <String>[
    _normalizeText(entry.prefecture),
    _normalizeText(entry.assemblyLabel),
    _normalizeText(entry.effectiveLocation),
    _normalizeName(entry.name),
    _normalizeText(entry.electionCountLabel),
  ].join('||');
}

String? _seatTupleKey(LocalElectionRosterEntry entry) {
  final pref = _normalizeText(entry.prefecture);
  final assembly = _normalizeText(entry.assemblyLabel);
  final location = _normalizeText(entry.effectiveLocation);
  final wins = _normalizeText(entry.electionCountLabel);
  if (pref.isEmpty || assembly.isEmpty || location.isEmpty || wins.isEmpty) {
    return null;
  }
  return '$pref||$assembly||$location||$wins';
}

String _toHiraganaNoSpace(String value) {
  final buffer = StringBuffer();
  for (final code in value.replaceAll(RegExp(r'[\s　]+'), '').runes) {
    if (code >= 0x30A1 && code <= 0x30F6) {
      buffer.writeCharCode(code - 0x60);
    } else {
      buffer.writeCharCode(code);
    }
  }
  return buffer.toString();
}

bool _isLikelySamePersonNameNotation(
  LocalElectionRosterEntry before,
  LocalElectionRosterEntry after,
) {
  final beforeCollapsed = _normalizeName(before.name);
  final afterCollapsed = _normalizeName(after.name);
  if (beforeCollapsed.isEmpty || afterCollapsed.isEmpty) {
    return false;
  }
  if (beforeCollapsed == afterCollapsed) {
    return true;
  }
  if (after.kana.isNotEmpty &&
      _toHiraganaNoSpace(before.name) == _toHiraganaNoSpace(after.kana)) {
    return true;
  }
  if (before.kana.isNotEmpty &&
      _toHiraganaNoSpace(after.name) == _toHiraganaNoSpace(before.kana)) {
    return true;
  }
  final beforeTokens = _normalizeText(before.name).split(' ');
  final afterTokens = _normalizeText(after.name).split(' ');
  if (beforeTokens.length >= 2 && afterTokens.length >= 2) {
    if (beforeTokens.first == afterTokens.first ||
        beforeTokens.last == afterTokens.last) {
      return true;
    }
  }
  return false;
}

int _compareEntries(
  LocalElectionRosterEntry left,
  LocalElectionRosterEntry right,
) {
  final prefIdxLeft = localElectionAllPrefectures.indexOf(left.prefecture);
  final prefIdxRight = localElectionAllPrefectures.indexOf(right.prefecture);
  if (prefIdxLeft != -1 && prefIdxRight != -1 && prefIdxLeft != prefIdxRight) {
    return prefIdxLeft.compareTo(prefIdxRight);
  }
  final prefCompare = left.prefecture.compareTo(right.prefecture);
  if (prefCompare != 0) {
    return prefCompare;
  }
  return left.name.compareTo(right.name);
}
