/// Detached fail-closed planning experiment. This is not connected to the
/// product and cannot authenticate an owner or coordinate asynchronous IO.
enum PaymentDayDependentUse {
  legacyLoad,
  localPrune,
  remoteRestore,
  remoteMirror,
  dirtyClear,
  edit,
  display,
  planner,
  calendar,
  availableBalance,
  forecast,
  advisory,
  notification,
  export,
}

/// No data is returned; callers must not replace this with a confirmed empty
/// map or an inferred date. Real consumers do not yet handle this type.
final class PaymentDayHeld<T> {
  const PaymentDayHeld();
}

/// This model only describes the unverified state. No ready/verified factory
/// exists until a real auth and atomic storage protocol has been reviewed.
class PaymentDayUnverifiedBoundaryCandidate {
  const PaymentDayUnverifiedBoundaryCandidate();

  /// The supplied synchronous fake calculation is never called. This method
  /// is not an async side-effect fence and must not be wired into production.
  PaymentDayHeld<T> hold<T>(
    PaymentDayDependentUse use,
    T Function() syntheticCalculation,
  ) =>
      PaymentDayHeld<T>();
}
