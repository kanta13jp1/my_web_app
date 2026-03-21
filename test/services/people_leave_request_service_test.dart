import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/people_leave_request_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('saves requests, sorts pending first, and updates status', () async {
    const service = PeopleLeaveRequestService();
    final prefs = await SharedPreferences.getInstance();

    await service.saveRequest(
      PeopleLeaveRequest(
        id: 'approved-request',
        employeeName: 'Ken',
        leaveType: 'Paid leave',
        startDate: DateTime(2026, 4, 2),
        endDate: DateTime(2026, 4, 2),
        reason: 'Personal errand',
        status: 'approved',
        createdAt: DateTime(2026, 3, 20, 9),
      ),
      prefs: prefs,
    );
    final saved = await service.saveRequest(
      PeopleLeaveRequest(
        id: 'pending-request',
        employeeName: 'Aiko',
        leaveType: 'Sick leave',
        startDate: DateTime(2026, 3, 25),
        endDate: DateTime(2026, 3, 26),
        reason: 'Medical appointment',
        status: 'pending',
        createdAt: DateTime(2026, 3, 20, 10),
      ),
      prefs: prefs,
    );

    expect(saved.map((request) => request.id).toList(), <String>[
      'pending-request',
      'approved-request',
    ]);

    final updated = await service.updateStatus(
      'pending-request',
      'approved',
      prefs: prefs,
    );

    expect(updated.map((request) => request.id).toList(), <String>[
      'pending-request',
      'approved-request',
    ]);
    expect(
      updated.where((request) => request.id == 'pending-request').single.status,
      'approved',
    );
  });
}
