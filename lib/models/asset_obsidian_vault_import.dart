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

class AssetObsidianExistingSubscription {
  const AssetObsidianExistingSubscription({
    required this.id,
    required this.name,
    required this.amount,
  });

  final String id;
  final String name;
  final double amount;
}

enum AssetObsidianSubscriptionCancellationStatus {
  matched,
  notRegistered,
  conflict,
}

class AssetObsidianSubscriptionCancellationCandidate {
  const AssetObsidianSubscriptionCancellationCandidate({
    required this.sourceSubscriptionName,
    required this.sourceStatus,
    required this.status,
    required this.sourcePaths,
    this.endedAt,
    this.matchedSubscriptionId,
    this.matchedSubscriptionName,
    this.matchedMonthlyAmount,
    this.conflictingSubscriptionNames = const <String>[],
  });

  final String sourceSubscriptionName;
  final String sourceStatus;
  final String? endedAt;
  final AssetObsidianSubscriptionCancellationStatus status;
  final List<String> sourcePaths;
  final String? matchedSubscriptionId;
  final String? matchedSubscriptionName;
  final double? matchedMonthlyAmount;
  final List<String> conflictingSubscriptionNames;

  String get id {
    final target = matchedSubscriptionId ?? sourceSubscriptionName;
    return 'subscription-cancellation_${status.name}_'
        '${target.length}:${target}_'
        '${sourceSubscriptionName.length}:$sourceSubscriptionName';
  }

  bool get isDeletable =>
      status == AssetObsidianSubscriptionCancellationStatus.matched &&
      (matchedSubscriptionId?.trim().isNotEmpty ?? false);
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
    this.recognizedCancellationFileCount = 0,
    this.subscriptionCancellations =
        const <AssetObsidianSubscriptionCancellationCandidate>[],
  });

  final int scannedFileCount;
  final int recognizedFileCount;
  final int recognizedCancellationFileCount;
  final List<AssetObsidianImportCandidate> candidates;
  final List<AssetObsidianSubscriptionCancellationCandidate>
      subscriptionCancellations;
  final List<String> warnings;

  List<AssetObsidianImportCandidate> get initiallySelected => candidates
      .where((candidate) => candidate.isImportable)
      .toList(growable: false);

  List<AssetObsidianSubscriptionCancellationCandidate>
      get initiallySelectedSubscriptionCancellations =>
          subscriptionCancellations
              .where((candidate) => candidate.isDeletable)
              .toList(growable: false);
}

class AssetObsidianApplySelection {
  const AssetObsidianApplySelection({
    this.balances = const <AssetObsidianImportCandidate>[],
    this.subscriptionCancellations =
        const <AssetObsidianSubscriptionCancellationCandidate>[],
  });

  final List<AssetObsidianImportCandidate> balances;
  final List<AssetObsidianSubscriptionCancellationCandidate>
      subscriptionCancellations;

  int get totalCount => balances.length + subscriptionCancellations.length;
}
