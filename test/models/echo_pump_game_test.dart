import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/echo_pump_game.dart';

void main() {
  test('power limit and invalid moves do not consume a turn', () {
    final game = EchoPumpGame();
    game.togglePower(PumpCircuit.b);
    game.togglePower(PumpCircuit.a);
    final turn = game.turn;
    game.togglePower(PumpCircuit.c);
    expect(game.power.length, 2);
    expect(game.turn, turn);
    game.move(PumpRoom.pump);
    expect(game.room, PumpRoom.control);
    expect(game.turn, turn);
    game.move(PumpRoom.exit);
    expect(game.escaped, isFalse);
  });

  test('unpowered shelf cannot be looted and remote power is rejected', () {
    final game = EchoPumpGame();
    game.move(PumpRoom.hall);
    game.move(PumpRoom.workshop);
    final turn = game.turn;
    game.collectFuse();
    game.togglePower(PumpCircuit.b);
    expect(game.hasFuse, isFalse);
    expect(game.power, isEmpty);
    expect(game.turn, turn);
  });

  test('enemy moves one connected room toward latest active machine', () {
    final game = EchoPumpGame();
    game.togglePower(PumpCircuit.b);
    expect(game.enemy, PumpRoom.hall);
    game.togglePower(PumpCircuit.a);
    expect(game.enemy, PumpRoom.loading);
    game.togglePower(PumpCircuit.a);
    expect(game.noiseRoom, PumpRoom.workshop);
    expect(game.enemy, PumpRoom.hall);
    game.togglePower(PumpCircuit.b);
    game.wait();
    expect(game.enemy, PumpRoom.hall);
    expect(game.health, 3);
  });

  test('collision retreats, loses health and eventually freezes at failure',
      () {
    final game = EchoPumpGame();
    for (var i = 0; i < 3; i++) {
      game.move(PumpRoom.hall);
      game.move(PumpRoom.pump);
      expect(game.room, PumpRoom.control);
      expect(game.health, 2 - i);
    }
    final turn = game.turn;
    game.wait();
    game.move(PumpRoom.hall);
    game.togglePower(PumpCircuit.a);
    expect(game.finished, isTrue);
    expect(game.turn, turn);
    expect(game.power, isEmpty);
  });

  test('full run collects, repairs, lures, seals, drains and escapes unhurt',
      () {
    final game = EchoPumpGame();
    game.togglePower(PumpCircuit.b);
    game.togglePower(PumpCircuit.a);
    game.move(PumpRoom.hall);
    game.move(PumpRoom.workshop);
    game.collectFuse();
    expect(game.hasFuse, isTrue);
    game.move(PumpRoom.hall);
    game.move(PumpRoom.pump);
    game.drain();
    expect(game.drained, isFalse);
    game.seal();
    expect(game.sealed, isFalse);
    game.repair();
    expect(game.hasFuse, isFalse);
    expect(game.repaired, isTrue);
    game.move(PumpRoom.hall);
    game.move(PumpRoom.control);
    game.togglePower(PumpCircuit.b);
    game.togglePower(PumpCircuit.c);
    game.wait();
    game.wait();
    expect(game.enemy, PumpRoom.inspection);
    game.move(PumpRoom.hall);
    game.move(PumpRoom.pump);
    game.seal();
    game.move(PumpRoom.inspection);
    expect(game.room, PumpRoom.pump);
    game.drain();
    game.move(PumpRoom.hall);
    game.move(PumpRoom.control);
    game.move(PumpRoom.exit);
    expect(game.escaped, isTrue);
    expect(game.health, 3);
    final turn = game.turn;
    game.wait();
    game.repair();
    expect(game.turn, turn);
  });
}
