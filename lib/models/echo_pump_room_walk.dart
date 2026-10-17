import 'dart:math' as math;

enum EchoRoomTarget { memo, door }

class EchoRoomPoint {
  const EchoRoomPoint(this.x, this.y);
  final double x, y;

  double distanceTo(EchoRoomPoint other) =>
      math.sqrt(math.pow(x - other.x, 2) + math.pow(y - other.y, 2));
}

/// Local presentation coordinates. This never advances the turn-based game.
abstract final class EchoPumpRoomWalk {
  static const start = EchoRoomPoint(0.24, 0.9);
  static const destinations = {
    EchoRoomTarget.memo: EchoRoomPoint(0.22, 0.76),
    EchoRoomTarget.door: EchoRoomPoint(0.82, 0.88),
  };

  /// Side aisles and a lower cross-aisle leave the central equipment blocked.
  static bool isWalkable(EchoRoomPoint p) =>
      p.x.isFinite && p.y.isFinite &&
      p.x >= 0.12 && p.x <= 0.88 && p.y >= 0.6 && p.y <= 0.92 &&
      (p.x <= 0.28 || p.x >= 0.72 || p.y >= 0.86);

  static List<EchoRoomPoint> route(EchoRoomPoint from, EchoRoomTarget target) {
    if (!isWalkable(from)) throw ArgumentError('Outside the room aisles');
    final to = destinations[target]!;
    if (from.distanceTo(to) < 0.00001) return [from];
    final points = [from, EchoRoomPoint(from.x, 0.9), EchoRoomPoint(to.x, 0.9), to];
    final result = <EchoRoomPoint>[];
    for (final point in points) {
      if (result.isEmpty || result.last.distanceTo(point) > 0.00001) {
        result.add(point);
      }
    }
    return result;
  }

  static double length(List<EchoRoomPoint> route) {
    var result = 0.0;
    for (var i = 1; i < route.length; i++) {
      result += route[i - 1].distanceTo(route[i]);
    }
    return result;
  }

  static EchoRoomPoint sample(List<EchoRoomPoint> route, double progress) {
    if (route.isEmpty) throw ArgumentError('Empty route');
    var remaining = length(route) * progress.clamp(0.0, 1.0);
    for (var i = 1; i < route.length; i++) {
      final from = route[i - 1], to = route[i];
      final distance = from.distanceTo(to);
      if (remaining <= distance && distance > 0) {
        final t = remaining / distance;
        return EchoRoomPoint(from.x + (to.x - from.x) * t, from.y + (to.y - from.y) * t);
      }
      remaining -= distance;
    }
    return route.last;
  }
}
