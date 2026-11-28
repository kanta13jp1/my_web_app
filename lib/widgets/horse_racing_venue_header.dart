import 'package:flutter/material.dart';

/// 開催場ごとのヘッダーバナー（JRA・地方・海外の区分とレース数を表示する）。
class HorseRacingVenueHeader extends StatelessWidget {
  const HorseRacingVenueHeader({
    super.key,
    required this.venue,
    required this.raceCount,
  });

  final String venue;
  final int raceCount;

  static const Set<String> _narVenues = <String>{
    '金沢',
    '園田',
    '姫路',
    '水沢',
    '門別',
    '盛岡',
    '浦和',
    '船橋',
    '大井',
    '川崎',
    '笠松',
    '名古屋',
    '高知',
    '佐賀',
    '帯広',
    '不明',
  };

  static const Set<String> _overseasVenues = <String>{
    'シャンティン',
    'シャティン',
    'Sha Tin',
    '沙田',
  };

  @override
  Widget build(BuildContext context) {
    final isOverseas = _overseasVenues.contains(venue);
    final isJra = !isOverseas && !_narVenues.contains(venue);
    final color = isOverseas
        ? const Color(0xFF059669)
        : isJra
            ? const Color(0xFF2563EB)
            : const Color(0xFF7C3AED);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isOverseas
                ? Icons.flight_takeoff
                : isJra
                    ? Icons.stadium
                    : Icons.location_on,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              venue,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                height: 1.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isOverseas
                  ? '海外'
                  : isJra
                      ? 'JRA'
                      : '地方',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '$raceCount R',
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
