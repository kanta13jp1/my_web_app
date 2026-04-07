// ignore_for_file: require_trailing_commas

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/local_election_reality.dart';
import '../models/public_memo.dart';
import 'public_memo_service.dart';

class LocalElectionShareDraft {
  final int noteId;
  final String title;
  final String content;
  final Map<String, dynamic> metadata;

  const LocalElectionShareDraft({
    required this.noteId,
    required this.title,
    required this.content,
    required this.metadata,
  });
}

class LocalElectionShareWindow {
  final String label;
  final int weekendOffset;

  const LocalElectionShareWindow({
    required this.label,
    required this.weekendOffset,
  });
}

class LocalElectionShareWindowRange {
  final DateTime start;
  final DateTime end;

  const LocalElectionShareWindowRange({
    required this.start,
    required this.end,
  });
}

class LocalElectionShareService {
  static const String publicCategory = '選挙ダッシュボード';
  static const String metadataType = 'local_election_snapshot';
  static const int lowPresenceThreshold = 4;
  static const int _syntheticNoteIdBase = 90000000000000;
  static const List<LocalElectionShareWindow> availableWindows =
      <LocalElectionShareWindow>[
    LocalElectionShareWindow(label: '今週末', weekendOffset: 0),
    LocalElectionShareWindow(label: '2週後', weekendOffset: 1),
    LocalElectionShareWindow(label: '3週後', weekendOffset: 2),
    LocalElectionShareWindow(label: '4週後', weekendOffset: 3),
    LocalElectionShareWindow(label: '5週後', weekendOffset: 4),
  ];

  final SupabaseClient _supabase;
  final PublicMemoService _publicMemoService;
  final DateFormat _dateOnlyFormat = DateFormat('yyyy/MM/dd', 'ja_JP');

  LocalElectionShareService(
    this._supabase, {
    PublicMemoService? publicMemoService,
  }) : _publicMemoService = publicMemoService ?? PublicMemoService(_supabase);

  Future<PublicMemo?> publishSnapshot({
    required LocalElectionRealitySnapshot snapshot,
    required List<LocalElectionLegislatorProfile> members,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return null;
    }

    final draft = buildDraft(
      snapshot: snapshot,
      members: members,
    );
    return _publicMemoService.upsertMemo(
      noteId: draft.noteId,
      userId: userId,
      title: draft.title,
      content: draft.content,
      category: publicCategory,
      metadata: draft.metadata,
    );
  }

  Future<PublicMemo?> loadPublishedSnapshot(
    LocalElectionRealitySnapshot snapshot,
  ) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return null;
    }
    return _publicMemoService.getUserPublicMemoByNoteId(
      noteId: buildSyntheticNoteId(snapshot),
      userId: userId,
    );
  }

  LocalElectionShareDraft buildDraft({
    required LocalElectionRealitySnapshot snapshot,
    required List<LocalElectionLegislatorProfile> members,
  }) {
    final resolvedMembers = _sortedMembers(members);
    final prefectures = _prefecturesForDisplay(snapshot);
    final title =
        '国民民主党 地方議員集計 ${_dateOnlyFormat.format(snapshot.fetchedAt.toLocal())}';

    return LocalElectionShareDraft(
      noteId: buildSyntheticNoteId(snapshot),
      title: title,
      content: _buildContent(
        title: title,
        snapshot: snapshot,
        prefectures: prefectures,
        members: resolvedMembers,
      ),
      metadata: _buildMetadata(
        snapshot: snapshot,
        prefectures: prefectures,
        members: resolvedMembers,
      ),
    );
  }

  String buildXShareText({
    required LocalElectionRealitySnapshot snapshot,
    required String publicUrl,
  }) {
    if (publicUrl.isNotEmpty) {
      final body = buildXShareBody(snapshot: snapshot);
      return '$body\n\n$publicUrl';
    }
    final prefectures = _prefecturesForDisplay(snapshot);
    final missingCount =
        prefectures.where((item) => item.currentMembers == 0).length;
    final lowCount = prefectures
        .where(
          (item) =>
              item.currentMembers > 0 &&
              item.currentMembers <= lowPresenceThreshold,
        )
        .length;
    final topPrefectures = snapshot.topPrefectures(limit: 3);

    final lines = <String>[
      '国民民主党の地方議員数 ${_dateOnlyFormat.format(snapshot.fetchedAt.toLocal())}',
      '${snapshot.officialCurrentLocalMembers}人',
      '700まで残り${snapshot.actualNetIncreaseRequired}人',
      '',
      '🔴議員不在 $missingCount県',
      '🟡要強化($lowPresenceThreshold人以下) $lowCount県',
      if (topPrefectures.isNotEmpty) '',
      for (final item in topPrefectures)
        '${item.prefecture} ${item.currentMembers}人',
      '',
      '全47都道府県の内訳と現職名簿を公開ノートに整理しました。',
      publicUrl,
    ];

    return lines.join('\n').trim();
  }

  String buildXShareBody({
    required LocalElectionRealitySnapshot snapshot,
  }) {
    return buildXShareText(
      snapshot: snapshot,
      publicUrl: '',
    );
  }

  Uri buildXShareIntentUri({
    required LocalElectionRealitySnapshot snapshot,
    required String publicUrl,
  }) {
    return Uri.https(
      'x.com',
      '/intent/tweet',
      <String, String>{
        'text': buildXShareBody(snapshot: snapshot),
        'url': publicUrl,
      },
    );
  }

  LocalElectionShareWindowRange scheduleWindowRange(
    LocalElectionShareWindow window, {
    DateTime? now,
  }) {
    final today = _normalizeDate(now ?? DateTime.now());
    final daysUntilSunday = (DateTime.sunday - today.weekday) % 7;
    final baseSunday = today.add(Duration(days: daysUntilSunday));
    final baseSaturday = baseSunday.subtract(const Duration(days: 1));
    final offset = Duration(days: window.weekendOffset * 7);

    return LocalElectionShareWindowRange(
      start: baseSaturday.add(offset),
      end: baseSunday.add(offset),
    );
  }

  String buildWindowDateRangeLabel(
    LocalElectionShareWindow window, {
    DateTime? now,
  }) {
    final range = scheduleWindowRange(window, now: now);
    return '${_dateOnlyFormat.format(range.start)}〜${_dateOnlyFormat.format(range.end)}';
  }

  List<LocalElectionScheduleEntry> schedulesForWindow({
    required LocalElectionRealitySnapshot snapshot,
    required LocalElectionShareWindow window,
    DateTime? now,
  }) {
    final range = scheduleWindowRange(window, now: now);
    final schedules = snapshot.upcomingSchedules.where((entry) {
      if (entry.isPast) {
        return false;
      }
      final voteDate = entry.parsedVoteDate;
      if (voteDate == null) {
        return false;
      }
      final localDate = _normalizeDate(voteDate.toLocal());
      return !localDate.isBefore(range.start) && !localDate.isAfter(range.end);
    }).toList()
      ..sort((a, b) {
        final aDate = a.parsedVoteDate ?? DateTime(9999);
        final bDate = b.parsedVoteDate ?? DateTime(9999);
        if (aDate != bDate) {
          return aDate.compareTo(bDate);
        }
        final prefectureCompare = a.prefecture.compareTo(b.prefecture);
        if (prefectureCompare != 0) {
          return prefectureCompare;
        }
        return a.electionName.compareTo(b.electionName);
      });
    return schedules;
  }

  /// Builds a Twitter/X thread for upcoming local elections with 0 Kokumin candidates.
  /// Returns a list of tweet texts forming a thread.
  /// Tweet 1: intro sentence + all prefecture blocks (no char truncation — user edits in dialog).
  /// Tweet 2: current member stats + top prefectures + public memo link.
  ///
  /// Specify either [weekendSaturday] (weekend-based) or [daysAhead] (legacy).
  /// [weekendSaturday] takes precedence when provided.
  List<String> buildUpcomingElectionsThread({
    required LocalElectionRealitySnapshot snapshot,
    String publicUrl = '',
    DateTime? weekendSaturday,
    int daysAhead = 7,
  }) {
    final List<LocalElectionScheduleEntry> upcoming;
    if (weekendSaturday != null) {
      upcoming = snapshot.schedulesOnWeekend(weekendSaturday)
        ..sort((a, b) {
          final aDate = a.parsedVoteDate ?? DateTime(9999);
          final bDate = b.parsedVoteDate ?? DateTime(9999);
          if (aDate != bDate) return aDate.compareTo(bDate);
          return a.prefecture.compareTo(b.prefecture);
        });
    } else {
      upcoming = snapshot
          .schedulesWithinDays(daysAhead)
          .where((e) => !e.isPast)
          .toList()
        ..sort((a, b) {
          final aDate = a.parsedVoteDate ?? DateTime(9999);
          final bDate = b.parsedVoteDate ?? DateTime(9999);
          if (aDate != bDate) return aDate.compareTo(bDate);
          return a.prefecture.compareTo(b.prefecture);
        });
    }

    final noCandidate =
        upcoming.where((e) => e.kokuminCandidateCount == 0).toList();
    final total = upcoming.length;
    final noCount = noCandidate.length;

    final tweets = <String>[];

    // --- Tweet 1: intro + ALL election entries grouped by prefecture ---
    final byPref = <String, List<LocalElectionScheduleEntry>>{};
    for (final e in noCandidate) {
      byPref.putIfAbsent(e.prefecture, () => []).add(e);
    }

    // Build human-readable date label for the weekend
    final String weekendLabel;
    if (weekendSaturday != null) {
      weekendLabel =
          '${weekendSaturday.month}/${weekendSaturday.day}(土)〜${weekendSaturday.add(const Duration(days: 1)).month}/${weekendSaturday.add(const Duration(days: 1)).day}(日)';
    } else {
      weekendLabel = '今週末';
    }

    final String introText;
    if (upcoming.isEmpty) {
      return ['$weekendLabel投開票日の地方選挙はありません。'];
    }
    if (noCount > 0) {
      final candidatePhrase = noCount == total ? '1人も' : '$noCount件';
      introText = '$weekendLabel投開票日の地方選挙が$total件ありますが、'
          '国民民主党は独自公認候補を$candidatePhrase擁立できていません。'
          '痛恨の極みです。こんな状況では統一地方選までに地方議員700人など絶対に達成できません。';
    } else {
      introText = '$weekendLabel投開票日の地方選挙が$total件あります。'
          '国民民主党は全選挙に候補者を擁立しています！';
    }

    const prefOrder = _allPrefectures;
    final sortedPrefs = byPref.keys.toList()
      ..sort((a, b) {
        final ai = prefOrder.indexOf(a);
        final bi = prefOrder.indexOf(b);
        if (ai == -1 && bi == -1) return a.compareTo(b);
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      });

    // Build tweet 1 — include ALL prefecture blocks (no 280-char truncation).
    // The dialog's char counter alerts the user if manual splitting is needed.
    final tweet1Buffer = StringBuffer(introText);
    for (final pref in sortedPrefs) {
      final elections = byPref[pref]!;
      tweet1Buffer.write('\n\n$pref');
      for (final e in elections) {
        tweet1Buffer.write('\n${e.electionName}');
      }
    }
    tweets.add(tweet1Buffer.toString().trim());

    // --- Tweet 2: statistics + top prefectures + link ---
    final prefectures = _prefecturesForDisplay(snapshot);
    final missingCount =
        prefectures.where((item) => item.currentMembers == 0).length;
    final lowCount = prefectures
        .where(
          (item) =>
              item.currentMembers > 0 &&
              item.currentMembers <= lowPresenceThreshold,
        )
        .length;
    final topPrefs = snapshot.topPrefectures(limit: 3);
    final dateStr = _dateOnlyFormat.format(snapshot.fetchedAt.toLocal());

    final stats = <String>[
      '国民民主党の地方議員数 $dateStr',
      '${snapshot.officialCurrentLocalMembers}人',
      '700まで残り${snapshot.actualNetIncreaseRequired}人',
      '',
      '🔴議員不在 $missingCount県',
      '🟡要強化($lowPresenceThreshold人以下) $lowCount県',
      '',
    ];
    for (final p in topPrefs) {
      stats.add('${p.prefecture} ${p.currentMembers}人');
    }
    if (publicUrl.isNotEmpty) {
      stats
        ..add('')
        ..add('全47都道府県の内訳と現職名簿を公開ノートに整理しました。')
        ..add(publicUrl);
    }
    tweets.add(stats.join('\n').trim());

    return tweets;
  }

  int buildSyntheticNoteId(LocalElectionRealitySnapshot snapshot) {
    final dateKey = int.parse(
      _dateOnlyFormat.format(snapshot.fetchedAt.toLocal()).replaceAll('/', ''),
    );
    return _syntheticNoteIdBase + dateKey;
  }

  String _buildContent({
    required String title,
    required LocalElectionRealitySnapshot snapshot,
    required List<LocalElectionPrefectureReality> prefectures,
    required List<LocalElectionLegislatorProfile> members,
  }) {
    final missing =
        prefectures.where((item) => item.currentMembers == 0).toList();
    final low = prefectures
        .where(
          (item) =>
              item.currentMembers > 0 &&
              item.currentMembers <= lowPresenceThreshold,
        )
        .toList();

    final buffer = StringBuffer()
      ..writeln(title)
      ..writeln()
      ..writeln('取得日時: ${snapshot.fetchedAt.toLocal().toIso8601String()}')
      ..writeln('公式地方議員数: ${snapshot.officialCurrentLocalMembers}人')
      ..writeln('基準340との差分: ${snapshot.deltaFromBaseline}人')
      ..writeln('700まで残り: ${snapshot.actualNetIncreaseRequired}人')
      ..writeln(
        '2023年統一地方選実績: ${snapshot.official2023FirstHalfWins} + '
        '${snapshot.official2023SecondHalfWins} = ${snapshot.official2023TotalWins}',
      )
      ..writeln(
          '議員在籍県数: ${prefectures.where((item) => item.currentMembers > 0).length}県')
      ..writeln('現職名簿件数: ${members.length}人');

    if (snapshot.aiSummary.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('AI要約')
        ..writeln(snapshot.aiSummary.trim());
    }

    if (snapshot.aiAlerts.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('注視ポイント');
      for (final item in snapshot.aiAlerts) {
        buffer.writeln('- $item');
      }
    }

    if (snapshot.aiStrategicNotes.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('戦略メモ');
      for (final item in snapshot.aiStrategicNotes) {
        buffer.writeln('- $item');
      }
    }

    buffer
      ..writeln()
      ..writeln('アラート');
    if (missing.isEmpty) {
      buffer.writeln('- 🔴議員不在県なし');
    } else {
      buffer.writeln(
          '- 🔴議員不在 ${missing.length}県: ${missing.map((item) => item.prefecture).join('、')}');
    }
    if (low.isEmpty) {
      buffer.writeln('- 🟡要強化県なし');
    } else {
      buffer.writeln(
        '- 🟡要強化($lowPresenceThreshold人以下) ${low.length}県: ${low.map((item) => item.prefecture).join('、')}',
      );
    }

    buffer
      ..writeln()
      ..writeln('全都道府県内訳');
    for (final prefecture in prefectures) {
      buffer.writeln(
        '${_prefectureMarker(prefecture)}${prefecture.prefecture} '
        '地方議員 ${prefecture.currentMembers}人 '
        '都道府県議 ${prefecture.prefecturalAssemblyMembers} / '
        '市区町村議 ${prefecture.municipalAssemblyMembers}',
      );
    }

    buffer
      ..writeln()
      ..writeln('現職地方議員名簿');
    for (final member in members) {
      buffer.writeln(_describeMember(member));
    }

    if (snapshot.sources.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('公式ソース');
      for (final source in snapshot.sources) {
        buffer.writeln('- ${source.label}: ${source.url}');
      }
    }

    return buffer.toString().trimRight();
  }

  Map<String, dynamic> _buildMetadata({
    required LocalElectionRealitySnapshot snapshot,
    required List<LocalElectionPrefectureReality> prefectures,
    required List<LocalElectionLegislatorProfile> members,
  }) {
    final missing =
        prefectures.where((item) => item.currentMembers == 0).toList();
    final low = prefectures
        .where(
          (item) =>
              item.currentMembers > 0 &&
              item.currentMembers <= lowPresenceThreshold,
        )
        .toList();

    return <String, dynamic>{
      'type': metadataType,
      'snapshotDate': _dateOnlyFormat.format(snapshot.fetchedAt.toLocal()),
      'fetchedAt': snapshot.fetchedAt.toIso8601String(),
      'officialCurrentLocalMembers': snapshot.officialCurrentLocalMembers,
      'actualNetIncreaseRequired': snapshot.actualNetIncreaseRequired,
      'activePrefectureCount':
          prefectures.where((item) => item.currentMembers > 0).length,
      'missingPrefectureCount': missing.length,
      'missingPrefectures': missing.map((item) => item.prefecture).toList(),
      'lowPresenceThreshold': lowPresenceThreshold,
      'lowPresencePrefectureCount': low.length,
      'lowPresencePrefectures': low.map((item) => item.prefecture).toList(),
      'rosterCount': members.length,
      'topPrefectures': snapshot
          .topPrefectures(limit: 5)
          .map(
            (item) => <String, dynamic>{
              'prefecture': item.prefecture,
              'currentMembers': item.currentMembers,
            },
          )
          .toList(),
    };
  }

  List<LocalElectionPrefectureReality> _prefecturesForDisplay(
    LocalElectionRealitySnapshot snapshot,
  ) {
    final prefectureMap = <String, LocalElectionPrefectureReality>{};
    for (final item in snapshot.prefectures) {
      prefectureMap[_normalizePrefectureKey(item.prefecture)] = item;
    }

    final completed = _allPrefectures.map((prefecture) {
      return prefectureMap[_normalizePrefectureKey(prefecture)] ??
          LocalElectionPrefectureReality(
            prefecture: prefecture,
            sourceUrl: '',
            currentMembers: 0,
            prefecturalAssemblyMembers: 0,
            municipalAssemblyMembers: 0,
          );
    }).toList();

    completed.sort((a, b) {
      final countCompare = b.currentMembers.compareTo(a.currentMembers);
      if (countCompare != 0) {
        return countCompare;
      }
      return a.prefecture.compareTo(b.prefecture);
    });

    return completed;
  }

  List<LocalElectionLegislatorProfile> _sortedMembers(
    List<LocalElectionLegislatorProfile> members,
  ) {
    final sorted = List<LocalElectionLegislatorProfile>.from(members);

    int categoryRank(String value) {
      switch (value) {
        case 'prefectural':
          return 0;
        case 'municipal':
          return 1;
        default:
          return 2;
      }
    }

    sorted.sort((left, right) {
      final prefectureCompare = left.prefecture.compareTo(right.prefecture);
      if (prefectureCompare != 0) {
        return prefectureCompare;
      }
      final categoryCompare = categoryRank(left.assemblyCategory) -
          categoryRank(right.assemblyCategory);
      if (categoryCompare != 0) {
        return categoryCompare;
      }
      return left.name.compareTo(right.name);
    });
    return sorted;
  }

  String _describeMember(LocalElectionLegislatorProfile member) {
    final segments = <String>[
      member.prefecture,
      if (member.municipality.trim().isNotEmpty) member.municipality.trim(),
      if (member.assemblyLabel.trim().isNotEmpty) member.assemblyLabel.trim(),
      member.name.trim(),
      if (member.electionCountLabel.trim().isNotEmpty)
        member.electionCountLabel.trim(),
      if (member.gender.trim().isNotEmpty) member.gender.trim(),
      if (member.age != null) '${member.age}歳',
      if (member.birthDate.trim().isNotEmpty) member.birthDate.trim(),
    ];
    final profile = member.profile.trim();
    if (profile.isNotEmpty) {
      segments.add(_truncate(profile, 120));
    }
    return '- ${segments.join(' / ')}';
  }

  String _prefectureMarker(LocalElectionPrefectureReality item) {
    if (item.currentMembers == 0) {
      return '🔴 ';
    }
    if (item.currentMembers <= lowPresenceThreshold) {
      return '🟡 ';
    }
    return '';
  }

  DateTime _normalizeDate(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  String _normalizePrefectureKey(String value) {
    final trimmed = value.trim();
    if (trimmed == '北海道') {
      return trimmed;
    }
    if (trimmed.endsWith('都') ||
        trimmed.endsWith('府') ||
        trimmed.endsWith('県')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength - 1)}…';
  }
}

const List<String> _allPrefectures = <String>[
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
