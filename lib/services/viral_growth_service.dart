import 'package:share_plus/share_plus.dart';
import 'gamification_service.dart';

class ViralGrowthService {
  final GamificationService _gamificationService;

  ViralGrowthService(this._gamificationService);

  Future<void> shareApp() async {
    await Share.share('Check out Me Inc. app!');
    await _gamificationService.awardPoints(30, reason: "App Share");
  }

  Future<void> handleReferral(String code) async {
    await _gamificationService.awardPoints(500, reason: "Referral Bonus");
  }
}
