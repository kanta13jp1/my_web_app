import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/echo_pump_room_walk.dart';

void main() {
  test('every route stays in the aisles and out of equipment', () {
    var from = EchoPumpRoomWalk.start;
    for (final target in [EchoRoomTarget.door, EchoRoomTarget.memo, EchoRoomTarget.door]) {
      final route = EchoPumpRoomWalk.route(from, target);
      for (var frame = 0; frame <= 1000; frame++) {
        expect(EchoPumpRoomWalk.isWalkable(EchoPumpRoomWalk.sample(route, frame / 1000)), isTrue);
      }
      final end = EchoPumpRoomWalk.sample(route, 1);
      expect(end.x, EchoPumpRoomWalk.destinations[target]!.x);
      expect(end.y, EchoPumpRoomWalk.destinations[target]!.y);
      from = end;
    }
  });

  test('stopped positions can safely resume to either target', () {
    final route = EchoPumpRoomWalk.route(EchoPumpRoomWalk.start, EchoRoomTarget.door);
    for (final progress in [0.1, 0.5, 0.9]) {
      final stopped = EchoPumpRoomWalk.sample(route, progress);
      for (final target in EchoRoomTarget.values) {
        final next = EchoPumpRoomWalk.route(stopped, target);
        for (var i = 0; i <= 100; i++) {
          expect(EchoPumpRoomWalk.isWalkable(EchoPumpRoomWalk.sample(next, i / 100)), isTrue);
        }
      }
    }
  });

  test('already at a target is idle and progress is bounded', () {
    final point = EchoPumpRoomWalk.destinations[EchoRoomTarget.memo]!;
    final idle = EchoPumpRoomWalk.route(point, EchoRoomTarget.memo);
    expect(EchoPumpRoomWalk.length(idle), 0);
    expect(EchoPumpRoomWalk.sample(idle, -1), point);
    expect(EchoPumpRoomWalk.sample(idle, 2), point);
  });

  test('walls, central equipment and invalid starts are rejected', () {
    for (final point in [EchoRoomPoint(0.5, 0.7), EchoRoomPoint(0, 0), EchoRoomPoint(double.nan, 0.9)]) {
      expect(EchoPumpRoomWalk.isWalkable(point), isFalse);
      expect(() => EchoPumpRoomWalk.route(point, EchoRoomTarget.memo), throwsArgumentError);
    }
    expect(() => EchoPumpRoomWalk.sample([], 0), throwsArgumentError);
  });
}
