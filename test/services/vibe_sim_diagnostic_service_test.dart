import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/vibe_sim_diagnostic_service.dart';

void main() {
  group('VibeSimDiagnosticService presets', () {
    test('v1_naive returns score 100 danger with 8 findings', () {
      final res = VibeSimDiagnosticService.evaluate(
        VibeSimDiagnosticService.presetInput(VibeSimPreset.v1Naive),
      );
      expect(res.isValid, isTrue);
      expect(res.riskScore, 100);
      expect(res.riskLevel, VibeSimRiskLevel.danger);
      expect(res.findings.length, 8);
      expect(
        res.findings
            .where((final f) => f.severity == VibeSimSeverity.critical)
            .length,
        3,
      );
      expect(
        res.findings
            .where((final f) => f.severity == VibeSimSeverity.high)
            .length,
        3,
      );
      expect(
        res.findings
            .where((final f) => f.severity == VibeSimSeverity.warning)
            .length,
        2,
      );
    });

    test('v2_spec_tuned returns score 6 safe with 2 info findings', () {
      final res = VibeSimDiagnosticService.evaluate(
        VibeSimDiagnosticService.presetInput(VibeSimPreset.v2SpecTuned),
      );
      expect(res.isValid, isTrue);
      expect(res.riskScore, 6);
      expect(res.riskLevel, VibeSimRiskLevel.safe);
      expect(res.findings.length, 2);
      expect(
        res.findings.every((final f) => f.severity == VibeSimSeverity.info),
        isTrue,
      );
    });

    test('v3_audited returns score 0 safe with 0 findings', () {
      final res = VibeSimDiagnosticService.evaluate(
        VibeSimDiagnosticService.presetInput(VibeSimPreset.v3Audited),
      );
      expect(res.isValid, isTrue);
      expect(res.riskScore, 0);
      expect(res.riskLevel, VibeSimRiskLevel.safe);
      expect(res.findings, isEmpty);
      expect(res.snippet,
          contains('spec.default.joint.damping = [0.1, 0.0, 0.0]'));
      expect(res.snippet, contains('imgui.Selectable'));
    });
  });

  group('VibeSimDiagnosticService boundary & error validation', () {
    test('triggers Critical when solrefTimeconst < 2 * timestep', () {
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
      expect(
        res.findings.any((final f) => f.id == 'solref_timeconst_below_2dt'),
        isTrue,
      );
      expect(res.snippet, isNot(contains('mujoco==4.0.1')));
    });

    test(
        'rejects empty, non-numeric, NaN, Infinity, and out-of-range inputs cleanly',
        () {
      const baseRaw = VibeSimRawFormValues(
        timestepText: '',
        integrator: VibeSimIntegrator.implicitFast,
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
          containsAll(<String>[
            'timestep',
            'impratio',
            'rootOffsetMm',
            'geomMarginMm',
            'solrefTimeconst',
            'solrefDampratio',
          ]));
    });
  });
}
