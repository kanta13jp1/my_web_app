import 'musubi_engagement_repository.dart';
import 'musubi_social_repository.dart';
import 'musubi_supabase_service.dart';

class MusubiFeatureDependencies {
  const MusubiFeatureDependencies({
    required this.socialRepository,
    required this.realtimeRepository,
    required this.discoveryRepository,
    required this.messagingRepository,
    required this.trustRepository,
    required this.researchRepository,
  });

  final MusubiSocialRepository socialRepository;
  final MusubiRealtimeRepository realtimeRepository;
  final MusubiDiscoveryRepository discoveryRepository;
  final MusubiMessagingRepository messagingRepository;
  final MusubiTrustRepository trustRepository;
  final MusubiResearchRepository researchRepository;

  factory MusubiFeatureDependencies.production() {
    final service = MusubiSupabaseService();
    final preview = PreviewMusubiEngagementRepository();
    return MusubiFeatureDependencies(
      socialRepository: SupabaseMusubiSocialRepository(service: service),
      realtimeRepository: SupabaseMusubiRealtimeRepository(service),
      discoveryRepository: SupabaseMusubiDiscoveryRepository(service, preview),
      messagingRepository: SupabaseMusubiMessagingRepository(service, preview),
      trustRepository: SupabaseMusubiTrustRepository(service, preview),
      researchRepository: SupabaseMusubiResearchRepository(service, preview),
    );
  }

  factory MusubiFeatureDependencies.preview({
    MusubiSocialRepository? socialRepository,
  }) {
    final preview = PreviewMusubiEngagementRepository();
    return MusubiFeatureDependencies(
      socialRepository: socialRepository ?? PreviewMusubiSocialRepository(),
      realtimeRepository: preview,
      discoveryRepository: preview,
      messagingRepository: preview,
      trustRepository: preview,
      researchRepository: preview,
    );
  }
}
