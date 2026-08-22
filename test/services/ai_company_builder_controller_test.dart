import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_company_builder_controller.dart';
import 'package:my_web_app/services/ai_company_builder_service.dart';

class _FakeCompanyBuilderService extends AiCompanyBuilderService {
  final List<String> commands = <String>[];
  final List<String> researchUrls = <String>[];
  bool globalKillEnabled = false;
  bool latestPassed = true;
  void Function()? onChange;

  @override
  bool get isSignedIn => true;

  @override
  Future<List<Map<String, dynamic>>> listCompanies() async => [
        {
          'id': 'company-1',
          'metadata': {'company_name': 'Signal School', 'passed': latestPassed},
        },
      ];

  @override
  Future<Map<String, dynamic>> getCompany(String companyId) async =>
      _companyDetail(
        state:
            latestPassed ? (commands.isEmpty ? 'idle' : 'running') : 'blocked',
        passed: latestPassed,
      );

  @override
  Future<Map<String, dynamic>> bootstrap({
    required String idea,
    required double threshold,
  }) async {
    latestPassed = false;
    return _companyDetail(state: 'blocked', passed: false);
  }

  @override
  Future<Map<String, dynamic>> runtimeCommand({
    required String companyId,
    required String command,
  }) async {
    commands.add(command);
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> setGlobalKillSwitch({
    required bool enabled,
  }) async {
    globalKillEnabled = enabled;
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> addResearchSource({
    required String companyId,
    required String sourceUrl,
  }) async {
    researchUrls.add(sourceUrl);
    return {'success': true};
  }

  @override
  void subscribe(String companyId, void Function() onChange) {
    this.onChange = onChange;
  }

  @override
  Future<void> dispose() async {}
}

Map<String, dynamic> _companyDetail({
  required String state,
  bool passed = true,
}) {
  return {
    'company': {
      'id': 'company-1',
      'metadata': {
        'company_name': 'Signal School',
        'passed': passed,
        'status': passed ? 'approved' : 'revise',
      },
    },
    'manager_agents': <Map<String, dynamic>>[],
    'tool_agents': <Map<String, dynamic>>[],
    'tasks': <Map<String, dynamic>>[],
    'vault_notes': <Map<String, dynamic>>[],
    'audit_entries': <Map<String, dynamic>>[],
    'runtime_events': <Map<String, dynamic>>[],
    'runtime_control': {'state': state, 'kill_switch': false},
    'runtime_master_control': {'kill_switch': false},
  };
}

Map<String, dynamic> _childMap(Map<String, dynamic>? source, String key) {
  final value = source?[key];
  return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

void main() {
  test(
    'loads a company and routes runtime commands through the service',
    () async {
      final service = _FakeCompanyBuilderService();
      final controller = AiCompanyBuilderController(service: service);

      await controller.loadCompanies();
      expect(controller.selectedCompanyId, 'company-1');
      expect(_childMap(controller.detail, 'runtime_control')['state'], 'idle');

      await controller.runCommand('start');
      expect(service.commands, ['start']);
      expect(
        _childMap(controller.detail, 'runtime_control')['state'],
        'running',
      );

      controller.dispose();
    },
  );

  test('keeps a gate rejection as a visible blocked company', () async {
    final service = _FakeCompanyBuilderService();
    final controller = AiCompanyBuilderController(service: service);

    final created = await controller.bootstrap(
      idea: 'A broad idea that should be narrowed',
      threshold: 9,
    );

    expect(created, isTrue);
    final company = _childMap(controller.detail, 'company');
    expect(_childMap(company, 'metadata')['passed'], isFalse);
    expect(_childMap(controller.detail, 'runtime_control')['state'], 'blocked');
    expect(controller.errorMessage, isNull);

    controller.dispose();
  });

  test('validates and ingests a company research source', () async {
    final service = _FakeCompanyBuilderService();
    final controller = AiCompanyBuilderController(service: service);
    await controller.loadCompanies();

    expect(await controller.addResearchSource('file:///private'), isFalse);
    expect(controller.errorMessage, contains('HTTP or HTTPS'));
    expect(await controller.addResearchSource('https:missing-host'), isFalse);
    expect(
      await controller.addResearchSource('https://example.com/research'),
      isTrue,
    );
    expect(service.researchUrls, ['https://example.com/research']);
    expect(controller.isResearchBusy, isFalse);

    controller.dispose();
  });
}
