import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

abstract interface class LocalBusinessReferenceService {
  Future<Map<String, dynamic>> fetchReferences({int limit = 30});
}

class SupabaseLocalBusinessReferenceService
    implements LocalBusinessReferenceService {
  SupabaseLocalBusinessReferenceService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> fetchReferences({int limit = 30}) async {
    final response = await _client.functions.invoke(
      'tools-hub',
      body: <String, dynamic>{
        'action': 'public_businesses.reference_list',
        'target_id': 'fuchu-honmachi-1',
        'limit': limit.clamp(1, 50),
      },
    );
    final data = _map(response.data);
    if (response.status < 200 ||
        response.status >= 300 ||
        data['success'] != true) {
      final error = data['error']?.toString().trim();
      throw LocalBusinessReferenceException(
        error == null || error.isEmpty ? 'HTTP ${response.status}' : error,
      );
    }
    return data;
  }
}

abstract interface class LocalBusinessReferenceLinkService {
  Future<bool> open(Uri uri);
}

class UrlLauncherLocalBusinessReferenceLinkService
    implements LocalBusinessReferenceLinkService {
  const UrlLauncherLocalBusinessReferenceLinkService();

  @override
  Future<bool> open(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class LocalBusinessReferenceException implements Exception {
  const LocalBusinessReferenceException(this.message);

  final String message;

  @override
  String toString() => message;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is! Map) return <String, dynamic>{};
  return value.map((key, item) => MapEntry(key.toString(), item));
}
