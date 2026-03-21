import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PeopleLeaveRequest {
  final String id;
  final String employeeName;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status;
  final DateTime createdAt;

  const PeopleLeaveRequest({
    required this.id,
    required this.employeeName,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  factory PeopleLeaveRequest.fromJson(Map<String, dynamic> json) {
    return PeopleLeaveRequest(
      id: json['id']?.toString() ?? '',
      employeeName: json['employeeName']?.toString() ?? '',
      leaveType: json['leaveType']?.toString() ?? '',
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endDate: DateTime.tryParse(json['endDate']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, String> toJson() {
    return <String, String>{
      'id': id,
      'employeeName': employeeName,
      'leaveType': leaveType,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'reason': reason,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  PeopleLeaveRequest copyWith({
    String? id,
    String? employeeName,
    String? leaveType,
    DateTime? startDate,
    DateTime? endDate,
    String? reason,
    String? status,
    DateTime? createdAt,
  }) {
    return PeopleLeaveRequest(
      id: id ?? this.id,
      employeeName: employeeName ?? this.employeeName,
      leaveType: leaveType ?? this.leaveType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class PeopleLeaveRequestService {
  static const String _storageKey = 'people_leave_requests_v1';
  static const List<String> supportedStatuses = <String>[
    'pending',
    'approved',
    'declined',
  ];

  const PeopleLeaveRequestService();

  Future<List<PeopleLeaveRequest>> loadRequests({
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final encoded = store.getString(_storageKey);
    if (encoded == null || encoded.trim().isEmpty) {
      return const <PeopleLeaveRequest>[];
    }

    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      return const <PeopleLeaveRequest>[];
    }

    final requests = <PeopleLeaveRequest>[];
    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }
      final request = PeopleLeaveRequest.fromJson(
        Map<String, dynamic>.from(item),
      );
      if (request.id.isEmpty ||
          request.employeeName.isEmpty ||
          request.leaveType.isEmpty ||
          request.reason.isEmpty ||
          !supportedStatuses.contains(request.status)) {
        continue;
      }
      requests.add(request);
    }
    return _sortRequests(requests);
  }

  Future<List<PeopleLeaveRequest>> saveRequest(
    PeopleLeaveRequest request, {
    SharedPreferences? prefs,
  }) async {
    final current = await loadRequests(prefs: prefs);
    final normalized = request.copyWith(
      id: request.id.trim(),
      employeeName: request.employeeName.trim(),
      leaveType: request.leaveType.trim(),
      reason: request.reason.trim(),
      status: request.status.trim(),
    );
    if (normalized.id.isEmpty ||
        normalized.employeeName.isEmpty ||
        normalized.leaveType.isEmpty ||
        normalized.reason.isEmpty ||
        normalized.endDate.isBefore(normalized.startDate) ||
        !supportedStatuses.contains(normalized.status)) {
      return current;
    }

    final next = <PeopleLeaveRequest>[
      for (final item in current)
        if (item.id != normalized.id) item,
      normalized,
    ];
    return _persistRequests(next, prefs: prefs);
  }

  Future<List<PeopleLeaveRequest>> updateStatus(
    String requestId,
    String status, {
    SharedPreferences? prefs,
  }) async {
    if (!supportedStatuses.contains(status.trim())) {
      return loadRequests(prefs: prefs);
    }
    final current = await loadRequests(prefs: prefs);
    final next = current
        .map(
          (item) => item.id == requestId
              ? item.copyWith(status: status.trim())
              : item,
        )
        .toList();
    return _persistRequests(next, prefs: prefs);
  }

  Future<List<PeopleLeaveRequest>> _persistRequests(
    List<PeopleLeaveRequest> requests, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final sorted = _sortRequests(requests);
    final encoded = jsonEncode(
      sorted.map((request) => request.toJson()).toList(),
    );
    await store.setString(_storageKey, encoded);
    return sorted;
  }

  List<PeopleLeaveRequest> _sortRequests(List<PeopleLeaveRequest> requests) {
    final sorted = List<PeopleLeaveRequest>.from(requests);
    sorted.sort((a, b) {
      final statusCompare =
          _statusRank(a.status).compareTo(_statusRank(b.status));
      if (statusCompare != 0) {
        return statusCompare;
      }
      final startCompare = a.startDate.compareTo(b.startDate);
      if (startCompare != 0) {
        return startCompare;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  int _statusRank(String status) {
    switch (status) {
      case 'pending':
        return 0;
      case 'approved':
        return 1;
      case 'declined':
        return 2;
      default:
        return 3;
    }
  }
}
