import 'package:flutter/widgets.dart';

import '../data/repositories/spreadsheet_repository.dart';
import '../data/services/spreadsheet_file_gateway.dart';
import '../ui/features/spreadsheet/spreadsheet_feature.dart';

/// Compatibility wrapper for the existing `/spreadsheet-database` route.
class SpreadsheetDatabasePage extends StatelessWidget {
  const SpreadsheetDatabasePage({
    super.key,
    this.repository,
    this.fileGateway,
  });

  final SpreadsheetRepository? repository;
  final SpreadsheetFileGateway? fileGateway;

  @override
  Widget build(BuildContext context) {
    return SpreadsheetFeature(
      repository: repository,
      fileGateway: fileGateway,
    );
  }
}
