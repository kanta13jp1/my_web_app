import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/vibe_sim_diagnostic_service.dart';

void main() {
  group('VibeSimDiagnosticService presets', () {
    test('v1_naive returns danger with 6 Tier 1 FAILs and 3 Tier 2 INFOs', () {
      final res = VibeSimDiagnosticService.evaluate(
        VibeSimDiagnosticService.presetInput(VibeSimPreset.v1Naive),
      );
      expect(res.isValid, isTrue);
      expect(res.riskLevel, VibeSimRiskLevel.danger);
      expect(res.tier1FailCount, 6);
      expect(res.tier2InfoCount, 3);
      expect(res.findings.length, 9);
      expect(
        res.findings
            .where((final f) => f.tier == VibeSimAuditTier.tier1Fail)
            .length,
        6,
      );
      expect(
        res.findings
            .where((final f) => f.tier == VibeSimAuditTier.tier2Info)
            .length,
        3,
      );
    });

    test('v2_spec_tuned returns caution (0 Tier 1, 3 Tier 2)', () {
      final res = VibeSimDiagnosticService.evaluate(
        VibeSimDiagnosticService.presetInput(VibeSimPreset.v2SpecTuned),
      );
      expect(res.isValid, isTrue);
      expect(res.riskLevel, VibeSimRiskLevel.caution);
      expect(res.tier1FailCount, 0);
      expect(res.tier2InfoCount, 3);
      expect(res.findings.length, 3);
      expect(
        res.findings.every((final f) => f.tier == VibeSimAuditTier.tier2Info),
        isTrue,
      );
    });

    test('v3_audited returns safe with 0 Tier 1 and 0 Tier 2 findings', () {
      final res = VibeSimDiagnosticService.evaluate(
        VibeSimDiagnosticService.presetInput(VibeSimPreset.v3Audited),
      );
      expect(res.isValid, isTrue);
      expect(res.riskLevel, VibeSimRiskLevel.safe);
      expect(res.tier1FailCount, 0);
      expect(res.tier2InfoCount, 0);
      expect(res.findings, isEmpty);
      expect(res.snippet, contains('mjINT_DISCRETE'));
      expect(res.snippet, contains('solref = [0.005, 1.0]'));
      expect(res.snippet, contains('spec.attach('));
      expect(
        res.snippet,
        contains('spec.default.joint.damping = [0.1, 0.0, 0.0]'),
      );
      expect(res.snippet, contains('imgui.Selectable'));
    });
  });

  group('VibeSimDiagnosticService boundary & error validation', () {
    test('triggers Tier 1 FAIL when solrefTimeconst < 2 * timestep', () {
      final base = VibeSimDiagnosticService.presetInput(
        VibeSimPreset.v3Audited,
      );
      final tweaked = VibeSimInput(
        timestep: 0.005,
        integrator: base.integrator,
        condim: base.condim,
        cone: base.cone,
        impratio: base.impratio,
        trayGeometryMode: base.trayGeometryMode,
        rootOffsetMm: base.rootOffsetMm,
        rootMatchesModelName: base.rootMatchesModelName,
        geomMarginMm: base.geomMarginMm,
        solrefTimeconst: 0.009,
        solrefDampratio: base.solrefDampratio,
        mujoco401Compat: false,
      );
      final res = VibeSimDiagnosticService.evaluate(tweaked);
      expect(res.tier1FailCount, 1);
      expect(
        res.findings.any((final f) => f.id == 'solref_timeconst_below_2dt'),
        isTrue,
      );
      expect(res.snippet, isNot(contains('mujoco==4.0.1')));
    });

    test(
      'rejects empty, non-numeric, NaN, Infinity, and out-of-range inputs',
      () {
        const baseRaw = VibeSimRawFormValues(
          timestepText: '',
          integrator: VibeSimIntegrator.discrete,
          condim: 6,
          cone: VibeSimCone.elliptic,
          impratioText: 'abc',
          trayGeometryMode: VibeSimTrayGeometryMode.fiveWallVisColSplit,
          rootOffsetMmText: 'NaN',
          rootMatchesModelName: true,
          geomMarginMmText: 'Infinity',
          solrefTimeconstText: '-0.01',
          solrefDampratioText: '99.0',
          mujoco401Compat: true,
        );
        final res = VibeSimDiagnosticService.evaluateRaw(baseRaw);
        expect(res.isValid, isFalse);
        expect(res.input, isNull);
        expect(
          res.validationErrors.keys,
          containsAll(
            const <String>[
              'timestep',
              'impratio',
              'rootOffsetMm',
              'geomMarginMm',
              'solrefTimeconst',
              'solrefDampratio',
            ],
          ),
        );
      },
    );
  });
}
