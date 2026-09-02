import 'package:flutter/material.dart';

import 'data/repositories/spreadsheet_repository.dart';
import 'data/services/spreadsheet_file_gateway.dart';
import 'ui/features/spreadsheet/spreadsheet_feature.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JibunSpreadsheetApp());
}

/// Windows向けにブラウザ専用機能を含めず、表計算機能だけを起動するアプリ。
class JibunSpreadsheetApp extends StatelessWidget {
  const JibunSpreadsheetApp({super.key, this.repository, this.fileGateway});

  final SpreadsheetRepository? repository;
  final SpreadsheetFileGateway? fileGateway;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jibun Spreadsheet',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF166534),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        useMaterial3: true,
      ),
      home: SpreadsheetFeature(
        repository: repository,
        fileGateway: fileGateway,
      ),
    );
  }
}
