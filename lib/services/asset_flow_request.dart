import 'package:supabase_flutter/supabase_flutter.dart';

/// Compatibility marker only. Ownership remains enforced by server RLS.
class AssetFlowRequest {
  static const headerName = 'x-asset-flow-version';
  static const headerValue = 'borrowing-v1';

  static PostgrestQueryBuilder<dynamic> table(SupabaseClient client) =>
      client.from('wealth_struggles').setHeader(headerName, headerValue);
}
