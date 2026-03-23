// ignore_for_file: must_be_immutable

import 'package:mockito/mockito.dart';
import 'package:my_web_app/services/theme_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

class MockFunctionResponse extends Mock implements FunctionResponse {}

class MockThemeService extends Mock implements ThemeService {}
