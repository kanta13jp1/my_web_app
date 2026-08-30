import 'package:my_web_app/models/asset_obsidian_vault_import.dart';

bool get isAssetObsidianVaultPickerSupported => false;

Future<AssetObsidianVaultSelection?> pickAssetObsidianVault() async {
  throw const AssetObsidianVaultPickerException(
    'Obsidian保管庫の選択はWeb版で利用できます。',
  );
}
