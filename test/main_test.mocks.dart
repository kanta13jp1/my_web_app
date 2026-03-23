// ignore_for_file: must_be_immutable

import 'package:mockito/mockito.dart';
import 'package:my_web_app/services/theme_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder<T> extends Mock
    implements PostgrestFilterBuilder<T> {}

class MockPostgrestTransformBuilder<T> extends Mock
    implements PostgrestTransformBuilder<T> {}

class MockThemeService extends Mock implements ThemeService {}

class MockUser extends Mock implements User {}

class MockSession extends Mock implements Session {}
