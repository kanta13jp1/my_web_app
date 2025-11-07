import 'package:flutter/material.dart';
import '../models/campaign.dart';

/// アクティブなキャンペーンを表示するバナー
class CampaignsBanner extends StatelessWidget {
  const CampaignsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // 現在アクティブなキャンペーンを取得（デモ用）
    final campaigns = [
      Campaign.createWelcomeCampaign(),
      Campaign.createShareCampaign(),
      Campaign.createReferralCampaign(),
    ].where((c) => c.isCurrentlyActive).toList();

    if (campaigns.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: campaigns.length,
        itemBuilder: (context, index) {
          final campaign = campaigns[index];
          return _buildCampaignCard(context, campaign);
        },
      ),
    );
  }

  Widget _buildCampaignCard(BuildContext context, Campaign campaign) {
    Color getBannerColor(String type) {
      switch (type) {
        case 'registration_boost':
          return Colors.purple;
        case 'share_boost':
          return Colors.blue;
        case 'referral_boost':
          return Colors.green;
        default:
          return Colors.orange;
      }
    }

    final color = getBannerColor(campaign.campaignType);

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color,
            color.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 内容
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        campaign.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '残り${campaign.daysRemaining}日',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    campaign.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 13,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // 装飾パターン
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.campaign,
              size: 80,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}
