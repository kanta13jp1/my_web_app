/// MuJoCo Vibe Sim 3段階検証の一次知見に基づく決定論的設定診断エンジン。
///
/// 外部サーバーや Supabase・AI API に依存せず、ブラウザ内で完結して
/// 物理破綻リスクと `MjSpec` / MuJoCo Studio 修正スニペットを試算する。
library;

enum VibeSimPreset {
  v1Naive,
  v2SpecTuned,
  v3Audited,
}

enum VibeSimIntegrator {
  euler,
  implicitFast,
  rk4,
}

enum VibeSimCone {
  pyramidal,
  elliptic,
}

enum VibeSimTrayGeometryMode {
  solidSingleBox,
  fiveWallCombined,
  fiveWallVisColSplit,
}

enum VibeSimSeverity {
  critical,
  high,
  warning,
  info,
}

enum VibeSimRiskLevel {
  safe,
  caution,
  danger,
}

class VibeSimInput {
  const VibeSimInput({
    required this.timestep,
    required this.integrator,
    required this.condim,
    required this.cone,
    required this.impratio,
    required this.trayGeometryMode,
    required this.rootOffsetMm,
    required this.rootMatchesModelName,
    required this.geomMarginMm,
    required this.solrefTimeconst,
    required this.solrefDampratio,
    required this.mujoco401Compat,
  });

  final double timestep;
  final VibeSimIntegrator integrator;
  final int condim;
  final VibeSimCone cone;
  final double impratio;
  final VibeSimTrayGeometryMode trayGeometryMode;
  final double rootOffsetMm;
  final bool rootMatchesModelName;
  final double geomMarginMm;
  final double solrefTimeconst;
  final double solrefDampratio;
  final bool mujoco401Compat;
}

class VibeSimRawFormValues {
  const VibeSimRawFormValues({
    required this.timestepText,
    required this.integrator,
    required this.condim,
    required this.cone,
    required this.impratioText,
    required this.trayGeometryMode,
    required this.rootOffsetMmText,
    required this.rootMatchesModelName,
    required this.geomMarginMmText,
    required this.solrefTimeconstText,
    required this.solrefDampratioText,
    required this.mujoco401Compat,
  });

  final String timestepText;
  final VibeSimIntegrator integrator;
  final int condim;
  final VibeSimCone cone;
  final String impratioText;
  final VibeSimTrayGeometryMode trayGeometryMode;
  final String rootOffsetMmText;
  final bool rootMatchesModelName;
  final String geomMarginMmText;
  final String solrefTimeconstText;
  final String solrefDampratioText;
  final bool mujoco401Compat;

  VibeSimRawFormValues copyWith({
    String? timestepText,
    VibeSimIntegrator? integrator,
    int? condim,
    VibeSimCone? cone,
    String? impratioText,
    VibeSimTrayGeometryMode? trayGeometryMode,
    String? rootOffsetMmText,
    bool? rootMatchesModelName,
    String? geomMarginMmText,
    String? solrefTimeconstText,
    String? solrefDampratioText,
    bool? mujoco401Compat,
  }) {
    return VibeSimRawFormValues(
      timestepText: timestepText ?? this.timestepText,
      integrator: integrator ?? this.integrator,
      condim: condim ?? this.condim,
      cone: cone ?? this.cone,
      impratioText: impratioText ?? this.impratioText,
      trayGeometryMode: trayGeometryMode ?? this.trayGeometryMode,
      rootOffsetMmText: rootOffsetMmText ?? this.rootOffsetMmText,
      rootMatchesModelName: rootMatchesModelName ?? this.rootMatchesModelName,
      geomMarginMmText: geomMarginMmText ?? this.geomMarginMmText,
      solrefTimeconstText: solrefTimeconstText ?? this.solrefTimeconstText,
      solrefDampratioText: solrefDampratioText ?? this.solrefDampratioText,
      mujoco401Compat: mujoco401Compat ?? this.mujoco401Compat,
    );
  }
}

class VibeSimFinding {
  const VibeSimFinding({
    required this.id,
    required this.severity,
    required this.title,
    required this.detail,
    required this.recommendation,
  });

  final String id;
  final VibeSimSeverity severity;
  final String title;
  final String detail;
  final String recommendation;
}

class VibeSimDiagnosticResult {
  const VibeSimDiagnosticResult({
    required this.input,
    required this.riskScore,
    required this.riskLevel,
    required this.findings,
    required this.snippet,
    required this.validationErrors,
  });

  final VibeSimInput? input;
  final int riskScore;
  final VibeSimRiskLevel riskLevel;
  final List<VibeSimFinding> findings;
  final String snippet;
  final Map<String, String> validationErrors;

  bool get isValid => validationErrors.isEmpty && input != null;
}

class VibeSimBenchmarkRow {
  const VibeSimBenchmarkRow({
    required this.stageLabel,
    required this.timestepLabel,
    required this.integratorLabel,
    required this.captureRateLabel,
    required this.tiltRetentionLabel,
    required this.settledTimeLabel,
    required this.restingPenetrationLabel,
    required this.qaccWarningsLabel,
    required this.auditLabel,
  });

  final String stageLabel;
  final String timestepLabel;
  final String integratorLabel;
  final String captureRateLabel;
  final String tiltRetentionLabel;
  final String settledTimeLabel;
  final String restingPenetrationLabel;
  final String qaccWarningsLabel;
  final String auditLabel;
}

class VibeSimDiagnosticService {
  const VibeSimDiagnosticService._();

  static const Set<int> allowedCondimValues = <int>{1, 3, 4, 6};

  /// REPORT.md（evidence/results.json 2026-11-22T03:46:31+09:00 / audit_summary.json）の一次実測値。
  static const List<VibeSimBenchmarkRow> benchmarkRows = <VibeSimBenchmarkRow>[
    VibeSimBenchmarkRow(
      stageLabel: 'v1_naive（破綻ベースライン）',
      timestepLabel: '0.01 s',
      integratorLabel: 'Euler',
      captureRateLabel: '0.0 (0/4個)',
      tiltRetentionLabel: '0.0 (0/4個)',
      settledTimeLabel: '未収束 (null)',
      restingPenetrationLabel: '0.0 mm（飛散消滅）',
      qaccWarningsLabel: '3 回',
      auditLabel: 'FAIL (+14.936 mm 浮き)',
    ),
    VibeSimBenchmarkRow(
      stageLabel: 'v2_spec_tuned（仕様調整）',
      timestepLabel: '0.002 s',
      integratorLabel: 'implicitfast',
      captureRateLabel: '1.0 (4/4個)',
      tiltRetentionLabel: '4.0 (4/4個)',
      settledTimeLabel: '0.416 s',
      restingPenetrationLabel: '0.0649 mm',
      qaccWarningsLabel: '0 回',
      auditLabel: '—（分離未適用）',
    ),
    VibeSimBenchmarkRow(
      stageLabel: 'v3_audited（監査準拠）',
      timestepLabel: '0.002 s',
      integratorLabel: 'implicitfast',
      captureRateLabel: '1.0 (4/4個)',
      tiltRetentionLabel: '4.0 (4/4個)',
      settledTimeLabel: '0.418 s',
      restingPenetrationLabel: '0.3729 mm',
      qaccWarningsLabel: '0 回',
      auditLabel: 'PASS (-0.016 mm)',
    ),
  ];

  static String presetLabel(final VibeSimPreset preset) => switch (preset) {
        VibeSimPreset.v1Naive => 'v1_naive（破綻例）',
        VibeSimPreset.v2SpecTuned => 'v2_spec_tuned（仕様調整）',
        VibeSimPreset.v3Audited => 'v3_audited（監査準拠・推奨）',
      };

  static String integratorLabel(final VibeSimIntegrator integrator) =>
      switch (integrator) {
        VibeSimIntegrator.euler => 'mjINT_EULER（標準）',
        VibeSimIntegrator.implicitFast => 'mjINT_IMPLICITFAST（推奨）',
        VibeSimIntegrator.rk4 => 'mjINT_RK4',
      };

  static String coneLabel(final VibeSimCone cone) => switch (cone) {
        VibeSimCone.pyramidal => 'pyramidal（四角錐近似）',
        VibeSimCone.elliptic => 'elliptic（楕円錐・推奨）',
      };

  static String trayModeLabel(final VibeSimTrayGeometryMode mode) =>
      switch (mode) {
        VibeSimTrayGeometryMode.solidSingleBox => 'solid_single_box（単一箱）',
        VibeSimTrayGeometryMode.fiveWallCombined => 'five_wall_combined（5壁統合）',
        VibeSimTrayGeometryMode.fiveWallVisColSplit =>
          'five_wall_vis_col_split（5壁＋描画/衝突分離）',
      };

  static String severityLabel(final VibeSimSeverity severity) =>
      switch (severity) {
        VibeSimSeverity.critical => 'Critical',
        VibeSimSeverity.high => 'High',
        VibeSimSeverity.warning => 'Warning',
        VibeSimSeverity.info => 'Info',
      };

  static String riskLevelLabel(final VibeSimRiskLevel level) => switch (level) {
        VibeSimRiskLevel.safe => '安全（監査基準準拠レベル）',
        VibeSimRiskLevel.caution => '要注意（一部パラメータ要調整）',
        VibeSimRiskLevel.danger => '危険（物理破綻リスク高）',
      };

  static VibeSimInput presetInput(final VibeSimPreset preset) =>
      switch (preset) {
        VibeSimPreset.v1Naive => const VibeSimInput(
            timestep: 0.01,
            integrator: VibeSimIntegrator.euler,
            condim: 3,
            cone: VibeSimCone.pyramidal,
            impratio: 1.0,
            trayGeometryMode: VibeSimTrayGeometryMode.solidSingleBox,
            rootOffsetMm: 54.8,
            rootMatchesModelName: false,
            geomMarginMm: 15.0,
            solrefTimeconst: 0.005,
            solrefDampratio: 0.2,
            mujoco401Compat: true,
          ),
        VibeSimPreset.v2SpecTuned => const VibeSimInput(
            timestep: 0.002,
            integrator: VibeSimIntegrator.implicitFast,
            condim: 6,
            cone: VibeSimCone.pyramidal,
            impratio: 1.0,
            trayGeometryMode: VibeSimTrayGeometryMode.fiveWallCombined,
            rootOffsetMm: 0.0,
            rootMatchesModelName: true,
            geomMarginMm: 0.0,
            solrefTimeconst: 0.02,
            solrefDampratio: 1.0,
            mujoco401Compat: true,
          ),
        VibeSimPreset.v3Audited => const VibeSimInput(
            timestep: 0.002,
            integrator: VibeSimIntegrator.implicitFast,
            condim: 6,
            cone: VibeSimCone.elliptic,
            impratio: 10.0,
            trayGeometryMode: VibeSimTrayGeometryMode.fiveWallVisColSplit,
            rootOffsetMm: 0.0,
            rootMatchesModelName: true,
            geomMarginMm: 0.0,
            solrefTimeconst: 0.02,
            solrefDampratio: 1.0,
            mujoco401Compat: true,
          ),
      };

  static VibeSimRawFormValues rawValuesForPreset(final VibeSimPreset preset) {
    final p = presetInput(preset);
    return VibeSimRawFormValues(
      timestepText: p.timestep.toString(),
      integrator: p.integrator,
      condim: p.condim,
      cone: p.cone,
      impratioText: p.impratio.toString(),
      trayGeometryMode: p.trayGeometryMode,
      rootOffsetMmText: p.rootOffsetMm.toString(),
      rootMatchesModelName: p.rootMatchesModelName,
      geomMarginMmText: p.geomMarginMm.toString(),
      solrefTimeconstText: p.solrefTimeconst.toString(),
      solrefDampratioText: p.solrefDampratio.toString(),
      mujoco401Compat: p.mujoco401Compat,
    );
  }

  static double? _parseBoundedDouble(
    final String raw,
    final String fieldKey,
    final String label,
    final double min,
    final double max,
    final Map<String, String> errors,
  ) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      errors[fieldKey] = '$label は空欄にできません。$min〜$max の範囲で数値を入力してください。';
      return null;
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null || parsed.isNaN || parsed.isInfinite) {
      errors[fieldKey] = '$label には有効な有限数値（$min〜$max）を入力してください。';
      return null;
    }
    if (parsed < min || parsed > max) {
      errors[fieldKey] = '$label は $min〜$max の範囲で数値を入力してください。';
      return null;
    }
    return parsed;
  }

  static VibeSimDiagnosticResult evaluateRaw(final VibeSimRawFormValues raw) {
    final errors = <String, String>{};

    final timestep = _parseBoundedDouble(
      raw.timestepText,
      'timestep',
      '時間刻み (timestep, s)',
      0.0001,
      0.1,
      errors,
    );
    final impratio = _parseBoundedDouble(
      raw.impratioText,
      'impratio',
      '摩擦・法線比 (impratio)',
      0.1,
      100.0,
      errors,
    );
    final rootOffsetMm = _parseBoundedDouble(
      raw.rootOffsetMmText,
      'rootOffsetMm',
      'ルート原点ずれ (mm)',
      0.0,
      500.0,
      errors,
    );
    final geomMarginMm = _parseBoundedDouble(
      raw.geomMarginMmText,
      'geomMarginMm',
      '接触マージン (margin, mm)',
      0.0,
      100.0,
      errors,
    );
    final solrefTimeconst = _parseBoundedDouble(
      raw.solrefTimeconstText,
      'solrefTimeconst',
      'solref 時定数 (s)',
      0.0005,
      1.0,
      errors,
    );
    final solrefDampratio = _parseBoundedDouble(
      raw.solrefDampratioText,
      'solrefDampratio',
      'solref 減衰比',
      0.05,
      5.0,
      errors,
    );

    if (!allowedCondimValues.contains(raw.condim)) {
      errors['condim'] = '接触摩擦次元 condim は 1, 3, 4, 6 のいずれかを選択してください。';
    }

    if (errors.isNotEmpty) {
      return VibeSimDiagnosticResult(
        input: null,
        riskScore: 0,
        riskLevel: VibeSimRiskLevel.danger,
        findings: const <VibeSimFinding>[],
        snippet: '',
        validationErrors: Map<String, String>.unmodifiable(errors),
      );
    }

    final input = VibeSimInput(
      timestep: timestep!,
      integrator: raw.integrator,
      condim: raw.condim,
      cone: raw.cone,
      impratio: impratio!,
      trayGeometryMode: raw.trayGeometryMode,
      rootOffsetMm: rootOffsetMm!,
      rootMatchesModelName: raw.rootMatchesModelName,
      geomMarginMm: geomMarginMm!,
      solrefTimeconst: solrefTimeconst!,
      solrefDampratio: solrefDampratio!,
      mujoco401Compat: raw.mujoco401Compat,
    );

    return evaluate(input);
  }

  static VibeSimDiagnosticResult evaluate(final VibeSimInput input) {
    final findings = <VibeSimFinding>[];

    // 1. timestep x integrator
    if (input.integrator == VibeSimIntegrator.euler && input.timestep > 0.002) {
      findings.add(
        const VibeSimFinding(
          id: 'integrator_euler_coarse_timestep',
          severity: VibeSimSeverity.critical,
          title: 'Euler 積分 × 粗い時間刻みによる数値発散リスク',
          detail:
              'v1_naive（timestep=0.01 s, Euler）では全3シードで QACC 異常警告が発生し、瞬間最大めり込み 14,515.57 mm・3.0秒未収束となりました。',
          recommendation:
              'timestep を 0.002 s 以下へ細かくし、mjINT_IMPLICITFAST へ切り替えてください。',
        ),
      );
    } else if (input.timestep > 0.005) {
      findings.add(
        const VibeSimFinding(
          id: 'coarse_timestep',
          severity: VibeSimSeverity.high,
          title: '時間刻み (timestep) が 0.005 s を超過',
          detail: '剛体の落下衝突で接触の立ち上がりを捉えきれず、反発や貫通が増大しやすくなります。',
          recommendation: 'timestep = 0.002 s 付近に設定してください。',
        ),
      );
    } else if (input.integrator == VibeSimIntegrator.euler) {
      findings.add(
        const VibeSimFinding(
          id: 'integrator_euler',
          severity: VibeSimSeverity.warning,
          title: '陰的積分法（mjINT_IMPLICITFAST）への切替推奨',
          detail: 'Euler 積分は接触剛性が高い場面でエネルギーが発散しやすいため、接触を伴う操作環境では暗黙積分が有利です。',
          recommendation:
              'spec.option.integrator = mujoco.mjtIntegrator.mjINT_IMPLICITFAST を指定してください。',
        ),
      );
    }

    // 2. Tray hollow vs solid box
    if (input.trayGeometryMode == VibeSimTrayGeometryMode.solidSingleBox) {
      findings.add(
        const VibeSimFinding(
          id: 'solid_box_cavity_blocked',
          severity: VibeSimSeverity.critical,
          title: '中空トレイの単一ボックス化によるキャビティ閉塞',
          detail:
              '1個の直方体ジオムでトレイを作ると内側の空間が存在せず、v1_naive 実測では捕獲率 0%（0/4個）・Scenario 4 開口判定 false となりました。',
          recommendation: '底板 1 枚＋側面 4 枚の 5 壁ジオム（または凸包分解）で構成してください。',
        ),
      );
    } else if (input.trayGeometryMode ==
        VibeSimTrayGeometryMode.fiveWallCombined) {
      findings.add(
        const VibeSimFinding(
          id: 'vis_col_group_not_split',
          severity: VibeSimSeverity.info,
          title: '描画用 (group=2) と衝突用 (group=3) のジオム分離が未適用',
          detail:
              '物理動作自体は 5 壁構成で安定しますが、mujoco-audit 基準の再利用可能アセットでは描画無質量（contype=0, conaffinity=0）と衝突ジオムの分離が推奨されます。',
          recommendation:
              '描画用 group=2 と衝突用 group=3 を分け、collision_alignment を点検してください。',
        ),
      );
    }

    // 3. condim & cone / impratio
    if (input.condim < 6) {
      findings.add(
        const VibeSimFinding(
          id: 'low_condim_friction',
          severity: VibeSimSeverity.warning,
          title: '接触摩擦次元 (condim < 6) によるねじれ・転がり摩擦の欠落',
          detail:
              'condim=3 では並進滑り摩擦のみが計算され、球体や円柱が傾斜時に止まりにくくなります（v2/v3 では condim=6 で 10度傾斜保持 4/4個）。',
          recommendation:
              'spec.default.geom.condim = 6 と適切な friction=[0.7, 0.01, 0.005] を設定してください。',
        ),
      );
    }
    if (input.cone == VibeSimCone.pyramidal || input.impratio < 10.0) {
      findings.add(
        const VibeSimFinding(
          id: 'pyramidal_cone_or_low_impratio',
          severity: VibeSimSeverity.info,
          title: '摩擦円錐設定（ELLIPTIC ＋ impratio=10.0）の最適化余地',
          detail:
              '四角錐近似（pyramidal）や impratio < 10 では、高摩擦把持や傾斜面での接触拘束が甘くなる場合があります。',
          recommendation:
              'spec.option.cone = mujoco.mjtCone.mjCONE_ELLIPTIC と spec.option.impratio = 10.0 を推奨します。',
        ),
      );
    }

    // 4. Root offset / naming / margin
    if (input.rootOffsetMm > 0.0) {
      findings.add(
        const VibeSimFinding(
          id: 'nonzero_root_offset',
          severity: VibeSimSeverity.high,
          title: 'ルートボディの非ゼロ座標オフセット',
          detail:
              'v1_naive（pos=[0.02, -0.01, 0.05]）は mujoco-audit --static_only で即座に ERROR となり、モデル再利用時に位置ずれや浮きを起こします。',
          recommendation:
              'ルートボディは pos=[0.0, 0.0, 0.0], quat=[1, 0, 0, 0] に固定してください。',
        ),
      );
    }
    if (!input.rootMatchesModelName) {
      findings.add(
        const VibeSimFinding(
          id: 'root_modelname_mismatch',
          severity: VibeSimSeverity.warning,
          title: 'ルートボディ名と modelname の不一致',
          detail:
              'v1_naive（root と tray_v1）では静的監査が WARNING を報告し、アタッチ時の識別性を損ねます。',
          recommendation:
              'spec.modelname とルートボディ名を同一の snake_case（例: vibe_sim_tray）に揃えてください。',
        ),
      );
    }
    if (input.geomMarginMm > 0.0) {
      findings.add(
        const VibeSimFinding(
          id: 'nonzero_geom_margin',
          severity: VibeSimSeverity.high,
          title: '非ゼロの接触 margin による見かけの浮き・キャビティ狭小化',
          detail:
              'v1_naive（margin=0.015 m）の Scenario 1 では +14.936 mm の浮き（許容 ±2.0 mm 超過）として FAIL しました。',
          recommendation: 'spec.default.geom.margin = 0.0 に設定してください。',
        ),
      );
    }

    // 5. solref timeconst & dampratio
    if (input.solrefTimeconst < 2.0 * input.timestep) {
      findings.add(
        const VibeSimFinding(
          id: 'solref_timeconst_below_2dt',
          severity: VibeSimSeverity.critical,
          title: 'solref 時定数が 2 × timestep 未満',
          detail:
              'v1_naive（solrefTimeconst=0.005 s < 2×0.01 s）のように時間刻みの2倍を下回ると、数値積分が接触バネを減衰できず爆発・跳ね過多（バウンス比 3125.09）を起こします。',
          recommendation:
              'solref[0]（時定数）を 2 * timestep 以上（例: 0.02 s）へ引き上げてください。',
        ),
      );
    }
    if (input.solrefDampratio < 0.7) {
      findings.add(
        const VibeSimFinding(
          id: 'solref_underdamped',
          severity: VibeSimSeverity.high,
          title: 'solref 減衰比が過小（跳ね返り過多リスク）',
          detail:
              '減衰比 0.2 の v1_naive に対し、臨界減衰（1.0）を採用した v2/v3 ではバウンス比が 0.0357–0.0367、静止めり込みが 0.0649–0.3729 mm（< 1.0 mm）に収束しました（0.35 m 落下時の瞬間ピーク 18.76–19.42 mm とは分離して評価）。',
          recommendation: 'spec.default.geom.solref = [0.02, 1.0] を設定してください。',
        ),
      );
    }

    findings.sort(
      (final a, final b) => a.severity.index.compareTo(b.severity.index),
    );

    var rawScore = 0;
    for (final f in findings) {
      rawScore += switch (f.severity) {
        VibeSimSeverity.critical => 30,
        VibeSimSeverity.high => 15,
        VibeSimSeverity.warning => 8,
        VibeSimSeverity.info => 3,
      };
    }
    final clampedScore = rawScore.clamp(0, 100);
    final level = clampedScore <= 10
        ? VibeSimRiskLevel.safe
        : (clampedScore <= 39
            ? VibeSimRiskLevel.caution
            : VibeSimRiskLevel.danger);

    return VibeSimDiagnosticResult(
      input: input,
      riskScore: clampedScore,
      riskLevel: level,
      findings: List<VibeSimFinding>.unmodifiable(findings),
      snippet: buildMjSpecSnippet(input: input, findings: findings),
      validationErrors: const <String, String>{},
    );
  }

  static String buildMjSpecSnippet({
    required final VibeSimInput input,
    required final List<VibeSimFinding> findings,
  }) {
    final ids = findings.map((final f) => f.id).toSet();
    final buf = StringBuffer()
      ..writeln('import mujoco')
      ..writeln()
      ..writeln('spec = mujoco.MjSpec()');

    if (ids.contains('root_modelname_mismatch') || ids.isEmpty) {
      buf.writeln("spec.modelname = 'vibe_sim_tray'");
    }
    if (ids.contains('integrator_euler_coarse_timestep') ||
        ids.contains('coarse_timestep') ||
        ids.contains('integrator_euler') ||
        ids.isEmpty) {
      buf
        ..writeln('spec.option.timestep = 0.002')
        ..writeln(
          'spec.option.integrator = mujoco.mjtIntegrator.mjINT_IMPLICITFAST',
        );
    }
    if (ids.contains('pyramidal_cone_or_low_impratio') || ids.isEmpty) {
      buf
        ..writeln('spec.option.cone = mujoco.mjtCone.mjCONE_ELLIPTIC')
        ..writeln('spec.option.impratio = 10.0');
    }
    if (ids.contains('low_condim_friction') || ids.isEmpty) {
      buf
        ..writeln('spec.default.geom.condim = 6')
        ..writeln('spec.default.geom.friction = [0.7, 0.01, 0.005]');
    }
    if (ids.contains('nonzero_geom_margin') || ids.isEmpty) {
      buf.writeln('spec.default.geom.margin = 0.0');
    }
    if (ids.contains('solref_timeconst_below_2dt') ||
        ids.contains('solref_underdamped') ||
        ids.isEmpty) {
      buf.writeln('spec.default.geom.solref = [0.02, 1.0]');
    }
    if (ids.contains('nonzero_root_offset') ||
        ids.contains('root_modelname_mismatch') ||
        ids.isEmpty) {
      buf.writeln(
        "root = spec.worldbody.add_body(name='vibe_sim_tray', pos=[0.0, 0.0, 0.0], quat=[1.0, 0.0, 0.0, 0.0])",
      );
    }
    if (ids.contains('solid_box_cavity_blocked') ||
        ids.contains('vis_col_group_not_split')) {
      buf
        ..writeln(
          '# 中空トレイは底板+4壁の5ジオムで組む（group=2 描画 / group=3 衝突を分離）',
        )
        ..writeln(
          "root.add_geom(name='tray_base_vis', type=mujoco.mjtGeom.mjGEOM_BOX, size=[0.18, 0.14, 0.008], pos=[0.0, 0.0, 0.008], group=2, contype=0, conaffinity=0, mass=0.0)",
        )
        ..writeln(
          "root.add_geom(name='tray_base_col', type=mujoco.mjtGeom.mjGEOM_BOX, size=[0.18, 0.14, 0.008], pos=[0.0, 0.0, 0.008], group=3, density=800.0)",
        );
    }
    if (input.mujoco401Compat) {
      buf
        ..writeln()
        ..writeln('# mujoco==4.0.1 / mujoco-studio==4.0.1 互換チェック')
        ..writeln(
          'spec.default.joint.damping = [0.1, 0.0, 0.0]  # スカラー 0.1 は TypeError',
        )
        ..writeln(
          'clicked = imgui.Selectable(label, selected)  # タプルではなく単一 bool',
        );
    }
    return buf.toString().trimRight();
  }
}
