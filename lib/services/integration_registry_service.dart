import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/integration_registry.dart';

abstract interface class IntegrationRegistryServiceContract {
  Future<IntegrationRegistrySnapshot> loadSnapshot();

  Future<IntegrationSystemDefinition> saveSystem(IntegrationSystemDraft draft);

  Future<IntegrationInterfaceDefinition> publishInterface(
    IntegrationInterfaceDraft draft,
  );

  Future<IntegrationCodeMappingSet> importMappings(
    IntegrationMappingImportDraft draft,
  );

  Future<IntegrationImpactReport> analyzeImpact(String systemKey);
}

class SupabaseIntegrationRegistryService
    implements IntegrationRegistryServiceContract {
  const SupabaseIntegrationRegistryService({SupabaseClient? client})
      : _clientOverride = client;

  static const String referenceApiAction = 'api.integrations.snapshot';

  final SupabaseClient? _clientOverride;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  @override
  Future<IntegrationRegistrySnapshot> loadSnapshot() async {
    final data = await _invoke(
      'integration.registry.snapshot',
      const <String, dynamic>{},
    );
    return IntegrationRegistrySnapshot.fromJson(data);
  }

  @override
  Future<IntegrationSystemDefinition> saveSystem(
    IntegrationSystemDraft draft,
  ) async {
    final data = await _invoke(
      'integration.registry.system.save',
      draft.toJson(),
    );
    return IntegrationSystemDefinition.fromJson(_requiredMap(data, 'system'));
  }

  @override
  Future<IntegrationInterfaceDefinition> publishInterface(
    IntegrationInterfaceDraft draft,
  ) async {
    final data = await _invoke(
      'integration.registry.interface.publish',
      draft.toJson(),
    );
    return IntegrationInterfaceDefinition.fromJson(
      _requiredMap(data, 'interface'),
    );
  }

  @override
  Future<IntegrationCodeMappingSet> importMappings(
    IntegrationMappingImportDraft draft,
  ) async {
    final data = await _invoke(
      'integration.registry.mapping.import',
      draft.toJson(),
    );
    return IntegrationCodeMappingSet.fromJson(_requiredMap(data, 'mapping'));
  }

  @override
  Future<IntegrationImpactReport> analyzeImpact(String systemKey) async {
    final data = await _invoke('integration.registry.impact', <String, dynamic>{
      'system_key': systemKey,
    });
    return IntegrationImpactReport.fromJson(_requiredMap(data, 'impact'));
  }

  Future<Map<String, dynamic>> _invoke(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.functions.invoke(
      'enterprise-hub',
      body: <String, dynamic>{'action': action, ...payload},
    );
    final data = _asMap(response.data);
    if (data['success'] != true) {
      throw StateError(
        data['error']?.toString() ?? 'Integration registry request failed.',
      );
    }
    return data;
  }

  Map<String, dynamic> _requiredMap(Map<String, dynamic> parent, String key) {
    final value = parent[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw StateError('Integration registry response is missing "$key".');
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw StateError('Integration registry returned an invalid response.');
  }
}
