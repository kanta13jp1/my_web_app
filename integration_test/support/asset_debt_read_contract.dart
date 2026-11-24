import 'package:flutter/widgets.dart';

enum DebtReadScenario { existing, failed, missing }

/// Only synthetic boundary inputs, observations, and completion barriers.
abstract interface class DebtReadHarness {
  String get id;
  Widget root();
  Future<void> get readStarted;
  void respond();
  Future<void> waitRestore();
  Future<void> waitBackfills();
  Future<void> waitSaves();
  Future<void> waitWrites();
  List<String> get owners;
  List<Map<String, int>> get writes;
  List<Map<String, int>> get saves;
  int get errorsEmitted;
}
