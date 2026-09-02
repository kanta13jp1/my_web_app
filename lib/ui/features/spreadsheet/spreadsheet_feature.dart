import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/spreadsheet_repository.dart';
import '../../../data/services/spreadsheet_file_gateway.dart';
import '../../../data/services/spreadsheet_local_storage_service.dart';
import '../../../domain/use_cases/evaluate_spreadsheet_formula_use_case.dart';
import '../../../domain/use_cases/spreadsheet_csv_codec.dart';
import '../../../services/auto_save_service.dart';
import 'view_models/spreadsheet_view_model.dart';
import 'views/spreadsheet_page.dart';

class SpreadsheetFeature extends StatelessWidget {
  const SpreadsheetFeature({
    super.key,
    this.repository,
    this.fileGateway,
  });

  final SpreadsheetRepository? repository;
  final SpreadsheetFileGateway? fileGateway;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SpreadsheetViewModel>(
      create: (_) => SpreadsheetViewModel(
        repository: repository ??
            const LocalSpreadsheetRepository(
              storageService: SpreadsheetLocalStorageService(),
            ),
        evaluateFormula: const EvaluateSpreadsheetFormulaUseCase(),
        csvCodec: const SpreadsheetCsvCodec(),
        fileGateway: fileGateway ?? const FilePickerSpreadsheetFileGateway(),
        autoSaveService: AutoSaveService(),
      )..load(),
      child: const SpreadsheetPage(),
    );
  }
}
