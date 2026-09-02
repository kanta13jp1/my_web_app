import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'data/notion_migration_gateway.dart';
import 'data/notion_vault_manifest_service.dart';
import 'view_models/notion_migration_view_model.dart';
import 'views/notion_migration_page.dart';

class NotionMigrationFeature extends StatelessWidget {
  const NotionMigrationFeature({
    super.key,
    this.gateway,
    this.vaultManifestPicker,
    this.vaultManifestParser,
  });

  final NotionMigrationGateway? gateway;
  final NotionVaultManifestPicker? vaultManifestPicker;
  final NotionVaultManifestParser? vaultManifestParser;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NotionMigrationViewModel>(
      create: (_) => NotionMigrationViewModel(
        gateway: gateway ?? SupabaseNotionMigrationGateway(),
        vaultManifestPicker: vaultManifestPicker,
        vaultManifestParser: vaultManifestParser,
      )..load(),
      child: const NotionMigrationPage(),
    );
  }
}
