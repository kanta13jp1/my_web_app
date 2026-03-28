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

class LocalElectionShareService {
  static const String publicCategory = '選挙ダッシュボード';
  static const String metadataType = 'local_election_snapshot';
  static const int lowPresenceThreshold = 4;
  static const int _syntheticNoteIdBase = 90000000000000;

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
    final missing = prefectures.where((item) => item.currentMembers == 0).toList();
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
      ..writeln('議員在籍県数: ${prefectures.where((item) => item.currentMembers > 0).length}県')
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
      buffer.writeln('- 🔴議員不在 ${missing.length}県: ${missing.map((item) => item.prefecture).join('、')}');
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
    final missing = prefectures.where((item) => item.currentMembers == 0).toList();
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
      final categoryCompare =
          categoryRank(left.assemblyCategory) - categoryRank(right.assemblyCategory);
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
