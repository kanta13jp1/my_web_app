import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await Supabase.initialize(
    url: 'http://127.0.0.1:9999',
    publishableKey: 'test-publishable-key',
    authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
  );
  SemanticsBinding.instance.ensureSemantics();
  runApp(
    MaterialApp(
      home: AssetManagementPage(
        debugNow: DateTime(2026, 6, 20),
        debugCalendarNow: DateTime(2026, 6, 20),
        debugInitialAssetData: const {
          '2026-06-20': {'Synthetic bank': 1000, 'SyntheticLoan': -10000},
        },
      ),
    ),
  );
}
