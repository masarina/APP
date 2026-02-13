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
    tapPosition = pos;
  }

  static void clearTap() {
    tapPosition = null;
  }
}


// ==============================================================
// コンポーネントサービス
// (ゲーム世界の「意味のある判断」をする場所)
// ==============================================================
class ComponentsService {

  // -----------------------------
  // 💥 衝突判定
  // -----------------------------
  static bool hit(WorldObject a, WorldObject b) {
    if (!a.enableCollision || !b.enableCollision) return false;
    if (a.colliderRect == null || b.colliderRect == null) return false;

    return a.colliderRect!.overlaps(b.colliderRect!);
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
// ==============================================================
class AnimationFilmService {

  // ============================================================
  // アニメーションフィルムを時間管理込みで実行するメソッド
  // ============================================================
  static
  (
    String newFrameResult,
    List<List<List<dynamic>>> newAnimationFilm3DList,
    List<dynamic> newList2D,
    int newWaitTime,
    int? newEndTime,
    bool isFilmEmpty
  )
  runAnimationFilm(

    // 現在の状態を受け取る
    String frameResult,
    List<List<List<dynamic>>> animationFilm3DList,
    List<dynamic> list2d,
    int waitTime,
    int? endTime,

  ) {

    // ============================================================
    // 待機時間秒カウント開始していなければ、カウント開始。
    // ============================================================
    if (endTime == null){

      // 現在時刻の取得
      int now_time = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // 現在時刻から待機時間秒後を取得
      endTime = now_time + waitTime;
    }

    // ============================================================
    // 待機時間秒経過チェック
    // ============================================================
    int now_time = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    if (endTime <= now_time) {

      // end_timeをnullに戻す。
      endTime = null;

      // 前回フレームが完了していたら次を読む
      if (frameResult == "ok" && animationFilm3DList.isNotEmpty) {
        list2d = animationFilm3DList.removeAt(0);
      }

      frameResult = "None";

      // 抜き取ったフレーム処理。
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
      animationFilm3DList.isEmpty
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
  WorldObject(this.position);

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
  UserOpetationsPlayer userOpetationsPlayer = UserOpetationsPlayer();
}
final world = WorldPool();


// ==============================================================
// 🎨 ObjectManager（Python感覚）
// ============================================================
class ObjectManager {
  // ============================================================
  // クラス変数群
  // ============================================================
  // ジャンプ管理用の辞書
  static final Map<WorldObject, _JumpData> _jumpingObjects = {}; // {obj, 着地予定座標}

  // ============================================================
  // スタティックメソッド群。
  // すべてのメソッドの引数は次のように固定してください。
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
      double x,
      double y,
    ) position,
  ) {
    final (x, y) = position;
    obj.position = Offset(x, y);
    return "ok";
  }

  // ==============================
  // 相対移動（現在位置に足し算）
  // ==============================
  static String toMove(
    WorldObject obj,
    (
      double dx,
      double dy,
    ) moveXY,
  ) {
    final (dx, dy) = moveXY;
    obj.position += Offset(dx, dy);
    return "ok";
  }

  // ==============================
  // 任意角度に設定（度で指定）
  // ==============================
  static String toSetRotationDeg(
    WorldObject obj,
    (
      double degree,
    ) params,
  ) {
    final (degree,) = params;

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
  // "顔の目" の座標を変更したい場合。
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

  // ============================================================
  // ジャンプメソッド（多段ジャンプ拡張対応設計）
  // ※ 任意の座標（targetX, targetY）へジャンプ
  // ※ 指定された target座標 に到達したらジャンプ終了
  // ============================================================
  static String toJump(
      WorldObject obj,
      (
        double targetX, // ジャンプ先の場所座標x
        double targetY, // ジャンプ先の場所座標y
        double jumpPower,
        double durationSec,
        int maxJumpCount
      ) params,
    ) {

    // params展開
    final (
      targetX,
      targetY,
      jumpPower,
      durationSec,
      maxJumpCount
    ) = params;

    final now = DateTime.now().millisecondsSinceEpoch;

    // ------------------------------------------------------------
    // 🟢 初回登録 または 追加ジャンプ判定
    // ------------------------------------------------------------
    
    if (!_jumpingObjects.containsKey(obj)) {

      _jumpingObjects[obj] = _JumpData(
        startX: obj.position.dx,
        startY: obj.position.dy,
        landingX: targetX,
        landingY: targetY,
        startTimeMs: now,
        jumpCount: 1,
      );

    } else {

      if (_jumpingObjects[obj]!.jumpCount < maxJumpCount) {

        _jumpingObjects[obj]!.startX = obj.position.dx;
        _jumpingObjects[obj]!.startY = obj.position.dy;
        _jumpingObjects[obj]!.landingX = targetX;
        _jumpingObjects[obj]!.landingY = targetY;
        _jumpingObjects[obj]!.startTimeMs = now;
        _jumpingObjects[obj]!.jumpCount += 1;
      }
    }


    // ------------------------------------------------------------
    // 🔵 ジャンプ実行
    // ------------------------------------------------------------

    final data = _jumpingObjects[obj]!;

    final elapsedSec = (
        now - data.startTimeMs
        ) / 1000.0;

    final _progress = (
        elapsedSec / durationSec
      );

    final progress = _progress.clamp(0.0, 1.0);

    // ------------------------------------------------------------
    // 横方向移動（線形補間）
    // ------------------------------------------------------------
    final newX = (
        data.startX +
        (data.landingX - data.startX) * progress
      );

    // ------------------------------------------------------------
    // 今この瞬間、基準線から何ピクセル上にいるかを算出
    // ------------------------------------------------------------

    final baseY = (
        data.startY +
        (data.landingY - data.startY) * progress
      );

    final height = (
        4 *
        jumpPower *
        progress * (1 - progress)
      );

    final newY = baseY - height;


    // ------------------------------------------------------------
    // 🔴 着地判定
    // 条件：
    // ① progress が 1.0 を超えた
    // ------------------------------------------------------------
    if (progress >= 1.0) {

      obj.position = Offset(data.landingX, data.landingY);

      _jumpingObjects.remove(obj);

      return "ok";
    }


    // ------------------------------------------------------------
    // 🟢 ジャンプ中更新
    // ------------------------------------------------------------
    obj.position = Offset(newX, newY);

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
  }) : super(position) {
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
  })  : collisionOffset = collisionOffset ?? Offset.zero,
        collisionSize = collisionSize ?? Size(width, height),
        super(position) {
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
  }) : super(position) {
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

    // ⭐ 追加
    bool enableCollision = false,
    Offset? collisionOffset,
    Size? collisionSize,
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
  }) {
    final gif = GifObject(
      position: position,
      assetPaths: assetPaths,
      width: width,
      height: height,
      rotation: rotation,         // ← 渡す
      enableCollision: enableCollision,
    );
    world.objects[objectName] = gif;
  }

}


// ==============================================================
// Players
// ==============================================================
// アプリ起動時の初期化を担うPlayer 
class InitPlayer extends SuperPlayer {
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
    // 背景（画面ぴったり）
    final screenSize = SystemEnvService.screenSize;
    ObjectCreator.createImage(
      objectName: "背景",
      assetPath: "assets/images/kami_free.png",
      position: Offset.zero, // 左上ぴったり
      width: screenSize.width,
      height: screenSize.height,
    );
  }

}


// ホーム画面初期化モード
class HomeInitPlayer extends SuperPlayer {
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
    // 材料の定義
    final screenSize = SystemEnvService.screenSize;

    // 真ん中下にアノアノ
    double bias_x = (screenSize.width / 2) + 70;
    double bias_y = (screenSize.height / 2) + 70;
    ObjectCreator.createImage(
      objectName: "アノアノ右目",
      assetPath: "assets/images/nikkori.png",
      position: Offset(bias_x, bias_y), // 左上ぴったり
      width: 70,
      height: 70,
    );
    ObjectCreator.createImage(
      objectName: "アノアノ左目",
      assetPath: "assets/images/nikkori.png",
      position: Offset(
          bias_x - 3, 
          bias_y + 2
        ), 
      width: 70,
      height: 70,
    );
    ObjectCreator.createImage(
      objectName: "アノアノ口",
      assetPath: "assets/images/nikkori.png",
      position: Offset(
          bias_x - 20, 
          bias_y + 20
        ), 
      width: 83.5,
      height: 65,
      rotation: pi, // pi → 180。0,
    );
    ObjectCreator.createImage(
      objectName: "アノアノ輪郭",
      assetPath: "assets/images/kao_rinnkaku_1.png",
      position: Offset(
          bias_x - 20, 
          bias_y + 20
        ), 
      width: 83.5,
      height: 65,
      rotation: pi, // pi → 180。0,
      enableCollision: true,
    );

    // 下中央に「スタートボタン」
    ObjectCreator.createImage(
      objectName: "スタートボタン",
      assetPath: "assets/images/start.png",
      position: Offset(screenSize.width / 2, screenSize.height * (9/10)),
      width: 70,
      height: 70,
      enableCollision: true,
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
    if (ComponentsService.isClicked(world.objects["スタートボタン"]!)) {
      this.flag_start_button = true;
    }
  }
}


// ゲームストーリーを再生するPlayer
class GameStoryPlayer extends SuperPlayer {
  // class変数
  bool flag_story_end = false;
  double hidden_xy = -10000;

  // 座標管理変数
  Size screenSize = SystemEnvService.screenSize;
  late double bias_x; // late → 意味:「後で代入するので空の初期化だけど許してほしい」
  late double bias_y;

  // フィルム再生用キャッシュ
  String frame_result = "ok";
  late List<dynamic> list_2d;
  int wait_time = 1;
  int? end_time = null;
  late List<List<List<dynamic>>> animation_film_3dlist;

  // __init__(self)に同じ
  @override
  void init() {

    // バイアス座標の作成
    this.bias_x = (screenSize.width / 2) + 75;
    this.bias_y = (screenSize.height / 2) + 70;

    // 使用するオブジェクトの用意
    ObjectCreator.createImage(
      objectName: "ちいさいまる",
      assetPath: "assets/images/maru_tiisai.png",
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: 70,
      height: 70,
    );
    ObjectCreator.createImage(
      objectName: "ちいさいもこもこ",
      assetPath: "assets/images/mokomoko_syou.png",
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: 70,
      height: 70,
    );
    ObjectCreator.createImage(
      objectName: "おおきいもこもこ",
      assetPath: "assets/images/mokomoko_dai.png",
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: 70,
      height: 70,
    );
    ObjectCreator.createImage(
      objectName: "空想アノアノ右目",
      assetPath: "assets/images/nikkori.png",
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: 70,
      height: 70,
    );
    ObjectCreator.createImage(
      objectName: "空想アノアノ左目",
      assetPath: "assets/images/nikkori.png",
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: 70,
      height: 70,
    );
    ObjectCreator.createImage(
      objectName: "空想アノアノ口",
      assetPath: "assets/images/nikkori.png",
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: 70,
      height: 70,
      rotation: pi, // pi → 180。
    );
    ObjectCreator.createGIF(
      objectName: "空想アノアノ羽",
      assetPaths: ["assets/images/hane_1.png","assets/images/hane_2.png"],
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: 70,
      height: 70,
    );
    ObjectCreator.createImage(
      objectName: "アノアノ両目_怒",
      assetPath: "assets/images/me_sikame.png",
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: 70,
      height: 70,
    );

    // アニメーションフィルムの作成
    int jump_height = 8;
    double jump_time = 0.3;

    // →　[オブジェクト名、代入値(座標等)、待機時間、実行関数]
    this.animation_film_3dlist = [
        // 空想もこもこ表示
        [[world.objects["ちいさいまる"], (this.bias_x, this.bias_y), 1, ObjectManager.toSetPosition]],
        [[world.objects["ちいさいもこもこ"], (this.bias_x + 10, this.bias_y + 12), 1, ObjectManager.toSetPosition]],
        [[world.objects["おおきいもこもこ"], (this.bias_x + 20, this.bias_y + 70), 1, ObjectManager.toSetPosition]],
        
        // 空想アノアノの出現
        [[world.objects["空想アノアノ右目"], (this.bias_x + 15, this.bias_y + 60), 0, ObjectManager.toSetPosition], 
         [world.objects["空想アノアノ右目"], (this.bias_x + 25, this.bias_y + 60), 0,ObjectManager.toSetPosition],
         [world.objects["空想アノアノ口"], (this.bias_x + 20, this.bias_y + 65), 1, ObjectManager.toSetPosition]],
        [[world.objects["空想アノアノ羽"], (this.bias_x + 35, this.bias_y + 40), 3, ObjectManager.toSetPosition]],
        
        // 現実アノアノが本気の顔になる
        [[world.objects["アノアノ両目_怒"], world.objects["アノアノ右目"], 0, ObjectManager.toCopyPosition], // 時間指定意味ないが、気休めに０を代入。
         [world.objects["アノアノ両目_怒"], (5, 0), 0, ObjectManager.toMove], // 時間指定意味ないが、気休めに０を代入。
         [world.objects["アノアノ右目"], (-1000, -1000), 0, ObjectManager.toSetPosition], 
         [world.objects["アノアノ左目"], (-1000, -1000), 1, ObjectManager.toSetPosition]],  
        
        // 現実アノアノが高ぶるいする（ちょっと2回ジャンプする。）
        [[world.objects["アノアノ両目_怒"],
          (
            world.objects["アノアノ両目_怒"]!.position.dx, // ジャンプ先x座標
            world.objects["アノアノ両目_怒"]!.position.dy, // ジャンプ先y座標
            jump_height,
            jump_time,
            1
          ),
          0,
          ObjectManager.toJump],
         [world.objects["アノアノ口"],
          (
            world.objects["アノアノ口"]!.position.dx, // ジャンプ先x座標
            world.objects["アノアノ口"]!.position.dy, // ジャンプ先y座標
            jump_height,
            jump_time,
            1
          ),
          0,
          ObjectManager.toJump],
         [world.objects["アノアノ輪郭"],
          (
            world.objects["アノアノ輪郭"]!.position.dx, // ジャンプ先x座標
            world.objects["アノアノ輪郭"]!.position.dy, // ジャンプ先y座標
            jump_height,
            jump_time,
            1
          ),
          0,
          ObjectManager.toJump]
        ]
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
    );
    this.frame_result = result.$1;
    this.animation_film_3dlist = result.$2;
    this.list_2d = result.$3;
    this.wait_time = result.$4;
    this.end_time = result.$5;
    this.flag_story_end = result.$6;
  }
}


// ゲームオブジェクトをリセット地点に置くプレイヤー。 
class GameInitPlayer extends SuperPlayer {
  // クラス変数
  final Offset hiddenOffset = const Offset(-10000, -10000);
  final Offset anoanoBiasOffset = const Offset(200, 500);

  // フィルム再生用キャッシュ
  String frame_result = "ok";
  late List<dynamic> list_2d;
  int wait_time = 1;
  int? end_time = null;
  late List<List<List<dynamic>>> animation_film_3dlist;
  bool flag_all_film_finished = false;

  // __init__(self)に同じ
  @override
  void init() {
    // アニメーションフィルムの作成
    // →　[オブジェクト名、代入値(座標等)、待機時間、実行関数]
    this.animation_film_3dlist = [

        // 空想隠す。
        [[world.objects["ちいさいまる"], (this.hiddenOffset.dx, this.hiddenOffset.dy), 1, ObjectManager.toMove],
         [world.objects["ちいさいもこもこ"], (this.hiddenOffset.dx, this.hiddenOffset.dy), 1, ObjectManager.toMove],
         [world.objects["おおきいもこもこ"], (this.hiddenOffset.dx, this.hiddenOffset.dy), 1, ObjectManager.toMove],
         [world.objects["空想アノアノ右目"], (this.hiddenOffset.dx, this.hiddenOffset.dy), 1, ObjectManager.toMove],
         [world.objects["空想アノアノ口"], (this.hiddenOffset.dx, this.hiddenOffset.dy), 1, ObjectManager.toMove],
         [world.objects["空想アノアノ羽"], (this.hiddenOffset.dx, this.hiddenOffset.dy), 1, ObjectManager.toMove]],

        // 既に存在するゲームオブジェクトを初期位置に移動させる。
        [[world.objects["アノアノ両目_怒"], (this.anoanoBiasOffset, this.anoanoBiasOffset), 1, ObjectManager.toJump],
         [world.objects["アノアノ口"], (this.anoanoBiasOffset, this.anoanoBiasOffset), 1, ObjectManager.toJump],
         [world.objects["アノアノ輪郭"], (this.anoanoBiasOffset, this.anoanoBiasOffset), 1, ObjectManager.toJump]],
      ];  
  }
  // 非同期サービスの開始
  
  @override
  void mainScript() 
  {
    // ============================================
    // 邪魔オブジェクトの生成（見えないところに。）
    // ============================================
    // 建物
    ObjectCreator.createGIF(
      objectName: "建物",
      assetPaths: [
          "assets/images/tatemono_1.png",
          "assets/images/tatemono_2.png",
        ],
      position: Offset(this.hiddenOffset.dx, this.hiddenOffset.dy),
      width: 500,
      height: 1000,
      enableCollision: true,
    );
    // UFO
    ObjectCreator.createGIF(
      objectName: "UFO",
      assetPaths: [
          "assets/images/ufo_1.png",
          "assets/images/ufo_2.png",
        ],
      position: Offset(this.hiddenOffset.dx, this.hiddenOffset.dy),
      width: 500,
      height: 1000,
      enableCollision: true,
    );

    // ============================================
    // ゲームの初期化
    // ============================================
    final result = AnimationFilmService.runAnimationFilm(
      this.frame_result,
      this.animation_film_3dlist,
      this.list_2d,
      this.wait_time,
      this.end_time,
    );
    this.frame_result = result.$1;
    this.animation_film_3dlist = result.$2;
    this.list_2d = result.$3;
    this.wait_time = result.$4;
    this.end_time = result.$5;
    this.flag_all_film_finished = result.$6;
  }
}


// ==============================================================
// 💫 ScheduleMaking（プレイヤーを格納するリスト型自体をこれで作る。）
// ==============================================================
class ScheduleMaking {
  final List<SuperPlayer> players;

  bool _initialized = false;

  ScheduleMaking(this.players);

  void doing() {
    // このApp一番最初の処理であれば、処理。
    if (!_initialized) {
      for (final player in players) {
        player.init();
      }
      _initialized = true;
    }

    // このモードのplayerのmainをすべて実行。
    for (final player in players) {
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
        world.userOpetationsPlayer
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
    late ScheduleMaking next_schedule; // 実行するscheduleが入る。

    // None の場合
    if (this.schedule_status == "None") {
      // Appの起動時の処理を実行する。
      next_schedule = Mode_Init;
      this.schedule_status = "App起動時の処理完了";
    } 

    // App起動した
    else if (this.schedule_status == "App起動時の処理完了") 
    {
      // ホーム画面に移行。
      next_schedule = Mode_HomeInit;
      this.schedule_status = "ホーム画面";
    }

    // ホーム画面でスタートボタンが押された
    else if (
          this.schedule_status == "ホーム画面" &&
          world.homePlayer.flag_start_button == true
        ) {

      // ボタンをもとに戻す。
      world.homePlayer.flag_start_button = false;

      // ゲームを初期化モードに遷移。
      next_schedule = Mode_GameInit;
      this.schedule_status = "ホームのスタートがクリックされました。";
    }

    // ホーム画面でスタートボタンが押された、
    else if (
          this.schedule_status == "ホームのスタートがクリックされました。"
        ) {

      // ゲーム初期化モードに遷移。
      next_schedule = Mode_GameInit;
      this.schedule_status = "ゲーム初期化モード";

      // もしゲームストーリーの視聴がまだならば、ゲームストーリー再生モードへ。
      if (world.gameStoryPlayer.flag_story_end == false){
        next_schedule = Mode_GameStoryMovie;
        this.schedule_status = "ゲームストーリーモード";
      }
    }

    // ゲームストーリーが再生し終わった。
    else if (
          this.schedule_status == "ゲームストーリーモード" &&
          world.gameStoryPlayer.flag_story_end == true
        ) {

      // ゲーム初期化モードに遷移。
      next_schedule = Mode_GameInit;
      this.schedule_status = "ゲーム初期化モード";
    }

    // ゲームの初期化が完了した
    else if (
          this.schedule_status == "ゲーム初期化モード"
        ) {
      // ゲームモードに遷移。
      next_schedule = Mode_Game;
      this.schedule_status = "ゲームモード";
    }

    // ゲームが終了した
    else if (
          this.schedule_status == "ゲームモード"
        ) {
      // ゲームオーバーモードに遷移。
      next_schedule = Mode_GameOver;
      this.schedule_status = "ゲームオーバーモード";
    }

    // ゲーム終了画面で「もう一度やる」ボタンが押された
    else if (
          this.schedule_status == "ゲームオーバーモード" &&
          gameButtons.flag_one_more_start_button == true
        ) {
      // ボタンを初期化
      gameButtons.flag_one_more_start_button = false;

      // ゲーム初期化に遷移。
      next_schedule = Mode_GameInit;
      this.schedule_status = "ゲームを初期化しました。";
    }


    // =============================================================
    // 選択されたモードを実行
    // なお、各Playerで実行されている内容は
    // world.objects Map の描写書き換えであり、
    // 次のsetState()内のdraw()実行により、ようやく反映されます。
    // =============================================================
    next_schedule.doing(); // このスケジュールの実行。


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
    /*
      update()で更新されたworld.objects Mapをdrawする。
      build() は “今のworldの状態を表示する” だけ、という方向でいこう。
    */

    // =============================================================
    // 端末データの取得（ここでしか取得できないので、しょうがない。）
    // =============================================================
    final size = MediaQuery.of(context).size;
    final orientation = MediaQuery.of(context).orientation;

    SystemEnvService.updateScreenInfo(
      size: size,
      orientation: orientation,
    );

    return MaterialApp(
      // ✅ MaterialApp：アプリ全体の枠（テーマ/画面遷移などの土台）
      home: Scaffold(
        // ✅ Scaffold：1画面の土台（背景、body、AppBarなどを置ける）
        backgroundColor: const Color.fromARGB(255, 56, 179, 144),

        // ✅ body：この画面の“中身”
        // 下のdraw()を呼び出している。
        body: GestureDetector(
          onTapDown: (details) {
            SystemEnvService.setTouching(true);
            SystemEnvService.setTapPosition(details.localPosition);
          },
          onTapUp: (_) => SystemEnvService.setTouching(false),
          onTapCancel: () => SystemEnvService.setTouching(false),
          child: WorldRenderer.draw(),
        ),
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
    return Stack(
      children: world.objects.values.map((obj) {

        // CircleObjectの描写
        if (obj is CircleObject) {
          return Positioned(
            left: obj.position.dx,
            top: obj.position.dy,
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

        // ImageObjectの描写
        if (obj is ImageObject) {
          return Positioned(
            left: obj.position.dx,
            top: obj.position.dy,
            child: Transform.rotate(
              angle: obj.rotation, // ← ラジアン
              child: Image.asset(
                obj.assetPath,
                width: obj.width,
                height: obj.height,
              ),
            ),
          );
        }

        // GifObjectの描写
        if (obj is GifObject) {
          return Positioned(
            left: obj.position.dx,
            top: obj.position.dy,
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

        // ★ これが必須
        return const SizedBox.shrink();
      }).toList(),
    );
  }
}


// ==============================================================
// 🖤 Flutter App（ここが「アプリの入口」＆「画面の土台」）
// ==============================================================
void main() {
  // ✅ Flutterアプリを起動する“スイッチ”。
  //
  // プログラムが起動したら
  // Flutterを立ち上げて
  // 「MyApp という画面構造」を
  // アプリとして表示しなさい。
  //
  // runApp() に渡した Widget（= 画面部品ツリーの根っこ）から画面が作られる
  runApp(const MyApp()); // runApp
                         // → Flutterが用意している関数。
                         // → 「画面を表示する処理を開始する」ためのもの。
                         //
                         // 【流れ】
                         // runApp(MyApp)
                         //   ↓
                         // Flutterエンジン起動
                         //   ↓
                         // 画面ツリー（Widgetツリー）作成
                         //   ↓
                         // OSの画面に表示
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



