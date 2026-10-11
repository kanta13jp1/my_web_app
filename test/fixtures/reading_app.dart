import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_web_app/data/repositories/reading_repository.dart';
import 'package:my_web_app/pages/reading_list_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FixtureRepository extends SupabaseReadingRepository {
  _FixtureRepository(this.guest) : super(SupabaseClient('http://127.0.0.1:7359', 'reading-fixture-public-key'));
  final bool guest;
  @override
  String? get sessionKey => guest ? null : '33333333-3333-4333-8333-333333333333';
  @override
  Stream<void> get authChanges => const Stream.empty();
}

void main() {
  WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  runApp(MaterialApp(
    theme: ThemeData(colorSchemeSeed: Colors.indigo, fontFamily: 'NotoSansJP'),
    routes: {'/login': (_) => const Scaffold(body: Text('ログイン入口'))},
    home: ReadingListPage(repository: _FixtureRepository(Uri.base.queryParameters['guest'] == '1')),
  ));
}
