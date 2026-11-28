/// Jev Mario Lab のステージ別（World 1-1 / 1-2）テレメトリ・リセット隔離・
/// 4 バックエンド個別比較の契約を扱う純粋サービス（UI / ネットワーク非依存）。
///
/// クリア証跡のない結果をクリア扱いしない。World 1-1 の既存記録は変更しない。
library;

/// 選択可能な独立ステージ。
enum JevMarioStageId {
  world1_1('world1_1', 'overworld'),
  world1_2('world1_2', 'underground');

  const JevMarioStageId(this.wireName, this.theme);

  final String wireName;
  final String theme;
}

/// ステージ固有の設定（テレメトリ名前空間・音声・録画プロファイル）。
class JevMarioStageProfile {
  const JevMarioStageProfile({
    required this.stage,
    required this.telemetryNamespace,
    required this.audioProfileId,
    required this.recordingProfileId,
    required this.preservedUnmodified,
  });

  final JevMarioStageId stage;
  final String telemetryNamespace;
  final String audioProfileId;
  final String recordingProfileId;

  /// World 1-1 のように既存挙動を変更せず保持するステージか。
  final bool preservedUnmodified;
}

class JevMarioStageRegistry {
  const JevMarioStageRegistry._();

  static const JevMarioStageProfile world11 = JevMarioStageProfile(
    stage: JevMarioStageId.world1_1,
    telemetryNamespace: 'jev_mario.world1_1',
    audioProfileId: 'overworld_original',
    recordingProfileId: 'overworld_default',
    preservedUnmodified: true,
  );

  static const JevMarioStageProfile world12 = JevMarioStageProfile(
    stage: JevMarioStageId.world1_2,
    telemetryNamespace: 'jev_mario.world1_2',
    audioProfileId: 'underground_original',
    recordingProfileId: 'underground_default',
    preservedUnmodified: false,
  );

  static const List<JevMarioStageProfile> all = <JevMarioStageProfile>[
    world11,
    world12,
  ];

  static JevMarioStageProfile profileFor(JevMarioStageId stage) {
    return stage == JevMarioStageId.world1_1 ? world11 : world12;
  }
}

class JevMarioValidation {
  const JevMarioValidation(this.errors);

  final List<String> errors;

  bool get isValid => errors.isEmpty;
}

/// ステージ別の実行状態。不変。
class JevMarioStageRunState {
  const JevMarioStageRunState({
    required this.stage,
    this.frames = 0,
    this.deaths = 0,
    this.telemetryEventCount = 0,
    this.cleared = false,
  });

  final JevMarioStageId stage;
  final int frames;
  final int deaths;
  final int telemetryEventCount;
  final bool cleared;

  JevMarioStageRunState copyWith({
    int? frames,
    int? deaths,
    int? telemetryEventCount,
    bool? cleared,
  }) {
    return JevMarioStageRunState(
      stage: stage,
      frames: frames ?? this.frames,
      deaths: deaths ?? this.deaths,
      telemetryEventCount: telemetryEventCount ?? this.telemetryEventCount,
      cleared: cleared ?? this.cleared,
    );
  }

  bool get isPristine =>
      frames == 0 && deaths == 0 && telemetryEventCount == 0 && !cleared;
}

/// ステージ名前空間付きテレメトリイベント。
class JevMarioTelemetryEvent {
  const JevMarioTelemetryEvent({
    required this.stage,
    required this.namespace,
    required this.name,
    required this.frame,
  });

  final JevMarioStageId stage;
  final String namespace;
  final String name;
  final int frame;
}

/// ステージ別のテレメトリ・実行状態ストア。不変（変更は新しいインスタンスを返す）。
class JevMarioStageTelemetryStore {
  JevMarioStageTelemetryStore({
    Map<JevMarioStageId, JevMarioStageRunState>? states,
    List<JevMarioTelemetryEvent>? events,
  })  : states = Map<JevMarioStageId, JevMarioStageRunState>.unmodifiable(
          states ??
              <JevMarioStageId, JevMarioStageRunState>{
                for (final stage in JevMarioStageId.values)
                  stage: JevMarioStageRunState(stage: stage),
              },
        ),
        events = List<JevMarioTelemetryEvent>.unmodifiable(
          events ?? const <JevMarioTelemetryEvent>[],
        );

  final Map<JevMarioStageId, JevMarioStageRunState> states;
  final List<JevMarioTelemetryEvent> events;

  JevMarioStageRunState stateOf(JevMarioStageId stage) {
    return states[stage] ?? JevMarioStageRunState(stage: stage);
  }

  List<JevMarioTelemetryEvent> eventsOf(JevMarioStageId stage) {
    return events
        .where((event) => event.stage == stage)
        .toList(growable: false);
  }

  /// イベントを記録する。名前空間は対象ステージのプロファイルから決まる。
  JevMarioStageTelemetryStore record({
    required JevMarioStageId stage,
    required String name,
    required int frame,
    bool died = false,
    bool cleared = false,
  }) {
    final profile = JevMarioStageRegistry.profileFor(stage);
    final current = stateOf(stage);
    final nextStates = Map<JevMarioStageId, JevMarioStageRunState>.of(states);
    nextStates[stage] = current.copyWith(
      frames: frame > current.frames ? frame : current.frames,
      deaths: died ? current.deaths + 1 : current.deaths,
      telemetryEventCount: current.telemetryEventCount + 1,
      cleared: current.cleared || cleared,
    );
    return JevMarioStageTelemetryStore(
      states: nextStates,
      events: <JevMarioTelemetryEvent>[
        ...events,
        JevMarioTelemetryEvent(
          stage: stage,
          namespace: profile.telemetryNamespace,
          name: name,
          frame: frame,
        ),
      ],
    );
  }

  /// 指定ステージだけを初期化する。他ステージの状態・イベントは変更しない。
  JevMarioStageTelemetryStore resetStage(JevMarioStageId stage) {
    final nextStates = Map<JevMarioStageId, JevMarioStageRunState>.of(states);
    nextStates[stage] = JevMarioStageRunState(stage: stage);
    return JevMarioStageTelemetryStore(
      states: nextStates,
      events: events.where((event) => event.stage != stage).toList(),
    );
  }
}

/// 支援モード。明示的に記録し、暗黙の支援を許さない。
enum JevMarioAssistance { none, assisted }

enum JevMarioInferenceKind { mock, live }

/// 1 バックエンド × 1 ステージの試行結果。
class JevMarioBackendRun {
  const JevMarioBackendRun({
    required this.backendId,
    required this.stage,
    required this.assistance,
    required this.inferenceKind,
    required this.cleared,
    this.clearEvidenceId,
    this.failureReason,
  });

  final String backendId;
  final JevMarioStageId stage;
  final JevMarioAssistance assistance;
  final JevMarioInferenceKind inferenceKind;
  final bool cleared;

  /// クリア証跡（リプレイ ID など）。クリアを主張する場合は必須。
  final String? clearEvidenceId;
  final String? failureReason;

  bool get failed => (failureReason ?? '').trim().isNotEmpty;
}

/// バックエンド別の集計（4 バックエンドを混ぜない）。
class JevMarioBackendSummary {
  const JevMarioBackendSummary({
    required this.backendId,
    required this.runCount,
    required this.verifiedClearCount,
    required this.failureCount,
    required this.assistedRunCount,
  });

  final String backendId;
  final int runCount;
  final int verifiedClearCount;
  final int failureCount;
  final int assistedRunCount;
}

class JevMarioStageTelemetryService {
  const JevMarioStageTelemetryService();

  static const int requiredBackendCount = 4;

  /// World 1-1 を保持しつつ World 1-2 が独立した設定を持つことを検証する。
  JevMarioValidation validateStageProfiles(
    List<JevMarioStageProfile> profiles,
  ) {
    final errors = <String>[];
    final stages = profiles.map((profile) => profile.stage).toSet();
    for (final stage in JevMarioStageId.values) {
      if (!stages.contains(stage)) {
        errors.add('missing_stage:${stage.wireName}');
      }
    }
    if (stages.length != profiles.length) {
      errors.add('duplicate_stage_profile');
    }
    if (profiles.map((profile) => profile.telemetryNamespace).toSet().length !=
        profiles.length) {
      errors.add('telemetry_namespace_must_be_distinct');
    }
    if (profiles.map((profile) => profile.audioProfileId).toSet().length !=
        profiles.length) {
      errors.add('audio_profile_must_be_distinct');
    }
    if (profiles.map((profile) => profile.recordingProfileId).toSet().length !=
        profiles.length) {
      errors.add('recording_profile_must_be_distinct');
    }
    for (final profile in profiles) {
      if (profile.telemetryNamespace.trim().isEmpty ||
          profile.audioProfileId.trim().isEmpty ||
          profile.recordingProfileId.trim().isEmpty) {
        errors.add('profile_fields_required:${profile.stage.wireName}');
      }
      if (profile.stage == JevMarioStageId.world1_1 &&
          !profile.preservedUnmodified) {
        errors.add('world1_1_must_be_preserved_unmodified');
      }
    }
    return JevMarioValidation(List<String>.unmodifiable(errors));
  }

  /// 4 つの実バックエンドを別々に評価する契約を検証する。
  JevMarioValidation validateBackendRuns(List<JevMarioBackendRun> runs) {
    final errors = <String>[];
    final backendIds = runs.map((run) => run.backendId.trim()).toSet();
    if (backendIds.contains('')) {
      errors.add('backend_id_required');
    }
    if (backendIds.where((id) => id.isNotEmpty).length !=
        requiredBackendCount) {
      errors.add('exactly_4_distinct_backends_required');
    }
    for (final run in runs) {
      final evidence = (run.clearEvidenceId ?? '').trim();
      if (run.cleared) {
        if (evidence.isEmpty) {
          errors.add('clear_requires_evidence:${run.backendId}');
        }
        if (run.inferenceKind == JevMarioInferenceKind.mock) {
          errors.add('mock_run_cannot_claim_clear:${run.backendId}');
        }
        if (run.failed) {
          errors.add('cleared_run_cannot_have_failure:${run.backendId}');
        }
      } else if (evidence.isNotEmpty) {
        errors.add('evidence_without_clear:${run.backendId}');
      }
    }
    return JevMarioValidation(List<String>.unmodifiable(errors));
  }

  /// バックエンドごとに集計する。証跡付き・実推論のクリアだけを検証済みクリアに数える。
  List<JevMarioBackendSummary> summarizeByBackend(
    List<JevMarioBackendRun> runs,
  ) {
    final ids = <String>[];
    for (final run in runs) {
      if (!ids.contains(run.backendId)) {
        ids.add(run.backendId);
      }
    }
    return List<JevMarioBackendSummary>.unmodifiable(
      ids.map((id) {
        final own = runs.where((run) => run.backendId == id).toList();
        return JevMarioBackendSummary(
          backendId: id,
          runCount: own.length,
          verifiedClearCount: own
              .where(
                (run) =>
                    run.cleared &&
                    run.inferenceKind == JevMarioInferenceKind.live &&
                    (run.clearEvidenceId ?? '').trim().isNotEmpty &&
                    !run.failed,
              )
              .length,
          failureCount: own.where((run) => run.failed).length,
          assistedRunCount: own
              .where((run) => run.assistance == JevMarioAssistance.assisted)
              .length,
        );
      }).toList(),
    );
  }
}
