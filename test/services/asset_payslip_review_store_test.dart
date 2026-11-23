import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/services/asset_payslip_review_store.dart';
import '../../integration_test/payslip_review_fixture.dart';
import '../main_test.mocks.dart';

void main() {
  test('snapshot is immutable and watches every original value and version',
      () {
    final source = syntheticPayslip();
    final first = PayslipReviewSnapshot(source);
    (source['deductions'] as Map)['income_tax'] = 999;
    expect((first.raw['deductions'] as Map)['income_tax'], 50);
    expect(
      () => (first.raw['deductions'] as Map)['income_tax'] = 999,
      throwsUnsupportedError,
    );
    expect(
      first.sameVersion(PayslipReviewSnapshot(syntheticPayslip())),
      isTrue,
    );
    for (final changed in [
      {...syntheticPayslip(), 'updated_at': '2030-02-01T00:00:00Z'},
      {...syntheticPayslip(), 'review_status': 'confirmed'},
      {...syntheticPayslip(), 'net_amount': 701},
      {
        ...syntheticPayslip(),
        'attendance': {'work_days': 19},
      },
    ]) {
      expect(first.sameVersion(PayslipReviewSnapshot(changed)), isFalse);
    }
  });
  test('private PDF paths stay in the explicit owners folder', () {
    expect(
      payslipPrivateObjectPath(
        'payslips/synthetic-owner/a.pdf',
        'synthetic-owner',
      ),
      'synthetic-owner/a.pdf',
    );
    for (final path in [
      'other/a.pdf',
      'synthetic-owner/../a.pdf',
      'synthetic-owner/%2e%2e/a.pdf',
      'synthetic-owner/%2fother/a.pdf',
      'https://example.invalid/a.pdf',
    ]) {
      expect(
        () => payslipPrivateObjectPath(path, 'synthetic-owner'),
        throwsFormatException,
      );
    }
  });
  test('owner CAS changes only review status and rejects stale raw values',
      () async {
    var data = syntheticPayslip();
    final requests = <http.Request>[];
    var raceAfterRead = false;
    var clearOwnerAfterRead = false;
    User? owner = const User(
      id: 'synthetic-owner',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2030-01-01',
    );
    final transport = SupabaseClient(
      'https://example.invalid',
      'synthetic-public-key',
      accessToken: () async => 'synthetic-user-jwt',
      httpClient: MockClient((request) async {
        requests.add(request);
        final query = request.url.queryParameters;
        var rows = <Map<String, dynamic>>[];
        if (query['user_id'] == 'eq.synthetic-owner' &&
            query['id'] == 'eq.synthetic-statement') {
          if (request.method == 'PATCH') {
            expect(jsonDecode(request.body), {'review_status': 'confirmed'});
            expect(query['review_status'], 'eq.auto');
            expect(query['raw_text_sha256'], 'eq.synthetic-hash');
            if (query['updated_at'] == 'eq.${data['updated_at']}') {
              data = {
                ...data,
                'review_status': 'confirmed',
                'updated_at': '2030-01-20T00:00:01Z',
              };
              rows = [data];
            }
          } else {
            rows = [Map<String, dynamic>.from(data)];
            if (raceAfterRead) {
              data = {
                ...data,
                'net_amount': 701,
                'updated_at': '2030-01-20T00:00:02Z',
              };
            }
            if (clearOwnerAfterRead) owner = null;
          }
        }
        final objectResponse =
            request.headers['accept']?.contains('vnd.pgrst.object') ?? false;
        if (objectResponse && rows.isEmpty) {
          return http.Response(
            jsonEncode({
              'code': 'PGRST116',
              'details': 'The result contains 0 rows',
              'hint': null,
              'message':
                  'JSON object requested, multiple (or no) rows returned',
            }),
            406,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response(
          jsonEncode(objectResponse && rows.isNotEmpty ? rows.single : rows),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(transport.dispose);
    final client = MockSupabaseClient();
    final auth = MockGoTrueClient();
    when(client.auth).thenReturn(auth);
    when(auth.currentUser).thenAnswer((_) => owner);
    when(client.from('payslips')).thenAnswer((_) => transport.from('payslips'));
    final store = SupabasePayslipReviewStore(client, 'synthetic-owner');
    final before = await store.load('synthetic-statement');
    final getCount = requests.length;
    await expectLater(
      store.confirm(before, confirmedDisplayedValues: false),
      throwsStateError,
    );
    expect(requests.length, getCount);
    await store.confirm(before, confirmedDisplayedValues: true);
    expect(data['net_amount'], 700);
    expect((data['deductions'] as Map)['income_tax'], 50);
    expect(requests.where((r) => r.method == 'PATCH').length, 1);
    await expectLater(
      store.confirm(before, confirmedDisplayedValues: true),
      throwsStateError,
    );
    expect(requests.where((r) => r.method == 'PATCH').length, 1);
    data = syntheticPayslip();
    raceAfterRead = true;
    await expectLater(
      store.confirm(before, confirmedDisplayedValues: true),
      throwsA(isA<PostgrestException>()),
    );
    expect(data['review_status'], 'auto');
    expect(data['net_amount'], 701);
    raceAfterRead = false;
    data = syntheticPayslip();
    clearOwnerAfterRead = true;
    final patchCount = requests.where((r) => r.method == 'PATCH').length;
    await expectLater(
      store.confirm(before, confirmedDisplayedValues: true),
      throwsStateError,
    );
    expect(requests.where((r) => r.method == 'PATCH').length, patchCount);
    expect(requests.every((r) => r.url.path == '/rest/v1/payslips'), isTrue);
  });
  test('blockingReasonAt enforces alias conflicts and future pay_date guard',
      () {
    final jpRow = syntheticPayslip()
      ..['pay_date'] = '2030-05-25'
      ..['social_insurance_total'] = 86500
      ..['deductions'] = {
        '所得税': 29500,
        '住民税': 29000,
        '健康保険料': 28000,
        '介護保険料': 4500,
        '厚生年金保険料': 51000,
        '雇用保険料': 3000,
        '厚生年金基金掛金': 0,
        'IDECO': 0,
      };
    final jpSnapshot = PayslipReviewSnapshot(jpRow);
    expect(jpSnapshot.blockingReason, isNull);
    expect(
      jpSnapshot.blockingReasonAt(asOfDate: DateTime(2030, 5, 25)),
      isNull,
    );
    expect(
      jpSnapshot.blockingReasonAt(asOfDate: DateTime(2030, 5, 24, 23, 59)),
      contains('支給日（2030-05-25）が未到来'),
    );

    final taxConflictRow = syntheticPayslip();
    (taxConflictRow['deductions'] as Map)['所得税'] = 55;
    final conflictSnapshot = PayslipReviewSnapshot(taxConflictRow);
    expect(
      conflictSnapshot.blockingReason,
      '控除の項目名違いが競合しています。元値の訂正が必要です。',
    );
  });
}
