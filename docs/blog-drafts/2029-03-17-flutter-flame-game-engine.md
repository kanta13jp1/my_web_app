---
title: "Flutter Flame ゲームエンジン完全ガイド — 2Dゲーム開発の基礎から実装まで"
tags: flutter,dart,個人開発,AI
published: true
---

# Flutter Flame ゲームエンジン完全ガイド — 2Dゲーム開発の基礎から実装まで

Flutter の Flame ゲームエンジンを使えば、既存の Flutter スキルで 2D ゲーム開発が可能です。コンポーネントベースの設計と豊富な機能で、スマートフォンゲームをクロスプラットフォームに開発できます。

## Flame とは

Flame は Flutter 上で動く 2D ゲームエンジン。特徴:

- **Component-based**: ゲームオブジェクトをコンポーネントとして管理
- **Flutter 統合**: Widget と混在可能 (メニュー・UI は Flutter、ゲーム部分は Flame)
- **クロスプラットフォーム**: iOS / Android / Web / Desktop 対応
- **Forge2D 対応**: Box2D ベースの物理エンジン内蔵

## セットアップ

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

## FlameGame の基本構造

```dart
class MyGame extends FlameGame {
  @override
  Future<void> onLoad() async {
    // アセット読み込み・初期化
    await images.loadAll(['player.png', 'enemy.png', 'background.png']);
    add(Background());
    add(Player());
  }

  @override
  void update(double dt) {
    super.update(dt);
    // ゲームロジック (dt = delta time in seconds)
  }
}
```

## Component システム

```dart
// プレイヤーコンポーネント
class Player extends SpriteComponent
    with HasGameRef<MyGame>, KeyboardHandler, CollisionCallbacks {

  static const double speed = 200;
  late final Vector2 velocity = Vector2.zero();

  Player() : super(size: Vector2(64, 64));

  @override
  Future<void> onLoad() async {
    sprite = await gameRef.loadSprite('player.png');
    position = gameRef.size / 2;
    add(RectangleHitbox()); // 当たり判定
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
    // 画面外に出ないように制限
    position.clamp(Vector2.zero(), gameRef.size - size);
  }

  @override
  void onCollisionStart(Set<Vector2> points, PositionComponent other) {
    if (other is Enemy) {
      // ダメージ処理
      gameRef.playerDamaged();
    }
  }
}
```

## スプライトアニメーション

```dart
class AnimatedPlayer extends SpriteAnimationComponent {
  @override
  Future<void> onLoad() async {
    // スプライトシートからアニメーション作成
    final spriteSheet = await gameRef.images.load('player_sheet.png');

    animation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 8,       // フレーム数
        stepTime: 0.1,   // 各フレームの表示時間 (秒)
        textureSize: Vector2(64, 64), // 1フレームのサイズ
      ),
    );

    size = Vector2(64, 64);
  }
}

// 状態別アニメーション切り替え
class CharacterWithStates extends SpriteAnimationGroupComponent<PlayerState> {
  @override
  Future<void> onLoad() async {
    final idle = await _loadAnimation('idle', 4, 0.15);
    final run = await _loadAnimation('run', 8, 0.1);
    final jump = await _loadAnimation('jump', 5, 0.12);

    animations = {
      PlayerState.idle: idle,
      PlayerState.running: run,
      PlayerState.jumping: jump,
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

## タイルマップ (Tiled 連携)

```dart
// Tiled で作成したマップを読み込む
class TiledMapComponent extends Component {
  late TiledComponent tiledMap;

  @override
  Future<void> onLoad() async {
    tiledMap = await TiledComponent.load('level1.tmx', Vector2.all(32));
    add(tiledMap);

    // オブジェクトレイヤーからエネミースポーンポイントを取得
    final objectLayer = tiledMap.tileMap.getLayer<ObjectGroup>('enemies');
    for (final obj in objectLayer?.objects ?? []) {
      add(Enemy(position: Vector2(obj.x, obj.y)));
    }
  }
}
```

## Flutter UI との統合

```dart
// ゲームとFlutter Widgetを混在させる
class GamePage extends StatelessWidget {
  final MyGame game = MyGame();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ゲーム画面 (フルスクリーン)
          GameWidget(game: game),

          // Flutter UI (HUD)
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

          // ポーズボタン
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

## Supabase でスコアを保存

```dart
// ゲーム終了時にスコアを Supabase に保存
Future<void> saveScore(int score) async {
  await supabase.from('game_scores').insert({
    'user_id': supabase.auth.currentUser!.id,
    'score': score,
    'completed_at': DateTime.now().toIso8601String(),
  });
}

// ランキング取得
Future<List<Map<String, dynamic>>> getLeaderboard() async {
  return await supabase
      .from('game_scores')
      .select('score, profiles(username)')
      .order('score', ascending: false)
      .limit(10);
}
```

## まとめ

Flutter Flame で:

- **Component 設計**で複雑なゲームロジックを整理
- **SpriteAnimation** でなめらかなキャラクター表現
- **Flutter Widget 統合**でUI/UXを柔軟に構築
- **Supabase 連携**でスコア管理やマルチプレイヤー機能も実現

既存の Flutter スキルを活かして、ゲーム開発の世界に踏み込めます。

---

自分株式会社では Flutter × Supabase でAIライフマネジメントアプリを開発中。個人開発の知見を毎週発信しています。
