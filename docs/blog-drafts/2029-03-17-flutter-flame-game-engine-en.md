---
title: "Flutter Flame Game Engine Complete Guide — 2D Game Development from Scratch"
tags: flutter,dart,gamedev,indiedev
published: true
---

# Flutter Flame Game Engine Complete Guide — 2D Game Development from Scratch

Flame lets you build 2D games with your existing Flutter skills. Its component-based design and rich feature set make cross-platform mobile game development accessible to Flutter developers.

## What is Flame?

Flame is a 2D game engine that runs on top of Flutter:

- **Component-based**: Manage game objects as composable components
- **Flutter integration**: Mix Widgets and Flame (menus in Flutter, game in Flame)
- **Cross-platform**: iOS / Android / Web / Desktop
- **Forge2D support**: Box2D-based physics engine included

## Setup

```yaml
# pubspec.yaml
dependencies:
  flame: ^1.18.0
  flame_audio: ^2.10.0
```

```dart
// main.dart
import 'package:flame/game.dart';

void main() {
  runApp(GameWidget(game: MyGame()));
}
```

## FlameGame Basics

```dart
class MyGame extends FlameGame {
  @override
  Future<void> onLoad() async {
    await images.loadAll(['player.png', 'enemy.png', 'background.png']);
    add(Background());
    add(Player());
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Game logic (dt = delta time in seconds)
  }
}
```

## Component System

```dart
class Player extends SpriteComponent
    with HasGameRef<MyGame>, KeyboardHandler, CollisionCallbacks {

  static const double speed = 200;
  late final Vector2 velocity = Vector2.zero();

  Player() : super(size: Vector2(64, 64));

  @override
  Future<void> onLoad() async {
    sprite = await gameRef.loadSprite('player.png');
    position = gameRef.size / 2;
    add(RectangleHitbox());
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    velocity.setZero();
    if (keysPressed.contains(LogicalKeyboardKey.arrowLeft)) velocity.x = -speed;
    if (keysPressed.contains(LogicalKeyboardKey.arrowRight)) velocity.x = speed;
    if (keysPressed.contains(LogicalKeyboardKey.arrowUp)) velocity.y = -speed;
    if (keysPressed.contains(LogicalKeyboardKey.arrowDown)) velocity.y = speed;
    return true;
  }

  @override
  void update(double dt) {
    position += velocity * dt;
    position.clamp(Vector2.zero(), gameRef.size - size);
  }

  @override
  void onCollisionStart(Set<Vector2> points, PositionComponent other) {
    if (other is Enemy) {
      gameRef.playerDamaged();
    }
  }
}
```

## Sprite Animations

```dart
class AnimatedPlayer extends SpriteAnimationComponent {
  @override
  Future<void> onLoad() async {
    final spriteSheet = await gameRef.images.load('player_sheet.png');

    animation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 8,
        stepTime: 0.1,
        textureSize: Vector2(64, 64),
      ),
    );
    size = Vector2(64, 64);
  }
}

// State-based animation switching
class CharacterWithStates extends SpriteAnimationGroupComponent<PlayerState> {
  @override
  Future<void> onLoad() async {
    animations = {
      PlayerState.idle: await _loadAnimation('idle', 4, 0.15),
      PlayerState.running: await _loadAnimation('run', 8, 0.1),
      PlayerState.jumping: await _loadAnimation('jump', 5, 0.12),
    };
    current = PlayerState.idle;
    size = Vector2(64, 64);
  }

  Future<SpriteAnimation> _loadAnimation(
    String name, int frames, double stepTime,
  ) async {
    return SpriteAnimation.fromFrameData(
      await gameRef.images.load('$name.png'),
      SpriteAnimationData.sequenced(
        amount: frames,
        stepTime: stepTime,
        textureSize: Vector2(64, 64),
      ),
    );
  }
}
```

## Tiled Map Integration

```dart
class TiledMapComponent extends Component {
  late TiledComponent tiledMap;

  @override
  Future<void> onLoad() async {
    tiledMap = await TiledComponent.load('level1.tmx', Vector2.all(32));
    add(tiledMap);

    final objectLayer = tiledMap.tileMap.getLayer<ObjectGroup>('enemies');
    for (final obj in objectLayer?.objects ?? []) {
      add(Enemy(position: Vector2(obj.x, obj.y)));
    }
  }
}
```

## Flutter UI Integration

```dart
class GamePage extends StatelessWidget {
  final MyGame game = MyGame();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: game),
          Positioned(
            top: 16, left: 16,
            child: ValueListenableBuilder<int>(
              valueListenable: game.score,
              builder: (_, score, __) => Text(
                'Score: $score',
                style: const TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
          ),
          Positioned(
            top: 16, right: 16,
            child: IconButton(
              icon: const Icon(Icons.pause, color: Colors.white),
              onPressed: () => game.pauseEngine(),
            ),
          ),
        ],
      ),
    );
  }
}
```

## Saving Scores to Supabase

```dart
Future<void> saveScore(int score) async {
  await supabase.from('game_scores').insert({
    'user_id': supabase.auth.currentUser!.id,
    'score': score,
    'completed_at': DateTime.now().toIso8601String(),
  });
}

Future<List<Map<String, dynamic>>> getLeaderboard() async {
  return await supabase
      .from('game_scores')
      .select('score, profiles(username)')
      .order('score', ascending: false)
      .limit(10);
}
```

## Summary

With Flutter Flame you can:

- **Component architecture** keeps complex game logic organized
- **SpriteAnimation** delivers smooth character visuals
- **Flutter Widget integration** gives full UI/UX flexibility
- **Supabase integration** enables leaderboards and multiplayer features

Your existing Flutter skills transfer directly to game development.

---

Building an AI Life Management app with Flutter × Supabase at 自分株式会社. Sharing indie dev insights every week.
