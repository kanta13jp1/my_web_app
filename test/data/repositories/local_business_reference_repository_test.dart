import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/local_business_reference_repository.dart';
import 'package:my_web_app/data/services/local_business_reference_service.dart';

class _FakeService implements LocalBusinessReferenceService {
  int? receivedLimit;

  @override
  Future<Map<String, dynamic>> fetchReferences({int limit = 30}) async {
    receivedLimit = limit;
    return <String, dynamic>{
      'officialAggregate': <String, dynamic>{
        'soleProprietorEstablishments': 20,
      },
      'publicReference': <String, dynamic>{'businesses': const <dynamic>[]},
    };
  }
}

void main() {
  test(
    'repository delegates the bounded request and maps the snapshot',
    () async {
      final service = _FakeService();
      final repository = RemoteLocalBusinessReferenceRepository(
        service: service,
      );

      final snapshot = await repository.load(limit: 12);

      expect(service.receivedLimit, 12);
      expect(snapshot.officialAggregate.soleProprietorEstablishments, 20);
      expect(snapshot.businesses, isEmpty);
    },
  );
}
