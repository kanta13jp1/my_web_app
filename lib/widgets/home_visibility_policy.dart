class HomeVisibilityPolicy {
  const HomeVisibilityPolicy._();

  static bool showInternalOperations({
    required bool showLegacyOperations,
    required bool showLegacyHomeSections,
  }) {
    return showLegacyOperations || showLegacyHomeSections;
  }
}
