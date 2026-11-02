import '../../domain/models/local_business_reference.dart';
import '../services/local_business_reference_service.dart';

abstract interface class LocalBusinessReferenceRepository {
  Future<LocalBusinessReferenceSnapshot> load({int limit = 30});
}

class RemoteLocalBusinessReferenceRepository
    implements LocalBusinessReferenceRepository {
  const RemoteLocalBusinessReferenceRepository({required this.service});

  final LocalBusinessReferenceService service;

  @override
  Future<LocalBusinessReferenceSnapshot> load({int limit = 30}) async {
    final data = await service.fetchReferences(limit: limit);
    return LocalBusinessReferenceSnapshot.fromJson(data);
  }
}
