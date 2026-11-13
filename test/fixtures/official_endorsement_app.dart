import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:my_web_app/models/election_intelligence.dart';
import 'package:my_web_app/services/local_election_reality_service.dart';
import 'package:my_web_app/ui/features/election_victory/view_models/official_endorsement_view_model.dart';
import 'package:my_web_app/ui/features/election_victory/widgets/official_endorsement_summary_card.dart';
import 'package:my_web_app/ui/features/election_victory/widgets/kokumin_representative_announcement_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

// This is a synthetic, loopback-only cache. Never run the normal app entrypoint.
const _cacheKey = 'election_intelligence_snapshot_v6_local';
const _seedKey = 'official_endorsement_fixture_seed_v1';
const _service = LocalElectionRealityService();

Map<String, dynamic> _oldEndorsements({bool verified = false}) => {
      if (verified) 'sourceCountsComplete': true,
      'sourceUrl': 'https://new-kokumin.jp/local-election-list',
      'sourceAsOf': '2026-10-21',
      'sourceDocumentSha256': List.filled(64, 'a').join(),
      'totalCount': 412,
      'incumbentCount': 170,
      'newcomerCount': 231,
      'formerCount': 11,
      'recommendationCount': 14,
      'prefectureCount': 1,
      'prefecturalCount': 113,
      'municipalCount': 299,
      'prefectures': [
        {
          'prefecture': '北海道',
          'totalCount': 412,
          'incumbentCount': 170,
          'newcomerCount': 231,
          'formerCount': 11,
          'prefecturalCount': 113,
          'municipalCount': 299,
        },
      ],
    };

ElectionIntelligenceSnapshot _intelligence(Map<String, dynamic> endorsements) =>
    ElectionIntelligenceSnapshot.fromJson({
      'schemaVersion': 1,
      'selectedMode': 'local',
      'modes': <Map<String, dynamic>>[],
      'goals': <Map<String, dynamic>>[],
      'achievements': <Map<String, dynamic>>[],
      'officialEndorsements': endorsements,
    });

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final location = Uri.base;
  if (!const bool.fromEnvironment('OFFICIAL_ENDORSEMENT_FIXTURE') ||
      location.scheme != 'http' ||
      location.host != '127.0.0.1' ||
      location.port != 7361) {
    throw StateError('The synthetic candidate fixture requires loopback:7361.');
  }
  await initializeDateFormatting('ja_JP');
  WidgetsBinding.instance.ensureSemantics();
  final prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey(_seedKey)) {
    await prefs.setString(
      _cacheKey,
      jsonEncode({
        'fetchedAt': '2026-10-21T00:00:00Z',
        // A positive synthetic count makes the real cache loader accept the row.
        'officialCurrentLocalMembers': 1,
        'electionIntelligence': {
          'schemaVersion': 1,
          'selectedMode': 'local',
          'officialEndorsements': _oldEndorsements(),
        },
      }),
    );
    await prefs.setBool(_seedKey, true);
  }
  final cached = await _service.loadCachedSnapshot(prefs: prefs);
  if (cached == null ||
      cached.electionIntelligence.officialEndorsements.totalCount != 412 ||
      cached.electionIntelligence.officialEndorsements.sourceCountsComplete) {
    throw StateError('The real cache loader did not read the legacy fixture.');
  }
  final model = OfficialEndorsementViewModel();
  model.updateFromIntelligence(cached.electionIntelligence);
  runApp(_Fixture(model: model, prefs: prefs));
}

class _Fixture extends StatefulWidget {
  const _Fixture({required this.model, required this.prefs});

  final OfficialEndorsementViewModel model;
  final SharedPreferences prefs;

  @override
  State<_Fixture> createState() => _FixtureState();
}

class _FixtureState extends State<_Fixture> {
  var _cacheReads = 1;
  var _input = '旧キャッシュ（合成412件・検証情報なし）';
  var _openedCandidateSource = '';
  var _openedAnnouncementSource = '';

  Future<void> _reloadCache() async {
    final cached = await _service.loadCachedSnapshot(prefs: widget.prefs);
    if (!mounted) {
      return;
    }
    if (cached == null ||
        cached.electionIntelligence.officialEndorsements.totalCount != 412) {
      throw StateError('Legacy cache changed unexpectedly.');
    }
    widget.model.updateFromIntelligence(cached.electionIntelligence);
    setState(() {
      _cacheReads += 1;
      _input = '旧キャッシュ（合成412件・検証情報なし）';
      _openedCandidateSource = '';
    });
  }

  void _applyOldEdge() {
    widget.model.updateFromIntelligence(
      _intelligence(_oldEndorsements(verified: true)),
    );
    setState(() {
      _input = '旧Edge（合成412件・検証済み・2026-10-21）';
      _openedCandidateSource = '';
    });
  }

  void _applyNewEdge() {
    final newer = {
      ..._oldEndorsements(verified: true),
      'sourceAsOf': '2026-11-12',
      'sourceUrl': 'https://example.invalid/official-endorsements-newer',
      'sourceDocumentSha256': List.filled(64, 'b').join(),
      'totalCount': 431,
      'incumbentCount': 177,
      'newcomerCount': 243,
      'recommendationCount': 16,
      'prefecturalCount': 117,
      'municipalCount': 314,
      'prefectures': [
        {
          'prefecture': '北海道',
          'totalCount': 431,
          'incumbentCount': 177,
          'newcomerCount': 243,
          'formerCount': 11,
          'prefecturalCount': 117,
          'municipalCount': 314,
        },
      ],
    };
    widget.model.updateFromIntelligence(_intelligence(newer));
    setState(() {
      _input = '新Edge（合成431件・検証済み・2026-11-12）';
      _openedCandidateSource = '';
    });
  }

  @override
  void dispose() {
    widget.model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(fontFamily: 'NotoSansJP'),
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('合成データ専用・localhost画面試験'),
                      const Text('本番・本人データ・実際のEdge応答ではありません'),
                      Text('入力: $_input'),
                      Text('キャッシュ読取: $_cacheReads回（合成412件）'),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: _applyOldEdge,
                            child: const Text('旧Edgeを反映'),
                          ),
                          TextButton(
                            onPressed: _applyNewEdge,
                            child: const Text('新しい合成Edgeを反映'),
                          ),
                          TextButton(
                            onPressed: _reloadCache,
                            child: const Text('キャッシュを再読込'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      KokuminRepresentativeAnnouncementCard(
                        onOpenSource: (url) {
                          setState(() => _openedAnnouncementSource = url);
                        },
                      ),
                      if (_openedAnnouncementSource.isNotEmpty)
                        Text('捕捉した発表出典URL: $_openedAnnouncementSource'),
                      const SizedBox(height: 12),
                      ListenableBuilder(
                        listenable: widget.model,
                        builder: (context, _) => OfficialEndorsementSummaryCard(
                          snapshot: widget.model.snapshot,
                          onOpenSource: (url) {
                            setState(() => _openedCandidateSource = url);
                          },
                        ),
                      ),
                      if (_openedCandidateSource.isNotEmpty)
                        Text('捕捉した公認出典URL: $_openedCandidateSource'),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
