/// Input-token estimates only: no network calls or actual billing claims.
class JevInputCostComparison {
  const JevInputCostComparison({
    required this.beforeUsd,
    required this.afterUsd,
  });

  final double beforeUsd;
  final double afterUsd;
  double get differenceUsd => afterUsd - beforeUsd;

  static JevInputCostComparison calculate({
    required int beforeTokens,
    required int afterTokens,
    required int requests,
    required double usdPerMillionTokens,
  }) {
    if (beforeTokens < 0 || afterTokens < 0 || requests < 1 ||
        beforeTokens > 1000000000 || afterTokens > 1000000000 ||
        requests > 1000000000 || !usdPerMillionTokens.isFinite ||
        usdPerMillionTokens < 0 || usdPerMillionTokens > 1000000) {
      throw ArgumentError('入力トークンは0以上、回数は1以上、単価は有限の0以上で指定してください。');
    }
    return JevInputCostComparison(
      beforeUsd: beforeTokens * requests * usdPerMillionTokens / 1000000,
      afterUsd: afterTokens * requests * usdPerMillionTokens / 1000000,
    );
  }
}
