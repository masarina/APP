import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/scheduler.dart';


// ============================================================
// 使い捨てプログラム群
// ============================================================
// ------------------------------------
// 使い捨て型
// ------------------------------------
// ジャンプ内部データ保持クラス
class _JumpData {
  double startX;
  double startY;
  double landingX;
  double landingY;
  int startTimeMs;
  int jumpCount;

  _JumpData({
    required this.startX,
    required this.startY,
    required this.landingX,
    required this.landingY,
    required this.startTimeMs,
    required this.jumpCount,
  });
}
// 移動関数内部データ保持クラス
class _MoveData {
  double startX;
  double startY;
  double targetX;
  double targetY;
  int startTimeMs;

  _MoveData({
    required this.startX,
    required this.startY,
    required this.targetX,
    required this.targetY,
    required this.startTimeMs,
  });
}



// ==============================================================
// ⏱️ 非同期 & 環境情報サービス
// (OS / Flutter から来る 生の入力 を保持する場所)
// ==============================================================
class SystemEnvService 
{
  // -----------------------------
  // ⏱ GIF画像の動き開始
  // -----------------------------
  static Timer? _gifTimer;
  static void startGif({
    int frameIntervalMs = 100,
  }) {
    _gifTimer ??= Timer.periodic(
      Duration(milliseconds: frameIntervalMs),
      (_) {
        for (final obj in world.objects.values) {
          if (obj is GifObject) {
            obj.nextFrame();
          }
        }
      },
    );
  }

  // -----------------------------
  // ⏱ GIF画像の動き停止
  // -----------------------------
  static void stopGif() {
    _gifTimer?.cancel();
    _gifTimer = null;
  }

  // -----------------------------
  // 🧤 ユーザー / 端末情報（グローバル）
  // -----------------------------
  static Size screenSize = Size.zero; // 画面サイズ
  static bool isPortrait = true; // 縦向きかどうか
  static bool isTouching = false; // タップされているか
  static Offset? tapPosition; // タップされた座標

  // ---- 上記の変数を更新するメソッド。（主にbuildで呼び出して更新）
  static void updateScreenInfo({
    required Size size,
    required Orientation orientation,
  }) {
    screenSize = size;
    isPortrait = (orientation == Orientation.portrait);
  }

  static void setTouching(bool value) {
    isTouching = value;
  }

  static void setTapPosition(Offset pos) {
    final w = screenSize.width;
    final h = screenSize.height;
    // 左上基準 -> センター基準へ変換
    tapPosition = Offset(pos.dx - w / 2, pos.dy - h / 2);
  }

  static void clearTap() {
    tapPosition = null;
  }
}


// ==============================================================
// コンポーネントサービス
// (ゲーム世界の「意味のある判断」をする場所)
// ==============================================================
enum HitSide {
  none,
  north,
  south,
  west,
  east,
}// --------------------------------------------------------------
// 💥 衝突方向（優先順位つき）
// ※ NORTH を最優先にする設計
// --------------------------------------------------------------
class ComponentsService {

  // ------------------------------------------------------------
  // 💥 衝突判定（従来互換：boolのみ欲しい場合）
  // ------------------------------------------------------------
  static bool hit(WorldObject a, WorldObject b) {
    return hitSide(a, b) != HitSide.none;
  }

  // ------------------------------------------------------------
  // 💥 衝突方向付き判定
  // 返り値：HitSide
  // 優先順位：北 → 南 → 西 → 東
  // ------------------------------------------------------------
  static HitSide hitSide(WorldObject a, WorldObject b) {
    if (!a.enableCollision || !b.enableCollision) return HitSide.none;
    if (a.colliderRect == null || b.colliderRect == null) return HitSide.none;

    final Rect ra = a.colliderRect!;
    final Rect rb = b.colliderRect!;

    // そもそも当たっていない
    if (!ra.overlaps(rb)) return HitSide.none;

    // ----------------------------------------------------------
    // 🔵 重なり領域（intersection）を計算
    // ----------------------------------------------------------
    final Rect inter = ra.intersect(rb);

    // 中心差分（a基準）
    final double dx = rb.center.dx - ra.center.dx;
    final double dy = rb.center.dy - ra.center.dy;

    // ----------------------------------------------------------
    // 🧭 どの面にめり込んだか判定
    // overlap が小さい方向 = 接触面
    // ----------------------------------------------------------
    final double overlapX = inter.width;
    final double overlapY = inter.height;

    // ================================
    // 🔴 縦方向優先（NORTH優先設計）
    // ================================
    if (overlapY <= overlapX) {

      // b が a より上にいる → 北衝突
      if (dy < 0) {
        return HitSide.north;
      }

      // b が下 → 南衝突
      return HitSide.south;
    }

    // ================================
    // 🟢 横方向
    // ================================
    if (dx < 0) {
      return HitSide.west;
    }

    return HitSide.east;
  }


  // -----------------------------
  // 👆 クリック判定
  // -----------------------------
  static bool isClicked(WorldObject obj) {
    if (!obj.enableCollision) return false;
    if (obj.colliderRect == null) return false;
    if (!SystemEnvService.isTouching) return false;
    if (SystemEnvService.tapPosition == null) return false;

    return obj.colliderRect!.contains(
      SystemEnvService.tapPosition!,
    );
  }
}

// --------------------------------------------------------------
// 🧪 使用例（Player側）
// --------------------------------------------------------------
// final side = ComponentsService.hitSide(player, wall);
//
// switch (side) {
//   case HitSide.north:
//     // 上から着地した時の処理
//     break;
//   case HitSide.south:
//     // 下からぶつかった
//     break;
//   case HitSide.west:
//   case HitSide.east:
//     // 横衝突
//     break;
//   case HitSide.none:
//     break;
// }


// ==============================================================
// アニメーションフィルムサービス
// 【フィルムを作成したら、そのクラスに必ず
// 　以下のキャッシュをメンバ変数に実装してください。】
// String frame_result = "ok";
// late List<dynamic> list_2d;
// int wait_time = 1;
// int? end_time = null;
// late List<List<List<dynamic>>> animation_film_3dlist;
// bool flag_all_film_finished = false;
//
// 【注意】
// ・一行一行実行されます。
// ・前の行の関数の実行が終了されていない場合、次の行は実行されません。
//   →（ジャンプ中など。なお、複数ジャンプメソッドの場合は、
// 　　　最後のジャンプでfunkの戻り値が"ok"になります。）
//
// 【例】・
// ==============================================================
class AnimationFilmService {
  // ============================================
  // ★ インデックス管理用（軽量化ポイント）
  // ============================================
  static
  (
    String newFrameResult,
    List<List<List<dynamic>>> newAnimationFilm3DList,
    List<dynamic> newList2D,
    int newWaitTime,
    int? newEndTime,
    int newCurrentIndex,
    bool isFilmEmpty
  )
  runAnimationFilm(
    String frameResult,
    List<List<List<dynamic>>> animationFilm3DList,
    List<dynamic> list2d,
    int waitTime,
    int? endTime,
    int currentIndex,   // ★追加
  ) {


    // ============================================
    // 待機開始
    // ============================================
    if (endTime == null){

      int now_time = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      endTime = now_time + waitTime;
    }

    // ============================================
    // 経過チェック
    // ============================================
    int now_time = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    if (endTime <= now_time) {

      endTime = null;

      // removeAtせず、インデックスで読む
      if (frameResult == "ok" && animationFilm3DList.isNotEmpty) {

        if (currentIndex < animationFilm3DList.length) {
          list2d = animationFilm3DList[currentIndex];
          currentIndex++;
        }
      }

      frameResult = "None";

      for (final cell in list2d) {

        final Function func = cell[3];
        final WorldObject obj = cell[0];
        final dynamic value = cell[1];

        frameResult = func(obj, value);
        waitTime = cell[2];
      }
    }

    return (
      frameResult,
      animationFilm3DList,
      list2d,
      waitTime,
      endTime,
      currentIndex,
      currentIndex >= animationFilm3DList.length
    );
  }
}


// ==============================================================
// 👒モードの入れ物準備
// ==============================================================
late ScheduleMaking Mode_Init; // 最初のモード
late ScheduleMaking Mode_HomeInit; // ホーム画面モード
late ScheduleMaking Mode_Home; // ホーム画面モード
late ScheduleMaking Mode_GameStoryMovie; // ゲームストーリーの再生モード
late ScheduleMaking Mode_GameInit; // ゲームの初期化モード
late ScheduleMaking Mode_Game; // ゲームの初期化モード
late ScheduleMaking Mode_GameOver; // ゲームオーバー画面モード


// ==============================================================
// 🧠 SuperPlayer
// ==============================================================
abstract class SuperPlayer {
  void init() {}
  void mainScript() {}
}

// ==============================================================
// 🌍 World / Pool
// ==============================================================
abstract class WorldObject {
  Offset position;
  int layer; // 画面オブジェクトの表示順番。レイヤ番号。

  WorldObject(this.position, {this.layer = 0});

  // ⭐ 当たり判定フラグ（基本はOFF）
  bool enableCollision = false;
  // ⭐ 当たり判定（なければ null）
  Rect? get colliderRect => null;
}
class WorldPool {
  final Map<String, WorldObject> objects = {};
  
  // ==============================================================
  // Playerのインスタンス化
  // ==============================================================
  InitPlayer initPlayer = InitPlayer();
  HomeInitPlayer homeInitPlayer = HomeInitPlayer();
  HomePlayer homePlayer = HomePlayer();
  GameInitPlayer gameInitPlayer = GameInitPlayer();
  GameStoryPlayer gameStoryPlayer = GameStoryPlayer();
  ReceiveInputPlayer receiveInputPlayer = ReceiveInputPlayer(); // ユーザからの入力判断
  MovingDisturverPlayer movingDisturberPlayer = MovingDisturverPlayer(); // 邪魔者の座標を更新
  CollisionGimmickPlayer collisionGimmickPlayer = CollisionGimmickPlayer(); // コライダー判定フラグ
  CollisionResolvePlayer collisionResolvePlayer = CollisionResolvePlayer(); // コライダー判定フラグ処理
  GameJumpAnimationPlayer gameJumpAnimationPlayer = GameJumpAnimationPlayer(); // ユーザからの入力判断
  GameoverJudgmentPlayer gameoverJudgmentPlayer = GameoverJudgmentPlayer(); // ユーザからの入力判断
  GameOverDisplayPlayer gameOverDisplayPlayer = GameOverDisplayPlayer(); // ゲームオーバーの画面を作る。
  GameOverInputPlayer gameOverInputPlayer = GameOverInputPlayer(); // ゲームオーバー画面でのユーザからの入力操作で動く。
}
final world = WorldPool();


// ============================================================== 
// 🎨 ObjectManager（Python感覚）
// 数値引数を int / double どちらでも安全に受け取れる改良版
// ============================================================== 

class ObjectManager {
  // ============================================================
  // クラス変数群
  // ============================================================

  // ジャンプ管理用の辞書
  static final Map<WorldObject, _JumpData> _jumpingObjects = {}; // {obj, 着地予定座標}

  // 管理用の辞書
  static final Map<WorldObject, _MoveData> _movingObjects = {}; // {obj, 着地予定座標}

  // ============================================================
  // 🔵 数値安全変換ヘルパー
  // int / double どちらが来ても double に変換する
  // ============================================================
  static double _toDouble(num value) {
    return value.toDouble();
  }

  // ============================================================
  // スタティックメソッド群。
  // 第一引数: WorldObject型
  // 第二引数: なんでもよい。
  // 引数の数: ２つ。
  // 戻り値: ステータス文字列
  // ============================================================

  // ==============================
  // 絶対座標へ移動（上書き型）
  // ==============================
  static String toSetPosition(
    WorldObject obj,
    (
      num x,
      num y,
    ) position,
  ) {
    final (xRaw, yRaw) = position;

    final x = _toDouble(xRaw);
    final y = _toDouble(yRaw);

    obj.position = Offset(x, y);
    return "ok";
  }

  // ==============================
  // 相対移動（現在位置に足し算）
  // ==============================
  static String toMove(
    WorldObject obj,
    (
      num dx,
      num dy,
    ) moveXY,
  ) {
    final (dxRaw, dyRaw) = moveXY;

    final dx = _toDouble(dxRaw);
    final dy = _toDouble(dyRaw);

    obj.position += Offset(dx, dy);
    return "ok";
  }

  // ==============================
  // 任意角度に設定（度で指定）
  // ==============================
  static String toSetRotationDeg(
    WorldObject obj,
    (
      num degree,
    ) params,
  ) {
    final (degreeRaw,) = params;

    final degree = _toDouble(degreeRaw);
    final rad = degree * pi / 180;

    if (obj is ImageObject) {
      obj.rotation = rad;
    }
    else if (obj is GifObject) {
      obj.rotation = rad;
    }

    return "ok";
  }

  // ==============================
  // 別オブジェクトの座標をコピー
  // ==============================
  static String toCopyPosition(
    WorldObject targetObj,
    (
      WorldObject sourceObj,
    ) params,
  ) {
    final (sourceObj,) = params;
    targetObj.position = sourceObj.position;
    return "ok";
  }

  // ==============================
  // 他オブジェクトに追従（オフセット付き）
  // ==============================
  static String toFollowWithOffset(
    WorldObject targetObj,
    (
      WorldObject baseObj,
      num offsetX,
      num offsetY,
    ) params,
  ) {
    final (baseObj, offsetXRaw, offsetYRaw) = params;

    final offsetX = _toDouble(offsetXRaw);
    final offsetY = _toDouble(offsetYRaw);

    targetObj.position = Offset(
      baseObj.position.dx + offsetX,
      baseObj.position.dy + offsetY,
    );

    return "ok";
  }

  // ============================================================
  // ジャンプメソッド（多段ジャンプ拡張対応設計）
  // ============================================================
  static String toJump(
    WorldObject obj,
    (
      num targetX,
      num targetY,
      num jumpPower,
      num durationSec,
      int maxJumpCount,
      bool flag_more_jump
    ) params,
  ) {

    final (
      targetXRaw,
      targetYRaw,
      jumpPowerRaw,
      durationSecRaw,
      maxJumpCount,
      flag_more_jump
    ) = params;

    final targetX = _toDouble(targetXRaw);
    final targetY = _toDouble(targetYRaw);
    final jumpPower = _toDouble(jumpPowerRaw);
    final durationSec = _toDouble(durationSecRaw);

    final now = DateTime.now().millisecondsSinceEpoch;

    if (!_jumpingObjects.containsKey(obj)) {
      _jumpingObjects[obj] = _JumpData(
        startX: obj.position.dx,
        startY: obj.position.dy,
        landingX: targetX,
        landingY: targetY,
        startTimeMs: now,
        jumpCount: 1,
      );
    }
    else {
      final data = _jumpingObjects[obj]!;

      if (flag_more_jump &&
          data.jumpCount < maxJumpCount) {

        data.startY = obj.position.dy;
        data.startTimeMs = now;
        data.jumpCount += 1;
      }
    }

    final data = _jumpingObjects[obj]!;

    final elapsedSec =
        (now - data.startTimeMs) / 1000.0;

    final progress =
        (elapsedSec / durationSec).clamp(0.0, 1.0);

    final newX =
        data.startX +
        (data.landingX - data.startX) * progress;

    final baseY =
        data.startY +
        (data.landingY - data.startY) * progress;

    final height =
        4 *
        jumpPower *
        progress * (1 - progress);

    final newY = baseY - height;

    if (progress >= 1.0) {
      obj.position =
          Offset(data.landingX, data.landingY);

      _jumpingObjects.remove(obj);
      return "ok";
    }

    obj.position = Offset(newX, newY);
    return "running";
  }

  // ============================================================
  // 直線移動メソッド（一定速度）
  // ============================================================
  static String toLinearMove(
    WorldObject obj,
    (
      num targetX,
      num targetY,
      num durationSec
    ) params,
  ) {

    final (
      targetXRaw,
      targetYRaw,
      durationSecRaw
    ) = params;

    final targetX = _toDouble(targetXRaw);
    final targetY = _toDouble(targetYRaw);
    final durationSec = _toDouble(durationSecRaw);

    final now = DateTime.now().millisecondsSinceEpoch;

    if (!_movingObjects.containsKey(obj)) {
      _movingObjects[obj] = _MoveData(
        startX: obj.position.dx,
        startY: obj.position.dy,
        targetX: targetX,
        targetY: targetY,
        startTimeMs: now,
      );
    }

    final data = _movingObjects[obj]!;

    final elapsedSec =
        (now - data.startTimeMs) / 1000.0;

    final progress =
        (elapsedSec / durationSec).clamp(0.0, 1.0);

    final newX =
        data.startX +
        (data.targetX - data.startX) * progress;

    final newY =
        data.startY +
        (data.targetY - data.startY) * progress;

    if (progress >= 1.0) {
      obj.position = Offset(data.targetX, data.targetY);
      _movingObjects.remove(obj);
      return "ok";
    }

    obj.position = Offset(newX, newY);
    return "running";
  }

  // ============================================================
  // ⬇ 落下メソッド（重力）
  // ============================================================
  static String toFall(
    WorldObject obj,
    (
      num fallSpeed,
    ) params,
  ) {
    final (fallSpeedRaw,) = params;

    final fallSpeed = _toDouble(fallSpeedRaw);

    obj.position += Offset(0, fallSpeed);

    return "running";
  }
}



// ==============================================================
// 🎨 ObjectCreator（Python感覚）
// ==============================================================
/*
オブジェクトの型の用意。
*/
// 円型のオブジェクト
class CircleObject extends WorldObject {
  Color color;
  double size;

  CircleObject({
    required Offset position,
    required this.color,
    required this.size,
    int layer = 0,   // 画面オブジェクトに照射するレイヤ数。
  }) : super(position, layer: layer) {   // ← 修正
    enableCollision = true;
  }
  

  @override
  Rect get colliderRect {
    return Rect.fromCircle(
      center: position,
      radius: size / 2,
    );
  }
}

// 静止画オブジェクト
class ImageObject extends WorldObject {
  String assetPath;
  double width;
  double height;
  double rotation;

  // ⭐ 当たり判定設定
  Offset collisionOffset;
  Size collisionSize;


  ImageObject({
    required Offset position,
    required this.assetPath,
    required this.width,
    required this.height,
    this.rotation = 0.0,
    bool enableCollision = false,
    Offset? collisionOffset,
    Size? collisionSize,
    int layer = 0,   // 画面オブジェクトに照射するレイヤ数。
  })  : collisionOffset = collisionOffset ?? Offset.zero,
        collisionSize = collisionSize ?? Size(width, height),
        super(position, layer: layer) {   // ← 修正
    this.enableCollision = enableCollision;
  }

  // =============================
  // 🧱 当たり判定用の四角（コライダー）
  // =============================
  @override
  Rect get colliderRect {
    return Rect.fromCenter(
      center: position + collisionOffset,
      width: collisionSize.width,
      height: collisionSize.height,
    );
  }
}


// アニメーションオブジェクト
class GifObject extends WorldObject {
  final List<String> assetPaths;
  int _frameIndex = 0;

  double width;
  double height;
  double rotation;

  GifObject({
    required Offset position,
    required this.assetPaths,
    required this.width,
    required this.height,
    this.rotation = 0.0,
    bool enableCollision = false,
    int layer = 0, // 画面照射する順番。
  }) : super(position, layer: layer) {   // ← 修正
    this.enableCollision = enableCollision;
  }

  @override
  Rect get colliderRect {
    return Rect.fromCenter(
      center: position,
      width: width,
      height: height,
    );
  }

  String get currentAssetPath => assetPaths[_frameIndex];

  void nextFrame() {
    _frameIndex = (_frameIndex + 1) % assetPaths.length;
  }
}


/*
オブジェクトの型を用いた、オブジェクトクリエイター群。
*/
class ObjectCreator {
  // 円型のオブジェクト
  static void createCircle({
    required String objectName,
    required Color color,
    required Offset position,
    required double size,
  }) {
    final circle = CircleObject(
      position: position,
      color: color,
      size: size,
    );
    world.objects[objectName] = circle;
  }

  // 静止画オブジェクト
  static void createImage({
    required String objectName,
    required String assetPath,
    required Offset position,
    required double width,
    required double height,
    double rotation = 0.0,

    bool enableCollision = false,
    Offset? collisionOffset,
    Size? collisionSize,
    int layer = 0,   // 表示順番
  }) {
    final image = ImageObject(
      position: position,
      assetPath: assetPath,
      width: width,
      height: height,
      rotation: rotation,
      enableCollision: enableCollision,
      collisionOffset: collisionOffset,
      collisionSize: collisionSize,
      layer: layer,  // 表示順番
    );

    world.objects[objectName] = image;
  }

  // アニメーションオブジェクト
  static void createGIF({
    required String objectName,
    required List<String> assetPaths,
    required Offset position,
    required double width,
    required double height,
    double rotation = 0.0, // ← 追加
    bool enableCollision = false,
    int layer = 0,   // 表示順番
  }) {
    final gif = GifObject(
      position: position,
      assetPaths: assetPaths,
      width: width,
      height: height,
      rotation: rotation,         // ← 渡す
      enableCollision: enableCollision,
      layer: layer,  // 表示順番
    );
    world.objects[objectName] = gif;
  }

}


// ==============================================================
// Players
// ==============================================================
// アプリ起動時の初期化を担うPlayer 
class InitPlayer extends SuperPlayer {
  bool background_created = false;

  // __init__(self)に同じ
  @override
  void init() {
    // 特になし
  }
  // 非同期サービスの開始
  
  // 最初に用意するオブジェクトと、それらの配置。
  @override
  void mainScript() 
  {
    // 画面サイズが取得できていない場合は、背景作れないので、パス。
    if (SystemEnvService.screenSize == Size.zero) {
      return;
    }

    if (!this.background_created){
      // 背景（画面ぴったり）
      final screenSize = SystemEnvService.screenSize;
      ObjectCreator.createImage(
        objectName: "背景",
        assetPath: "assets/images/kami_kusyakusya.png",
        position: Offset.zero,
        width: screenSize.width * 20,
        height: screenSize.height * 20,
        rotation: pi / 2,
        layer: 0, // 一番奥
      );

      debugPrint("背景を作りました。");
      this.background_created = true;
    }
  }
}


// ホーム画面初期化モード
class HomeInitPlayer extends SuperPlayer {
  bool initialized = false;

  // __init__(self)に同じ
  @override
  void init() {
    // 特になし
  }
  // 非同期サービスの開始
  
  // 最初に用意するオブジェクトと、それらの配置。
  @override
  void mainScript() 
  {

    if (this.initialized) return;
    this.initialized = true;

    // 材料の定義
    final screenSize = SystemEnvService.screenSize;

    // 真ん中下にアノアノ
    double bias_x = 70;
    double bias_y = 70;
    ObjectCreator.createImage(
      objectName: "アノアノ右目",
      assetPath: "assets/images/nikkori.png",
      position: Offset(bias_x, bias_y), // 左上ぴったり
      width: 30,
      height: 30,
      layer: 100, // 表示順番
    );
    ObjectCreator.createImage(
      objectName: "アノアノ左目",
      assetPath: "assets/images/nikkori.png",
      position: Offset(
          bias_x - 3, 
          bias_y + 2
        ), 
      width: 30,
      height: 30,
      layer: 101, // 表示順番
    );
    ObjectCreator.createImage(
      objectName: "アノアノ口",
      assetPath: "assets/images/nikkori.png",
      position: Offset(
          bias_x - 20, 
          bias_y + 20
        ), 
      width: 30,
      height: 30,
      rotation: pi, // pi → 180。0,
      layer: 102, // 表示順番
    );
    ObjectCreator.createImage(
      objectName: "アノアノ輪郭",
      assetPath: "assets/images/kao_rinnkaku_1.png",
      position: Offset(
          bias_x - 5, 
          bias_y + 5
        ), 
      width: 30,
      height: 30,
      rotation: pi, // pi → 180。0,
      enableCollision: true,
      layer: 103, // 表示順番
    );

    // 下中央に「スタートボタン」
    ObjectCreator.createImage(
      objectName: "スタートボタン",
      assetPath: "assets/images/start.png",
      position: Offset(
        0,
        screenSize.height * 0.4 - screenSize.height / 2,
      ),
      width: 70,
      height: 70,
      enableCollision: true,
      layer: 200, // 表示順番
    );

  }
}


// ホーム画面プレイヤー
class HomePlayer extends SuperPlayer {
  // class変数
  bool flag_start_button = false;

  // __init__(self)に同じ
  @override
  void init() {
    // 特になし
  }
  
  @override
  void mainScript() 
  {

    // スタートボタンが押されたか判定
    final button = world.objects["スタートボタン"];

    if (button != null &&
        ComponentsService.isClicked(button)) {

      debugPrint("🔥 スタートボタンが押されました");
      flag_start_button = true;
    }

  }

}


// ゲームストーリーを再生するPlayer
class GameStoryPlayer extends SuperPlayer {
  // class変数
  bool flag_story_end = false;
  double hidden_xy = -10000.0;

  // 座標管理変数
  Size screenSize = SystemEnvService.screenSize;
  late double bias_x; // late → 意味:「後で代入するので空の初期化だけど許してほしい」
  late double bias_y;

  // フィルム再生用キャッシュ
  String frame_result = "ok";
  late List<dynamic> list_2d;
  int wait_time = 1;
  int? end_time = null;
  int currentIndex = 0;   // ★追加
  late List<List<List<dynamic>>> animation_film_3dlist;

  // __init__(self)に同じ
  @override
  void init() {

    list_2d = [];          // ★これを追加
    // バイアス座標の作成
    this.bias_x = 75;
    this.bias_y = 70;


    // 使用するオブジェクトの用意
    ObjectCreator.createImage(
      objectName: "ちいさいまる",
      assetPath: "assets/images/maru_tiisai.png",
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: hidden_xy,
      height: hidden_xy,
      layer: 301, // 表示順番
    );
    ObjectCreator.createImage(
      objectName: "ちいさいもこもこ",
      assetPath: "assets/images/mokomoko_syou.png",
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: hidden_xy,
      height: hidden_xy,
      layer: 302, // 表示順番
    );
    ObjectCreator.createImage(
      objectName: "おおきいもこもこ",
      assetPath: "assets/images/mokomoko_dai.png",
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: hidden_xy,
      height: hidden_xy,
      layer: 303, // 表示順番
    );
    ObjectCreator.createImage(
      objectName: "空想アノアノ右目",
      assetPath: "assets/images/nikkori.png",
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: hidden_xy,
      height: hidden_xy,
    );
    ObjectCreator.createImage(
      objectName: "空想アノアノ左目",
      assetPath: "assets/images/nikkori.png",
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: hidden_xy,
      height: hidden_xy,
      layer: 304, // 表示順番
    );
    ObjectCreator.createImage(
      objectName: "空想アノアノ口",
      assetPath: "assets/images/nikkori.png",
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: hidden_xy,
      height: hidden_xy,
      rotation: pi, // pi → 180。
      layer: 305, // 表示順番
    );
    ObjectCreator.createGIF(
      objectName: "空想アノアノ羽",
      assetPaths: ["assets/images/hane_1.png","assets/images/hane_2.png"],
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: hidden_xy,
      height: hidden_xy,
      layer: 306, // 表示順番
    );
    ObjectCreator.createGIF(
      objectName: "空想アノアノ輪郭",
      assetPaths: ["assets/images/hane_1.png","assets/images/kao_rinnkaku_1.png"],
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: hidden_xy,
      height: 70,
      layer: 306, // 表示順番
    );
    ObjectCreator.createImage(
      objectName: "アノアノ両目_怒",
      assetPath: "assets/images/me_sikame.png",
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: hidden_xy,
      height: hidden_xy,
      layer: 307, // 表示順番
    );

    // アニメーションフィルムの作成
    double jump_height = 3.0;
    double jump_time = 0.05;

    // →　[オブジェクト名、代入値(座標等)、待機時間、実行関数]
    this.animation_film_3dlist = [
        // スタートボタンの退避
        [[world.objects["スタートボタン"], (-1000.0, -1000.0), 0, ObjectManager.toSetPosition]],

        // 空想もこもこ表示
        [[world.objects["ちいさいまる"], (this.bias_x, this.bias_y), 1, ObjectManager.toSetPosition]],
        [[world.objects["ちいさいもこもこ"], (this.bias_x + 10, this.bias_y + 12), 1, ObjectManager.toSetPosition]],
        [[world.objects["おおきいもこもこ"], (this.bias_x + 20, this.bias_y + 70), 1, ObjectManager.toSetPosition]],
        
        // 空想アノアノの出現
        [[world.objects["空想アノアノ輪郭"], (this.bias_x + 15, this.bias_y + 60), 0, ObjectManager.toSetPosition],
         [world.objects["空想アノアノ右目"], (world.objects["空想アノアノ輪郭"]!, 20, -10), 0, ObjectManager.toFollowWithOffset],
         [world.objects["空想アノアノ左目"], (world.objects["空想アノアノ輪郭"]!, 20, -10), 0, ObjectManager.toFollowWithOffset],
         [world.objects["空想アノアノ口"], (world.objects["空想アノアノ輪郭"]!, 20, -10), 0, ObjectManager.toFollowWithOffset],
         [world.objects["空想アノアノ羽"], (world.objects["空想アノアノ輪郭"]!, 20, -10), 0, ObjectManager.toFollowWithOffset]],
        
        // 現実アノアノが本気の顔になる
        [[world.objects["アノアノ両目_怒"], world.objects["アノアノ右目"], 0, ObjectManager.toCopyPosition], // 時間指定意味ないが、気休めに０を代入。
         [world.objects["アノアノ両目_怒"], (5, 0), 0, ObjectManager.toMove], // 時間指定意味ないが、気休めに０を代入。
         [world.objects["アノアノ右目"], (hidden_xy, hidden_xy), 0, ObjectManager.toSetPosition], // 目を退避
         [world.objects["アノアノ左目"], (hidden_xy, hidden_xy), 1, ObjectManager.toSetPosition]], // 目を退避
        
        // 現実アノアノが高ぶるいする（ちょっと2回ジャンプする。）
        [[world.objects["アノアノ輪郭"], (world.objects["アノアノ輪郭"]!.position.dx, 
                                        world.objects["アノアノ輪郭"]!.position.dy, 
                                        jump_height,
                                        jump_time, 
                                        1, 
                                        false),0,ObjectManager.toJump],
         [world.objects["アノアノ両目_怒"], (world.objects["アノアノ輪郭"]!, 20, -10), 0, ObjectManager.toFollowWithOffset],
         [world.objects["アノアノ口"], (world.objects["アノアノ輪郭"]!, 20, -10), 0, ObjectManager.toFollowWithOffset]],
      ];

  }
  
  @override
  void mainScript() 
  {
    // ============================================
    // ゲームストーリーの再生開始。
    // ============================================
    final result = AnimationFilmService.runAnimationFilm(
      this.frame_result,
      this.animation_film_3dlist,
      this.list_2d,
      this.wait_time,
      this.end_time,
      this.currentIndex,
    );
    this.frame_result = result.$1;
    this.animation_film_3dlist = result.$2;
    this.list_2d = result.$3;
    this.wait_time = result.$4;
    this.end_time = result.$5;
    this.currentIndex = result.$6;      // ★index保存
    this.flag_story_end = result.$7;    // ★終了フラグは$7
  }
}


// ゲームオブジェクトをリセット地点に置くプレイヤー。 
class GameInitPlayer extends SuperPlayer {
  // クラス変数
  final Offset hiddenOffset = const Offset(-10000, -10000);
  final Offset anoanoBiasOffset = const Offset(200, 500);
  bool flag_object_created = false;

  // フィルム再生用キャッシュ
  String frame_result = "ok";
  late List<dynamic> list_2d;
  int wait_time = 1;
  int? end_time = null;
  int currentIndex = 0;   // ★追加
  late List<List<List<dynamic>>> animation_film_3dlist;
  bool flag_all_film_finished = false;

  // __init__(self)に同じ
  @override
  void init() {

    list_2d = [];          // ★これを追加
    // アニメーションフィルムの作成
    // →　[オブジェクト名、代入値(座標等)、待機時間、実行関数]
    this.animation_film_3dlist = [

        // 空想隠す。
        [[world.objects["ちいさいまる"], (this.hiddenOffset.dx, this.hiddenOffset.dy), 0, ObjectManager.toSetPosition],
         [world.objects["ちいさいもこもこ"], (this.hiddenOffset.dx, this.hiddenOffset.dy), 0, ObjectManager.toSetPosition],
         [world.objects["おおきいもこもこ"], (this.hiddenOffset.dx, this.hiddenOffset.dy), 0, ObjectManager.toSetPosition],
         [world.objects["空想アノアノ輪郭"], (this.hiddenOffset.dx, this.hiddenOffset.dy), 0, ObjectManager.toSetPosition],
         [world.objects["空想アノアノ右目"], (world.objects["空想アノアノ輪郭"]!, 20, -10), 0, ObjectManager.toFollowWithOffset],
         [world.objects["空想アノアノ口"], (world.objects["空想アノアノ輪郭"]!, 20, -10), 0, ObjectManager.toFollowWithOffset],
         [world.objects["空想アノアノ羽"], (world.objects["空想アノアノ輪郭"]!, 20, -10), 0, ObjectManager.toFollowWithOffset]],

        // 既に存在するゲームオブジェクトを初期位置に移動させる。
        [[world.objects["アノアノ輪郭"], (this.anoanoBiasOffset.dx, this.anoanoBiasOffset.dy, 150.0, 0.8, 1, false), 0, ObjectManager.toJump],
         [world.objects["アノアノ口"], (world.objects["アノアノ輪郭"]!, 20, -10), 0, ObjectManager.toFollowWithOffset],
         [world.objects["アノアノ両目_怒"], (world.objects["アノアノ輪郭"]!, 20, -10), 0, ObjectManager.toFollowWithOffset]],
      ];  
  }
  // 非同期サービスの開始

  
  @override
  void mainScript() 
  {
    // ============================================
    // 邪魔オブジェクトの生成（見えないところに。）
    // ============================================
    if (!this.flag_object_created){
      // 建物
      ObjectCreator.createGIF(
        objectName: "建物_1",
        assetPaths: [
            "assets/images/tatemono_1.png",
            "assets/images/tatemono_2.png",
          ],
        position: Offset(this.hiddenOffset.dx, this.hiddenOffset.dy),
        width: 500,
        height: 1000,
        enableCollision: true,
        layer: 401, // 表示順番
      );
      // UFO
      ObjectCreator.createGIF(
        objectName: "UFO_1",
        assetPaths: [
            "assets/images/ufo_1.png",
            "assets/images/ufo_2.png",
          ],
        position: Offset(this.hiddenOffset.dx, this.hiddenOffset.dy),
        width: 500,
        height: 1000,
        enableCollision: true,
        layer: 402, // 表示順番
      );
      // 建物
      ObjectCreator.createGIF(
        objectName: "建物_2",
        assetPaths: [
            "assets/images/tatemono_1.png",
            "assets/images/tatemono_2.png",
          ],
        position: Offset(this.hiddenOffset.dx, this.hiddenOffset.dy),
        width: 500,
        height: 1000,
        enableCollision: true,
        layer: 403, // 表示順番
      );
      // UFO
      ObjectCreator.createGIF(
        objectName: "UFO_2",
        assetPaths: [
            "assets/images/ufo_1.png",
            "assets/images/ufo_2.png",
          ],
        position: Offset(this.hiddenOffset.dx, this.hiddenOffset.dy),
        width: 500,
        height: 1000,
        enableCollision: true,
        layer: 404, // 表示順番
      );
      // 建物
      ObjectCreator.createGIF(
        objectName: "建物_3",
        assetPaths: [
            "assets/images/tatemono_1.png",
            "assets/images/tatemono_2.png",
          ],
        position: Offset(this.hiddenOffset.dx, this.hiddenOffset.dy),
        width: 500,
        height: 1000,
        enableCollision: true,
        layer: 405, // 表示順番
      );
      // UFO
      ObjectCreator.createGIF(
        objectName: "UFO_3",
        assetPaths: [
            "assets/images/ufo_1.png",
            "assets/images/ufo_2.png",
          ],
        position: Offset(this.hiddenOffset.dx, this.hiddenOffset.dy),
        width: 500,
        height: 1000,
        enableCollision: true,
        layer: 406, // 表示順番
      );

      // ============================================
      // アイテムオブジェクトの生成（見えないところに。）
      // ============================================
      // UFO
      ObjectCreator.createGIF(
        objectName: "アイテム_羽_1",
        assetPaths: [
            "assets/images/hane_1.png",
            "assets/images/hane_2.png",
          ],
        position: Offset(this.hiddenOffset.dx, this.hiddenOffset.dy),
        width: 500,
        height: 1000,
        enableCollision: true,
        layer: 500, // 表示順番
      );

      // アイテム作成できたので、フラグをオンにする。
      this.flag_object_created = true;
    }

    // ============================================
    // ゲームの初期化
    // ============================================
    final result = AnimationFilmService.runAnimationFilm(
      this.frame_result,
      this.animation_film_3dlist,
      this.list_2d,
      this.wait_time,
      this.end_time,
      this.currentIndex,
    );
    this.frame_result = result.$1;
    this.animation_film_3dlist = result.$2;
    this.list_2d = result.$3;
    this.wait_time = result.$4;
    this.end_time = result.$5;
    this.currentIndex = result.$6;
    this.flag_all_film_finished = result.$7;

  }
}


// ユーザの入力を受け取るプレイヤー 
class ReceiveInputPlayer extends SuperPlayer {

  // ==============================
  // 🔵 クラス変数（入力保持用）
  // ==============================
  bool isTouching = false;
  Offset? tapPosition;

  @override
  void init() {
    // 初期化（必要なら後で）
  }

  @override
  void mainScript() 
  {
    // ------------------------------
    // 🟢 現在の入力状態を取得して保持
    // ------------------------------
    isTouching = SystemEnvService.isTouching;
    tapPosition = SystemEnvService.tapPosition;
    
    // 入力flagの削除
    SystemEnvService.clearTap();
  }
}


// 邪魔者の座標を更新
class MovingDisturverPlayer extends SuperPlayer {
  // ==============================
  // 🔵 クラス変数
  // ==============================
  // クラス変数
  late Offset disturver_reset_position;
  final Offset anoanoBiasOffset = const Offset(200, 500);
  double disturver_speed = 1; // 邪魔者オブジェクトのスピード

  // 障害物マップを切り替えるの、秒数処理
  int lastSwitchTimeSec = 0;
  int switchIntervalSec = 3; // 3秒ごとに切り替える
  int currentPattern = 1;


  // ==============================
  // フィルム再生用キャッシュ
  // ==============================
  String frame_result = "ok";
  late List<dynamic> list_2d;
  int wait_time = 1;
  int? end_time = null;
  int currentIndex = 0;   // ★追加
  late List<List<List<dynamic>>> item_and_disturver_animation_film_3dlist_1;
  late List<List<List<dynamic>>> item_and_disturver_animation_film_3dlist_2;
  late List<List<List<dynamic>>> item_and_disturver_animation_film_3dlist_3;
  bool item_and_disturver_animation_film_3dlist_1_end = false;
  bool item_and_disturver_animation_film_3dlist_2_end = false;
  bool item_and_disturver_animation_film_3dlist_3_end = false;
  bool flag_all_film_finished = false;

  @override
  void init() {
    list_2d = [];          // ★これを追加
    final screenSize = SystemEnvService.screenSize;

    disturver_reset_position = Offset(
      -screenSize.width / 2,
      screenSize.height / 2,
    );

    // マップPattern１
    this.item_and_disturver_animation_film_3dlist_1 = [
        // 邪魔者の座標を動かす。
        [[world.objects["建物_1"], (this.disturver_reset_position.dx, this.disturver_reset_position.dy, disturver_speed), 1, ObjectManager.toLinearMove],
         [world.objects["UFO_1"], (this.disturver_reset_position.dx, this.disturver_reset_position.dy, disturver_speed), 1, ObjectManager.toLinearMove]],
      ];  

    // マップPattern２
    this.item_and_disturver_animation_film_3dlist_2 = [
        // 邪魔者の座標を動かす。
        [[world.objects["建物_2"], (this.disturver_reset_position.dx, this.disturver_reset_position.dy, disturver_speed), 1, ObjectManager.toLinearMove],
         [world.objects["UFO_2"], (this.disturver_reset_position.dx, this.disturver_reset_position.dy, disturver_speed), 1, ObjectManager.toLinearMove]],
      ];  

    // マップPattern３
    this.item_and_disturver_animation_film_3dlist_3 = [
        // 邪魔者の座標を動かす。
         [[world.objects["建物_3"], (this.disturver_reset_position.dx, this.disturver_reset_position.dy, disturver_speed), 1, ObjectManager.toLinearMove],
          [world.objects["UFO_3"], (this.disturver_reset_position.dx, this.disturver_reset_position.dy, disturver_speed), 1, ObjectManager.toLinearMove]],
      ];
    debugPrint("MovingDisturverPlayerの初期化が完了しました。");
  }

  @override
  void mainScript() 
  {
    debugPrint("▶ ${runtimeType} mainScript スタート");

    final nowSec =
        DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // ==========================================
    // 🔄 一定秒数ごとにパターン切替
    // ==========================================
    if (nowSec - lastSwitchTimeSec >= switchIntervalSec) {

      lastSwitchTimeSec = nowSec;

      currentPattern++;

      if (currentPattern > 3) {
        currentPattern = 1;
      }

      // フィルム状態リセット
      frame_result = "ok";
      end_time = null;

      currentIndex = 0;   // ★これがないと前のindexのまま進みます
    }

    // ==========================================
    // 🎬 現在のパターンを実行
    // ==========================================
    List<List<List<dynamic>>> targetFilm;

    if (currentPattern == 1) {
      targetFilm = item_and_disturver_animation_film_3dlist_1;
    } else if (currentPattern == 2) {
      targetFilm = item_and_disturver_animation_film_3dlist_2;
    } else {
      targetFilm = item_and_disturver_animation_film_3dlist_3;
    }

    final result = AnimationFilmService.runAnimationFilm(
      frame_result,
      targetFilm,
      list_2d,
      wait_time,
      end_time,
      currentIndex,
    );

    frame_result = result.$1;
    targetFilm = result.$2;
    list_2d = result.$3;
    wait_time = result.$4;
    end_time = result.$5;
    currentIndex = result.$6;

  }
}


// ジャンプボタンが押されていたら、キャラをジャンプさせるPlayer 
class GameJumpAnimationPlayer extends SuperPlayer {

  // ==============================
  // 🔵 クラス変数
  // ==============================
  final Offset hiddenOffset = const Offset(-10000, -10000);
  final Offset anoanoBiasOffset = const Offset(200, 500);
  bool flag_jumping_now = false; // ジャンプ中ならばtrueにする。
  bool isGrounded = false; //

  // CollisionResolvePlayer用。
  int currentJumpCount = 0;   // 現在のジャンプ回数
  int maxJumpCount = 2;       // 最大ジャンプ回数
  bool canMoreJump = true;    // 追加ジャンプ可能か


  // ==============================
  // フィルム再生用キャッシュ
  // ==============================
  String frame_result = "ok";
  late List<dynamic> list_2d;
  int wait_time = 1;
  int? end_time = null;
  int currentIndex = 0;   // ★追加
  late List<List<List<dynamic>>> jump_animation_film_3dlist;
  late List<List<List<dynamic>>> more_jump_animation_film_3dlist;
  bool flag_all_film_finished = false;

  @override
  void init() {
    // 初期化（必要なら後で）
    list_2d = [];          // ★これを追加

    // →　[オブジェクト名、代入値(座標等)、待機時間、実行関数]
    this.jump_animation_film_3dlist = [
        // アノアノジャンプ
        [[world.objects["アノアノ輪郭"], (this.anoanoBiasOffset.dx, this.anoanoBiasOffset.dy, 150.0, 0.8, 1, false), 0, ObjectManager.toJump],
         [world.objects["アノアノ口"], (world.objects["アノアノ輪郭"]!, 20, -10), 0, ObjectManager.toFollowWithOffset],
         [world.objects["アノアノ両目_怒"], (world.objects["アノアノ輪郭"]!, 20, -10), 0, ObjectManager.toFollowWithOffset]],
      ];

    // 重複ジャンプ用
    this.more_jump_animation_film_3dlist = [
        // アノアノジャンプ
        [[world.objects["アノアノ輪郭"], (this.anoanoBiasOffset.dx, this.anoanoBiasOffset.dy, 150.0, 0.8, 1, true), 0, ObjectManager.toJump],
         [world.objects["アノアノ口"], (world.objects["アノアノ輪郭"]!, 20, -10), 0, ObjectManager.toFollowWithOffset],
         [world.objects["アノアノ両目_怒"], (world.objects["アノアノ輪郭"]!, 20, -10), 0, ObjectManager.toFollowWithOffset]],
      ];

    debugPrint("GameJumpAnimationPlayerの初期化が完了しました。");
  }

  @override
  void mainScript() 
  {
    // ------------------------------
    // 🟢 
    // ------------------------------
    // プレイヤーの入力flagをプレイヤーから取得
    bool flag_jump_from_user_input = world.receiveInputPlayer.isTouching;

    // このフレームでジャンプの入力があった。
    if (flag_jump_from_user_input){
      
      // でもジャンプ中だった。→二段ジャンプ（重複ジャンプ）の実行
      if (this.flag_jumping_now){
        // 重複ジャンプを実行
        final result = AnimationFilmService.runAnimationFilm(
          this.frame_result,
          this.more_jump_animation_film_3dlist,
          this.list_2d,
          this.wait_time,
          this.end_time,
          this.currentIndex, // ★追加
        );
        this.frame_result = result.$1;
        this.more_jump_animation_film_3dlist = result.$2;
        this.list_2d = result.$3;
        this.wait_time = result.$4;
        this.end_time = result.$5;
        this.currentIndex = result.$6;           // ★追加
        this.flag_all_film_finished = result.$7; // ★$7が完了

        // 重複ジャンプなので、「現在の連続ジャンプ数」をインクリメント。
        this.currentJumpCount++;
      }

      // ジャンプ中ではなかった。→1段ジャンプ（最初のジャンプ）の実行
      else if (!this.flag_jumping_now){
        final result = AnimationFilmService.runAnimationFilm(
          this.frame_result,
          this.jump_animation_film_3dlist,
          this.list_2d,
          this.wait_time,
          this.end_time,
          this.currentIndex, // ★追加
        );

        this.frame_result = result.$1;
        this.jump_animation_film_3dlist = result.$2;
        this.list_2d = result.$3;
        this.wait_time = result.$4;
        this.end_time = result.$5;
        this.currentIndex = result.$6;           // ★追加
        this.flag_all_film_finished = result.$7; // ★$7が完了

        // 「現在の連続ジャンプ数」を１に強制。
        this.currentJumpCount = 1; 
      }

      // ジャンプ開始したので`ジャンプ中フラグ`をオン。
      this.flag_jumping_now = true;    
    }

    // このフレームでジャンプの入力はなかった。
    else if (!flag_jump_from_user_input){

      // でもジャンプ中だった。→ジャンプしてるobjの座標を、ジャンプ関数で更新する。
      if (this.flag_jumping_now){

        // ジャンプ座標を遷移
        final result = AnimationFilmService.runAnimationFilm(
          this.frame_result,
          this.jump_animation_film_3dlist,
          this.list_2d,
          this.wait_time,
          this.end_time,
          this.currentIndex, // ★追加
        );
        this.frame_result = result.$1;
        this.jump_animation_film_3dlist = result.$2;
        this.list_2d = result.$3;
        this.wait_time = result.$4;
        this.end_time = result.$5;
        this.currentIndex = result.$6;           // ★追加
        this.flag_all_film_finished = result.$7; // ★$7が完了
      }

      // ジャンプ中でもなかった。→何もしない。
      else{
      }
    }

    // ジャンプが終了していたら、フラグをオフ。
    if (this.flag_all_film_finished){
      this.flag_jumping_now = false;
    }

  }
}


// オブジェクト同士が衝突していたら、衝突flagを作るプレイヤー
class CollisionGimmickPlayer extends SuperPlayer {

  // 今回の衝突オブジェクトの一覧
  // [衝突obj, 衝突方向]
  late List<(WorldObject, HitSide)> hitList;

  @override
  void init() {
    hitList = [];
  }

  @override
  void mainScript() {

    // 毎フレームリセット
    hitList.clear();

    final objects = [
      world.objects["建物_1"],
      world.objects["建物_2"],
      world.objects["建物_3"],
      world.objects["UFO_1"],
      world.objects["UFO_2"],
      world.objects["UFO_3"],
    ];

    final player = world.objects["アノアノ輪郭"];
    if (player == null) return;

    // -----------------------------
    // 🔁 全オブジェクトをチェック
    // -----------------------------
    for (final obj in objects) {

      if (obj == null) continue;

      final side =
          ComponentsService.hitSide(player, obj);

      if (side != HitSide.none) {

        // ⭐ 衝突情報を保存
        hitList.add((obj, side));
      }
    }

    // -----------------------------
    // 🔥 衝突結果を処理
    // -----------------------------
    for (final hit in hitList) {

      final obj = hit.$1;
      final side = hit.$2;

      switch (side) {

        case HitSide.north:
          // 上から着地
          break;

        case HitSide.south:
          // 下から衝突
          break;

        case HitSide.west:
        case HitSide.east:
          // 横衝突
          break;

        case HitSide.none:
          break;
      }
    }

  }
}


// ==============================================================
// 💥 CollisionResolvePlayer
// --------------------------------------------------------------
// 【役割】
//  CollisionGimmickPlayer が収集した衝突情報をもとに、
//  ・座標補正（物理解決）
//  ・接地状態の管理
//  ・ゲームオーバー判定フラグの更新
//  を行う専用Player。
//
// 【設計思想】
//  ・衝突「検出」と「解決」は分離する
//  ・このクラスは “解決” のみを担当
//  ・副作用は最小限（座標補正とフラグ操作のみ）
//
// 【状態管理対象】
//  ・flag_jumping_now
//  ・isGrounded
//  ・flag_gameover
// ==============================================================
class CollisionResolvePlayer extends SuperPlayer {

  @override
  void init() {
    // 状態を持たないため初期化処理なし
  }

  @override
  void mainScript() {

    // ==========================================================
    // 🎮 プレイヤー（アノアノ輪郭）を取得
    // ==========================================================
    final player = world.objects["アノアノ輪郭"];
    if (player == null) return;

    // ==========================================================
    // 📋 今フレームの衝突一覧を取得
    // （CollisionGimmickPlayer が毎フレーム更新）
    // ==========================================================
    final jumpPlayer = world.gameJumpAnimationPlayer;
    final hitList = world.collisionGimmickPlayer.hitList;

    // ==========================================================
    // 🟢 今フレームで「地面に接触したか」判定用フラグ
    // ==========================================================
    bool touchedGroundThisFrame = false;

    // ==========================================================
    // 🔁 衝突ごとの処理ループ
    // ==========================================================
    for (final hit in hitList) {

      final obj = hit.$1;
      final side = hit.$2;

      switch (side) {

        // ======================================================
        // 🟢 NORTH：上から着地
        // ------------------------------------------------------
        // 状況：
        //   プレイヤーが建物の上面に乗った
        //
        // 処理：
        //   ・Y座標を建物上面に補正
        //   ・ジャンプ終了
        //   ・接地状態ON
        // ======================================================
        case HitSide.north:

          // 建物とプレイヤーのコライダー取得
          final Rect objRect = obj.colliderRect!;
          final Rect playerRect = player.colliderRect!;

          // 建物の上面 - プレイヤー半分高さ
          final double correctedY =
              objRect.top - (playerRect.height / 2);

          // Y座標補正（Xはそのまま）
          player.position = Offset(
            player.position.dx,
            correctedY,
          );

          // ジャンプ状態リセット
          jumpPlayer.flag_jumping_now = false;
          jumpPlayer.isGrounded = true;

          // 🔥 ジャンプ回数リセット
          jumpPlayer.currentJumpCount = 0;
          jumpPlayer.canMoreJump = true;

          touchedGroundThisFrame = true;

          break;


        // ======================================================
        // 🔴 その他衝突 → 即ゲームオーバー
        // ======================================================
        case HitSide.south:
        case HitSide.west:
        case HitSide.east:

          // ゲームオーバープレイヤーのフラグを直接trueにする。
          world.gameoverJudgmentPlayer.flag_gameover = true;
          break;

        case HitSide.none:
          break;
      }
    }

    // ==========================================================
    // 🌪 落下判定（多段ジャンプ考慮）
    // ==========================================================
    if (!touchedGroundThisFrame) {

      jumpPlayer.isGrounded = false;

      // ------------------------------------------------------
      // 落下条件：
      // ・現在ジャンプ中ではない
      // ・追加ジャンプ回数を使い切った
      // ------------------------------------------------------
      final bool shouldFall =
          !jumpPlayer.flag_jumping_now &&
          jumpPlayer.currentJumpCount >= jumpPlayer.maxJumpCount;

      if (shouldFall) {

        ObjectManager.toFall(
          player,
          (5,)  // 落下速度
        );
      }
    }

  }
}


// ==============================================================
// 💀 GameoverJudgmentPlayer
// --------------------------------------------------------------
// 【役割】
//  ・CollisionResolvePlayer が立てた
//    flag_gameover を監視
//  ・ON になったらゲーム終了処理へ移行
//
// 【目的】
//  ・まずはデバッグ用の最小実装
//  ・ゲームオーバー状態を確実に検出する
// ==============================================================
class GameoverJudgmentPlayer extends SuperPlayer {

  // ==========================================================
  // 🔴 ゲームオーバーフラグ
  // CollisionResolvePlayer から ON にされる
  // ==========================================================
  bool flag_gameover = false;

  @override
  void init() {
    // 起動時はゲームオーバーではない
    flag_gameover = false;
  }

  @override
  void mainScript() {
    // 特になし。
  }
}


class GameOverDisplayPlayer extends SuperPlayer {

  late Offset center_down;
  final Offset hidden_xy = const Offset(-10000, -10000);

  @override
  void init() {

    final screenSize = SystemEnvService.screenSize;
    final half = screenSize.width / 2;

    center_down = Offset(
      0,
      screenSize.height / 4,
    );


    ObjectCreator.createImage(
      objectName: "もう一回やる？ボタン",
      assetPath: "assets/images/once_again.png",
      position: hidden_xy,
      width: 250,
      height: 120,
      layer: 600, // 表示順番
    );

    ObjectCreator.createImage(
      objectName: "悲しい右目",
      assetPath: "assets/images/once_again.png",
      position: hidden_xy,
      width: 180,
      height: 80,
      enableCollision: true,
      layer: 350, // 表示順番
    );

    ObjectCreator.createImage(
      objectName: "悲しい左目",
      assetPath: "assets/images/once_again.png",
      position: hidden_xy,
      width: 180,
      height: 80,
      enableCollision: true,
      layer: 351, // 表示順番
    );

    ObjectCreator.createImage(
      objectName: "悲しい口",
      assetPath: "assets/images/once_again.png",
      position: hidden_xy,
      width: 180,
      height: 80,
      rotation: pi,
      enableCollision: true,
      layer: 352, // 表示順番
    );
  }

  @override
  void mainScript() {

    // ================================
    // 🔹 必要オブジェクト取得
    // ================================
    final onceAgainButton = world.objects["もう一回やる？ボタン"];
    final sadRightEye     = world.objects["悲しい右目"];
    final sadLeftEye      = world.objects["悲しい左目"];
    final sadMouth        = world.objects["悲しい口"];

    final angryEyes = world.objects["アノアノ両目_怒"];
    final normalMouth = world.objects["アノアノ口"];

    if (onceAgainButton == null ||
        sadRightEye == null ||
        sadLeftEye == null ||
        sadMouth == null ||
        angryEyes == null ||
        normalMouth == null) return;

    // ================================
    // 🔹 ① ボタンを中央下へ表示
    // ================================
    ObjectManager.toSetPosition(
      onceAgainButton,
      (center_down.dx, center_down.dy),
    );

    // ================================
    // 🔹 ② 怒り目を隠す
    // ================================
    ObjectManager.toSetPosition(
      angryEyes,
      (hidden_xy.dx, hidden_xy.dy),
    );

    // ================================
    // 🔹 ③ 通常口を隠す
    // ================================
    ObjectManager.toSetPosition(
      normalMouth,
      (hidden_xy.dx, hidden_xy.dy),
    );

    // ================================
    // 🔹 ④ 悲しい目を現在位置にコピー
    //    （怒り目の位置を基準にする）
    // ================================
    ObjectManager.toCopyPosition(
      sadRightEye,
      (angryEyes,),
    );

    ObjectManager.toMove(
      sadRightEye,
      (20, 0),
    );

    ObjectManager.toCopyPosition(
      sadLeftEye,
      (angryEyes,),
    );

    ObjectManager.toMove(
      sadLeftEye,
      (-20, 0),
    );

    // ================================
    // 🔹 ⑤ 悲しい口を表示
    // ================================
    ObjectManager.toCopyPosition(
      sadMouth,
      (normalMouth,),
    );

    // 口を反転（念のため毎回指定）
    ObjectManager.toSetRotationDeg(
      sadMouth,
      (180,),
    );
  }
}


class GameOverInputPlayer extends SuperPlayer {

  bool flag_one_more_start_button = false;

  final Offset hidden_xy = const Offset(-10000, -10000);

  @override
  void init() {
    flag_one_more_start_button = false;
  }

  @override
  void mainScript() {

    final button       = world.objects["もう一回やる？ボタン"];
    final sadRightEye  = world.objects["悲しい右目"];
    final sadLeftEye   = world.objects["悲しい左目"];
    final sadMouth     = world.objects["悲しい口"];

    if (button == null ||
        sadRightEye == null ||
        sadLeftEye == null ||
        sadMouth == null) return;

    // ==============================
    // 🖱 クリック判定
    // ==============================
    if (ComponentsService.isClicked(button)) {

      flag_one_more_start_button = true;

      // ==============================
      // 👻 全部 hidden に戻す
      // ==============================

      ObjectManager.toSetPosition(
        button,
        (hidden_xy.dx, hidden_xy.dy),
      );

      ObjectManager.toSetPosition(
        sadRightEye,
        (hidden_xy.dx, hidden_xy.dy),
      );

      ObjectManager.toSetPosition(
        sadLeftEye,
        (hidden_xy.dx, hidden_xy.dy),
      );

      ObjectManager.toSetPosition(
        sadMouth,
        (hidden_xy.dx, hidden_xy.dy),
      );
    }
    
  }
}


// ==============================================================
// 💫 ScheduleMaking（プレイヤーを格納するリスト型自体をこれで作る。）
// ・各Playerのinit()は、初回モード実行時に実行されます。
// ==============================================================
class ScheduleMaking {
  final List<SuperPlayer> players;

  bool _initialized = false;

  ScheduleMaking(this.players);

  void doing() {

    // ============================================
    // 🩵 初期化フェーズ（init）
    // ============================================
    if (!_initialized) {
      for (final player in players) {

        // --- 水色ログ ---
        debugPrint(
          '\x1B[36m[INIT] ${player.runtimeType}\x1B[0m'
        );

        player.init();
      }
      _initialized = true;
    }

    // ============================================
    // 🔵 メイン処理フェーズ（mainScript）
    // ============================================
    for (final player in players) {

      // --- 青ログ ---
      debugPrint(
        '\x1B[34m[MAIN] ${player.runtimeType}\x1B[0m'
      );

      player.mainScript();
    }
  }
}



// ✅ MyApp は「アプリの最上位Widget」。
// この箱（MyApp）を使うときは、
// 中に _MyAppState っていうおもちゃ を入れてね
class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  // StatefulWidget は State（実体）と必ずペアで使われる。
  // createState() は「このWidgetに紐づく実体（State）を生成する」ためのファクトリ。
  @override
  State<MyApp> createState() => _MyAppState();
}


// ✅ こっちが「状態（変数）と処理」を持つ本体
// ・Ticker（Flutterの描画フレームと同期するゲームループ）
// ・スケジュール
// ・update()（ゲームロジック）
// ・build()（画面を作る関数）
// を全部ここに置いてる
class _MyAppState extends State<MyApp>
    with SingleTickerProviderStateMixin {

  // 前回のnext_scheduleが入ってくる。
  ScheduleMaking? before_next_schedule; // 最初は null でOK
  
  // ✅ これは「どのスケジュールを動かすフェーズか」の状態
  String schedule_status = "None";

  // ✅ 毎フレーム update() を呼ぶためのTicker
  late Ticker _ticker;

  // =============================================================
  // initState()：この画面が“最初に作られた瞬間”に1回だけ呼ばれる
  // =============================================================
  @override
  void initState() {
    super.initState();
    // =============================================================
    // モード定義一覧
    // =============================================================


    // APP起動時の初期化モード
    Mode_Init = ScheduleMaking(
      [
        world.initPlayer
      ],
    );

    // ホーム画面の初期化モード
    Mode_HomeInit = ScheduleMaking(
      [
        world.homeInitPlayer
      ],
    );
    
    // ホーム画面モード
    Mode_Home = ScheduleMaking(
      [
        world.homePlayer
      ],
    );

    // ゲームのストーリーを再生するモード。
    Mode_GameStoryMovie = ScheduleMaking(
      [
        world.gameStoryPlayer
      ],
    );

    // ゲームの初期化モード
    Mode_GameInit = ScheduleMaking(
      [
        world.gameInitPlayer
      ],
    );

    // ゲームモード
    Mode_Game = ScheduleMaking(
      [
        world.receiveInputPlayer, // ユーザーからの入力の判断
        world.movingDisturberPlayer, // 邪魔者の座標を遷移
        world.gameJumpAnimationPlayer, // ユーザの入力に対するジャンプ座標処理
        world.collisionGimmickPlayer, // コライダー判定フラグ
        world.collisionResolvePlayer,  // コライダーflagの処理。（例（着地判定の上書き（建物北に衝突→yを建物北（よりちょっと上）に上書き。）））
        world.gameoverJudgmentPlayer // ゲームオーバー判断
      ],
    );

    Mode_GameOver = ScheduleMaking(
      [
        world.gameOverDisplayPlayer, // オブジェクトを消したり増やしたり調整
        world.gameOverInputPlayer // ‘もう一回する‘ボタンがクリックされれば、もう一回やるフラグをONにするプレイヤー。
      ],
    );


    // ✅ Flutterの描画フレームに同期して update() を呼び出す
    // Tickerは「画面のリフレッシュタイミング」と同じ周期で動く
    // 端末が60fpsなら1秒間に約60回 update() が呼ばれる
    // 120fps端末なら約120回呼ばれる（自動調整）
    // ※ Timerのような固定16ms待機ではない
    _ticker = createTicker((elapsed) {
      update();
    });

    // ✅ ゲームループ開始
    _ticker.start();
  }

  void update() {
    // =============================================================
    // モード分岐プログラム
    // =============================================================
    // 変数群
    ScheduleMaking? next_schedule;


    // --------------------------
    // None の場合
    // --------------------------
    if (this.schedule_status == "None") {

      // 画面サイズがまだ取れていないなら待機
      if (SystemEnvService.screenSize == Size.zero) {
        return;
      }

      next_schedule = Mode_Init;
      this.schedule_status = "App起動時の処理完了";
    }


    // --------------------------
    // App起動した
    // --------------------------
    else if (this.schedule_status == "App起動時の処理完了") 
    {
      next_schedule = Mode_HomeInit;
      this.schedule_status = "ホーム初期化完了";
    }

    // --------------------------
    // ホーム初期化完了した
    // --------------------------
    else if (this.schedule_status == "ホーム初期化完了")
    {
      next_schedule = Mode_Home;
      this.schedule_status = "ホーム画面";
    }

    // --------------------------
    // ホーム画面でなにもされていないとき
    // --------------------------
    else if (
          this.schedule_status == "ホーム画面" &&
          world.homePlayer.flag_start_button == false
        ) {

      // ホーム画面に遷移（ホーム画面のままでOK）
      next_schedule = Mode_Home;
      this.schedule_status = "ホーム画面";
    }

    // --------------------------
    // ホーム画面でスタートボタンが押された
    // --------------------------
    else if (
          this.schedule_status == "ホーム画面" &&
          world.homePlayer.flag_start_button == true
        ) {

      // ボタンをもとに戻す。
      world.homePlayer.flag_start_button = false;

      // ストーリーモードに遷移。
      next_schedule = Mode_GameStoryMovie;
      this.schedule_status = "ゲームストーリーモード";

      // もしゲームストーリーの視聴が終わっていたならば、ゲーム初期化モードへ。
      if (world.gameStoryPlayer.flag_story_end){
        next_schedule = Mode_GameInit;
        this.schedule_status = "ゲーム初期化モード";
      }
    }

    // --------------------------
    // ゲームストーリーモードだった。
    // --------------------------
    // かつ、ストーリーの再生が終わった
    else if (
          this.schedule_status == "ゲームストーリーモード" &&
          world.gameStoryPlayer.flag_story_end == true
        ) {

      // ゲーム初期化モードに遷移。
      next_schedule = Mode_GameInit;
      this.schedule_status = "ゲーム初期化モード";
    }
    // まだストーリーが終わっていない
    else if (
          this.schedule_status == "ゲームストーリーモード" &&
          world.gameStoryPlayer.flag_story_end == false
        ) {

      // ゲームストーリーモードのまま。
      next_schedule = Mode_GameInit;
      this.schedule_status = "ゲームストーリーモード";
    }

    // --------------------------
    // ゲームの初期化が完了した
    // --------------------------
    else if (
          this.schedule_status == "ゲーム初期化モード"
        ) {
      // ゲームモードに遷移。
      next_schedule = Mode_Game;
      this.schedule_status = "ゲームモード";
    }

    // --------------------------
    // ゲームが終了した
    // --------------------------
    else if (
          this.schedule_status == "ゲームモード" &&
          world.gameoverJudgmentPlayer.flag_gameover == true
        ) {

      next_schedule = Mode_GameOver;
      this.schedule_status = "ゲームオーバーモード";

      // フラグをもとに戻す。
      world.gameoverJudgmentPlayer.flag_gameover = false;
    }

    // --------------------------
    // ゲーム終了画面で「もう一度やる」ボタンが押された
    // --------------------------
    else if (
      this.schedule_status == "ゲームオーバーモード" &&
      world.gameOverInputPlayer.flag_one_more_start_button == true
    ) {

      world.gameOverInputPlayer.flag_one_more_start_button = false;

      next_schedule = Mode_GameInit;
      this.schedule_status = "ゲームを初期化しました。";
    }

    // =============================================================
    // 選択されたモードを実行
    // なお、各Playerで実行されている内容は
    // world.objects Map の描写書き換えであり、
    // 次のsetState()内のdraw()実行により、ようやく反映されます。
    // =============================================================
    // next_scheduleが前回と異なるかどうかの比較
    final same_before_schedule_mode = (next_schedule == before_next_schedule);

    if (next_schedule != null) {
      if (!same_before_schedule_mode){ // next_scheduleが前回と一緒でなければ、`開始・終了`を表示。
        debugPrint("\n\x1B[35m==== スケジュールモード【${this.schedule_status}】を開始します ============================\x1B[0m");
      }
      
      // =============================================================
      // このスケジュールを実行。
      // =============================================================
      next_schedule.doing(); 

      if (!same_before_schedule_mode){
        debugPrint("\x1B[35m==== スケジュールモード【${this.schedule_status}】を終了します ============================\x1B[0m\n");
      }
    }
    else {
      // =============================================================
      // エラーハンドリング
      // =============================================================
      if (!same_before_schedule_mode){
        debugPrint("\x1B[35m==== 【 ❣❣モード分岐に誤りがあります❣❣ 】============================\x1B[0m");
        debugPrint("\x1B[35m====（next_schedule: ${next_schedule}） ============================\x1B[0m");
        debugPrint("\x1B[35m====（this.schedule_status: ${this.schedule_status}） ============================\x1B[0m");
      }
    }

    // =============================================================
    // 前回実行されたモードの保持。
    // =============================================================
    before_next_schedule = next_schedule; // null もそのまま保持でOK

    // ✅ setState() は「ねぇFlutter、画面を作り直して！」の合図
    // （≒ドローコールの実行）
    // これが呼ばれると、下の build() が再実行される（＝再描画）
    setState(() {});
  }


  // =============================================================
  // build()：Flutterが「画面をどう作るか」を聞きに来る場所
  // =============================================================
  @override
  Widget build(BuildContext context) {

    // =============================================================
    // 📱 端末情報の取得
    // build() 内でしか MediaQuery は安全に取得できない
    // =============================================================
    final size = MediaQuery.of(context).size;
    final orientation = MediaQuery.of(context).orientation;

    SystemEnvService.updateScreenInfo(
      size: size,
      orientation: orientation,
    );

    // =============================================================
    // 🎨 画面の描画
    // MaterialApp は main() 側へ移動済み
    // ここでは Scaffold だけを返す
    // =============================================================
    return Scaffold(
      backgroundColor: Colors.black,

      body: GestureDetector(
        onTapDown: (details) {
          SystemEnvService.setTouching(true);
          SystemEnvService.setTapPosition(details.localPosition);
        },
        onTapUp: (_) => SystemEnvService.setTouching(false),
        onTapCancel: () => SystemEnvService.setTouching(false),

        // update()で更新された world.objects を描画する
        child: WorldRenderer.draw(),
      ),
    );
  }


  // dispose()：この画面が破棄されるとき（アプリ終了/画面移動など）に呼ばれる
  @override
  void dispose() {
    // ✅ Tickerを破棄しないと、画面破棄後もフレームコールが続いて事故る
    _ticker.dispose();
    super.dispose();
  }
}


// ==============================================================
// 🖌️ Renderer（ドローコール）
// ==============================================================
class WorldRenderer {

  static Widget draw() {

    final screenSize = SystemEnvService.screenSize;
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height / 2;

    // 表示する順番を決定。
    final sortedObjects = world.objects.values.toList();
    sortedObjects.sort(
      (a, b) => a.layer.compareTo(b.layer)
    );

    return Stack(
      children: sortedObjects.map((obj) {

        // CircleObject
        if (obj is CircleObject) {
          return Positioned(
            left: centerX + obj.position.dx - obj.size / 2,
            top:  centerY + obj.position.dy - obj.size / 2,
            child: Container(
              width: obj.size,
              height: obj.size,
              decoration: BoxDecoration(
                color: obj.color,
                shape: BoxShape.circle,
              ),
            ),
          );
        }

        // ImageObject
        if (obj is ImageObject) {
          return Positioned(
            left: centerX + obj.position.dx - obj.width / 2,
            top:  centerY + obj.position.dy - obj.height / 2,
            child: Transform.rotate(
              angle: obj.rotation,
              child: Image.asset(
                obj.assetPath,
                width: obj.width,
                height: obj.height,
              ),
            ),
          );
        }

        // GifObject
        if (obj is GifObject) {
          return Positioned(
            left: centerX + obj.position.dx - obj.width / 2,
            top:  centerY + obj.position.dy - obj.height / 2,
            child: Transform.rotate(
              angle: obj.rotation,
              child: Image.asset(
                obj.currentAssetPath,
                width: obj.width,
                height: obj.height,
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      }).toList(),
    );
  }
}


// ==============================================================
// 🖤 Flutter App（ここが「アプリの入口」＆「画面の土台」）
// ==============================================================
void main() {

  // =============================================================
  // ✅ MaterialApp を最外層に配置
  // これで毎フレーム再生成されなくなる
  // =============================================================
  runApp(
    const MaterialApp(
      home: MyApp(),
      debugShowCheckedModeBanner: false,
    ),
  );
}





// =========================================================================
// 🪄 未来の自分へ。
// （独自デザインパターン「CatchBallSchedulePattern」の
// Dartバージョン実装です。(2026年2月09日)）
// =========================================================================
//
// 【① オブジェクトを作成するとき】
// ObjectCreator を使って「世界に存在するオブジェクト」を作る。
// create○○() を呼んだ時点で world に登録され、画面に出現する。
// （メイドイン俺的：ステージに置く感覚）
//
// 例：
// ObjectCreator.createCircle(
//   color: Colors.pink,
//   position: const Offset(50, 80), // 画面左上を (0,0) とした座標
//   size: 50,
// );
//
// ※ Player 側で world.objects.add() を直接呼ぶ必要はない。
// ※ オブジェクトの型も用意しなければならないので注意（コード見ればわかる）

//
// --------------------------------------------------------------
//
// 【② オブジェクトを操作するとき】
// Player は ObjectManager を通して「世界に命令」する。
// Player はオブジェクトを所有せず、
// world に存在するオブジェクト全体に影響を与える役割。
//
// 例：
// for (final obj in world.objects) {
//   if (obj is CircleObject) {
//     ObjectManager.toSetPosition(
//       obj,
//       const Offset(10, 0),
//     );
//   }
// }
//
// ※ 描画は WorldRenderer が毎フレーム自動で行う。
//    UI（Widget）は意識しなくてOK。
//
// --------------------------------------------------------------
//
// 【③ プレイヤーを追加するとき】
// SuperPlayer を継承してクラスを作る。
// init()：ステージ初期化・オブジェクト配置向け（1回だけ）
// mainScript()：ルール・挙動・監視向け（毎フレーム）
//
// 作った Player は ScheduleMaking([...]) に追加すると有効になる。
//
// 例：
// schedule = ScheduleMaking(
//   [
//     PutCircleObjectPlayer("てすと"), // ステージに円を配置
//     // FaceMovingUpPlayer(...)        // ルール用Player（後で追加）
//   ],
//   ondoing: () => setState(() {}),
// );
//
// --------------------------------------------------------------
//
// 【補足：スケジュールについて】
// ScheduleMaking は「ゲームのフェーズ / モード」を表す。
// 今後、init_schedule や game_schedule などを複数用意し、
// 状況に応じて切り替える設計を想定している。
//



