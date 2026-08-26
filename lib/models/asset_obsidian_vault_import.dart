enum AssetObsidianImportStatus {
  newAccount,
  update,
  unchanged,
  stale,
  conflict,
}

class AssetObsidianVaultFile {
  const AssetObsidianVaultFile({
    required this.relativePath,
    required this.content,
    required this.byteSize,
    this.lastModified,
  });

  final String relativePath;
  final String content;
  final int byteSize;
  final DateTime? lastModified;
}

class AssetObsidianVaultSelection {
  const AssetObsidianVaultSelection({
    required this.vaultName,
    required this.files,
  });

  final String vaultName;
  final List<AssetObsidianVaultFile> files;
}

class AssetObsidianVaultPickerException implements Exception {
  const AssetObsidianVaultPickerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AssetObsidianExistingBalance {
  const AssetObsidianExistingBalance({
    required this.accountName,
    required this.observedDate,
    required this.amount,
  });

  final String accountName;
  final DateTime observedDate;
  final double amount;
}

class AssetObsidianImportCandidate {
  const AssetObsidianImportCandidate({
    required this.accountName,
    required this.sourceAccountName,
    required this.observedDate,
    required this.amount,
    required this.status,
    required this.sourcePaths,
    this.existingAmount,
    this.existingObservedDate,
    this.conflictingAmounts = const <double>[],
  });

  final String accountName;
  final String sourceAccountName;
  final DateTime observedDate;
  final double amount;
  final AssetObsidianImportStatus status;
  final List<String> sourcePaths;
  final double? existingAmount;
  final DateTime? existingObservedDate;
  final List<double> conflictingAmounts;

  String get id =>
      '${accountName}_${observedDate.toIso8601String()}_${amount.toStringAsFixed(2)}';

  bool get isImportable =>
      status == AssetObsidianImportStatus.newAccount ||
      status == AssetObsidianImportStatus.update;
}

class AssetObsidianImportPreview {
  const AssetObsidianImportPreview({
    required this.scannedFileCount,
    required this.recognizedFileCount,
    required this.candidates,
    required this.warnings,
  });

  final int scannedFileCount;
  final int recognizedFileCount;
  final List<AssetObsidianImportCandidate> candidates;
  final List<String> warnings;

  List<AssetObsidianImportCandidate> get initiallySelected => candidates
      .where((candidate) => candidate.isImportable)
      .toList(growable: false);
}
