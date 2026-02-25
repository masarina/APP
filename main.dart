import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/scheduler.dart';


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

class DebugFlags {
  static bool showColliders = true; 
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


// ============================================================
// 🎬 アニメーション辞書クラス
// ============================================================
class AnimationDict {
  static double hidden_xy = -10000.0;

  // ----------------------------------------------------------
  // 🧩 複数の3次元リスト（フィルム）を受け取り、
  // それらを 1つの3次元リストにまとめる（連結する）
  //
  // 使い方：
  // final film = AnimationFilmService.match3d([filmA, filmB, filmC]);
  // ----------------------------------------------------------
  static List<List<List<dynamic>>> match3d(
    List<List<List<List<dynamic>>>> films,
  ) {
    return films.expand((f) => f).toList();
  }

  // ----------------------------------------------------------
  // 🧩 引数に複数二次元リストを取り、
  // すべてをまとめて一つの二次元リストに変換するメソッド
  // ----------------------------------------------------------
  static List<List<dynamic>> match2d(
      List<List<List<dynamic>>> lists) {
    return lists.expand((e) => e).toList();
  }

  // ----------------------------------------------------------
  // 🗂 アニメーションテンプレート辞書
  // ----------------------------------------------------------
  static final Map<String, List<List<dynamic>>> _dict = {

    "もこもこ全解除": [
      [world.objects["ちいさいまる"], (ObjectManager.toFollowWithOffset,), 0, ObjectManager.clearRunningTaskByFunc], // 追従の解除
      [world.objects["ちいさいもこもこ"], (ObjectManager.toFollowWithOffset,), 0, ObjectManager.clearRunningTaskByFunc], // 追従の解除
      [world.objects["おおきいもこもこ"], (ObjectManager.toFollowWithOffset,), 0, ObjectManager.clearRunningTaskByFunc] // 追従の解除
    ],

    "もこもこ全隠し": [
      [world.objects["ちいさいまる"], (hidden_xy, hidden_xy), 0, ObjectManager.toMove], //
      [world.objects["ちいさいもこもこ"], (hidden_xy, hidden_xy), 0, ObjectManager.toMove], //
      [world.objects["おおきいもこもこ"], (hidden_xy, hidden_xy), 0, ObjectManager.toMove] //
    ],

    "表情追従全解除": [
      [world.objects["アノアノ右目"], (ObjectManager.toFollowWithOffset,), 0, ObjectManager.clearRunningTaskByFunc], // 追従の解除
      [world.objects["アノアノ左目"], (ObjectManager.toFollowWithOffset,), 0, ObjectManager.clearRunningTaskByFunc], // 追従の解除
      [world.objects["アノアノ口"], (ObjectManager.toFollowWithOffset,), 0, ObjectManager.clearRunningTaskByFunc], // 追従の解除
      [world.objects["アノアノ両目_怒"], (ObjectManager.toFollowWithOffset,), 0, ObjectManager.clearRunningTaskByFunc], // 追従の解除
      [world.objects["空想アノアノ右目"], (ObjectManager.toFollowWithOffset,), 0, ObjectManager.clearRunningTaskByFunc], // 追従の解除
      [world.objects["空想アノアノ左目"], (ObjectManager.toFollowWithOffset,), 0, ObjectManager.clearRunningTaskByFunc], // 追従の解除
      [world.objects["空想アノアノ口"], (ObjectManager.toFollowWithOffset,), 0, ObjectManager.clearRunningTaskByFunc], // 追従の解除
      [world.objects["空想アノアノ羽"], (ObjectManager.toFollowWithOffset,), 0, ObjectManager.clearRunningTaskByFunc] // 追従の解除
    ],

    "表情全隠し": [
      [world.objects["アノアノ右目"], (hidden_xy, hidden_xy), 0, ObjectManager.toSetPosition], // 目を退避
      [world.objects["アノアノ左目"], (hidden_xy, hidden_xy), 0, ObjectManager.toSetPosition], // 目を退避
      [world.objects["アノアノ口"], (hidden_xy, hidden_xy), 0, ObjectManager.toSetPosition], // 目を退避
      [world.objects["アノアノ両目_怒"], (hidden_xy, hidden_xy), 0, ObjectManager.toSetPosition], // 目を退避
      [world.objects["空想アノアノ右目"], (hidden_xy, hidden_xy), 0, ObjectManager.toSetPosition], // 目を退避
      [world.objects["空想アノアノ左目"], (hidden_xy, hidden_xy), 0, ObjectManager.toSetPosition], // 目を退避
      [world.objects["空想アノアノ口"], (hidden_xy, hidden_xy), 0, ObjectManager.toSetPosition], // 目を退避
      [world.objects["空想アノアノ羽"], (hidden_xy, hidden_xy), 0, ObjectManager.toSetPosition] // 目を退避
    ],

    "真剣顔": [
      [world.objects["アノアノ両目_怒"], (world.objects["アノアノ輪郭"]!, 11, 2), 0, ObjectManager.toFollowWithOffset], // 顔の輪郭に追従させる。
      [world.objects["アノアノ右目"], (hidden_xy, hidden_xy), 0, ObjectManager.toSetPosition], // 目を退避
      [world.objects["アノアノ左目"], (hidden_xy, hidden_xy), 1, ObjectManager.toSetPosition], // 目を退避
      [world.objects["アノアノ口"], (world.objects["アノアノ輪郭"]!, 19, 27), 0, ObjectManager.toFollowWithOffset]
    ],

    "ニコニコ笑顔": [
      [world.objects["アノアノ右目"], (180,), 0, ObjectManager.toAddRotationDeg],
      [world.objects["アノアノ左目"], (180,), 0, ObjectManager.toAddRotationDeg],
      [world.objects["アノアノ右目"], (world.objects["アノアノ輪郭"]!, 11, 22), 0, ObjectManager.toFollowWithOffset],
      [world.objects["アノアノ左目"], (world.objects["アノアノ輪郭"]!, 27, 22), 0, ObjectManager.toFollowWithOffset],
      [world.objects["アノアノ口"], (world.objects["アノアノ輪郭"]!, 19, 27), 0, ObjectManager.toFollowWithOffset]
    ],

    "悲しい顔": [
      [world.objects["アノアノ右目"], (world.objects["アノアノ輪郭"]!, 11, 22), 0, ObjectManager.toFollowWithOffset],
      [world.objects["アノアノ左目"], (world.objects["アノアノ輪郭"]!, 27, 22), 0, ObjectManager.toFollowWithOffset],
      [world.objects["アノアノ口"], (world.objects["アノアノ輪郭"]!, 4, 12), 0, ObjectManager.toFollowWithOffset],
      [world.objects["アノアノ口"], (180,), 0, ObjectManager.toAddRotationDeg],
    ],

    "羽アノアノ": [
      [world.objects["空想アノアノ右目"], (world.objects["空想アノアノ輪郭"]!, -4, 2), 0, ObjectManager.toFollowWithOffset],
      [world.objects["空想アノアノ左目"], (world.objects["空想アノアノ輪郭"]!, 15, 2), 0, ObjectManager.toFollowWithOffset],
      [world.objects["空想アノアノ口"], (world.objects["空想アノアノ輪郭"]!, 25, 34), 0, ObjectManager.toFollowWithOffset],
      [world.objects["空想アノアノ羽"], (world.objects["空想アノアノ輪郭"]!, -25, -5), 3, ObjectManager.toFollowWithOffset]
    ],
  };

  // ----------------------------------------------------------
  // 🎁 取得メソッド
  // ----------------------------------------------------------
  static List<List<dynamic>> get(String key) {
    if (!_dict.containsKey(key)) {
      throw Exception("AnimationDict に [$key] は存在しません");
    }
    return _dict[key]!;
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

  // ============================================================
  // 🔎 world.objects の中から「このオブジェクトの名前（キー）」を探す
  // 見つからなければ "(unknown)" を返す
  // ============================================================
  static String getObjectName(WorldObject obj) {
    for (final entry in world.objects.entries) {
      if (identical(entry.value, obj)) {
        return entry.key;
      }
    }
    return "(unknown)";
  }


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


  // ============================================================
  // 📌 base に一番近いオブジェクトを candidates から探す
  // ・candidates が空なら null
  // ・base 自身が入っていても除外したいなら除外オプションも付けられる
  // ============================================================
  static WorldObject? nearestObject(
    WorldObject base,
    List<WorldObject> candidates, {
    bool excludeSelf = true, // base 自身が混ざってたら除外する
  }) {
    if (candidates.isEmpty) return null;

    WorldObject? nearest;
    double bestDist2 = double.infinity;

    for (final o in candidates) {
      if (excludeSelf && identical(o, base)) continue;

      final dx = o.position.dx - base.position.dx;
      final dy = o.position.dy - base.position.dy;
      final dist2 = dx * dx + dy * dy; // sqrtしない（二乗距離で比較）

      if (dist2 < bestDist2) {
        bestDist2 = dist2;
        nearest = o;
      }
    }

    return nearest;
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
// ・ジャンプ等で秒数0以外に設定すると、
// 　コマ送りのようになるので、使用しないでください。
// ・前の行の関数の実行が終了されていない場合、次の行は実行されません。
//   →（ジャンプ中など。なお、複数ジャンプメソッドの場合は、
// 　　　最後のジャンプでfunkの戻り値が"ok"になります。）
//
// ==============================================================
class AnimationFilmService {
  static
  (
    String newFrameResult,
    List<List<List<dynamic>>> newAnimationFilm3DList,
    List<dynamic> newList2D,
    int newWaitTime,
    int? newEndTime,
    int newCurrentIndex,
    bool isFilmEmpty
  ) runAnimationFilm(
    String frameResult,
    List<List<List<dynamic>>> animationFilm3DList,
    List<dynamic> list2d,
    int waitTime,
    int? endTime,
    int currentIndex,
  ) {

    final nowSec =
        DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // ===========================
    // ⏱ 待機開始
    // ===========================
    if (endTime == null) {
      endTime = nowSec + waitTime;
    }

    // ===========================
    // ⏱ 実行タイミング
    // ===========================
    debugPrint("0");
    debugPrint("$endTime");
    debugPrint("$nowSec");
    
    if (endTime <= nowSec) {
      debugPrint("1");
      endTime = null;

      // ===========================
      // 🔵 次フレーム取得
      // ===========================
      // 前回のが"ok"でかつ、まだ３次元リストが終了してない場合。
      if (frameResult == "ok" &&
          currentIndex < animationFilm3DList.length) {
        
        debugPrint("2");

        // ３次元リストから２次元リストを取得。
        list2d = animationFilm3DList[currentIndex];
        currentIndex++;
      }

      // frameResult を ok で初期化。
      frameResult = "ok";


      // ===========================
      // 🟡 ① 二次元リストを実行
      // ===========================
      for (final cell in list2d) {

        final Function func = cell[3];
        final WorldObject obj = cell[0];
        final dynamic value = cell[1];

        final result = func(obj, value);
        waitTime = cell[2];


        // resultがrunningだった場合は、リストに追加。
        if (result == "running") {
          ObjectManager.addRunningTask(obj, func, value);
        }
      }
      // (二次元リストをすべて実行した)
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


  // ============================================================
  // 🐇 秒無視・スキップ版：同一フレームで最後まで流す
  //
  // ・waitTime/endTime を無視
  // ・各コマを順に取り出して実行し、最後まで消化
  // ・無限ループ防止の maxSteps を入れる
  //
  // 使い方：
  // final r = AnimationFilmService.runAnimationFilmSkipTime(
  //   frame_result, film3d, list2d, wait_time, end_time, currentIndex,
  // );
  // ============================================================
  static (
    String newFrameResult,
    List<List<List<dynamic>>> newAnimationFilm3DList,
    List<dynamic> newList2D,
    int newWaitTime,
    int? newEndTime,
    int newCurrentIndex,
    bool isFilmEmpty
  ) runAnimationFilmSkipTime(
    String frameResult,
    List<List<List<dynamic>>> animationFilm3DList,
    List<dynamic> list2d,
    int waitTime,
    int? endTime,
    int currentIndex, {
    int maxSteps = 100000, // 安全装置（大きめ）
  }) {
    // 秒関連は無効化
    endTime = null;
    waitTime = 0;
    frameResult = "ok";

    int steps = 0;

    // フィルムが終わるまで “同一フレームで” 回す
    while (currentIndex < animationFilm3DList.length) {
      if (steps++ > maxSteps) {
        // 無限ループ対策：危険なので止める
        // debugPrint等で気づけるようにする
        debugPrint("⚠ runAnimationFilmSkipTime: maxStepsに到達。フィルムが無限/過大の可能性");
        break;
      }

      // 次コマ取得
      list2d = animationFilm3DList[currentIndex];
      currentIndex++;

      // 1コマ実行（待機時間は完全無視）
      for (final cell in list2d) {
        final Function func = cell[3];
        final WorldObject obj = cell[0];
        final dynamic value = cell[1];

        final result = func(obj, value);

        // "running" は従来通り runningTasks に積む
        if (result == "running") {
          ObjectManager.addRunningTask(obj, func, value);
        }
      }
    }

    final finished = (currentIndex >= animationFilm3DList.length);

    return (
      "ok",
      animationFilm3DList,
      list2d,
      0,     // waitTimeは無意味なので0固定
      null,  // endTimeも無意味なのでnull固定
      currentIndex,
      finished
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

// ✅ 追加：デバッグ用の「赤い四角」表示オブジェクト
class DebugColliderImageObject extends ImageObject {
  DebugColliderImageObject({
    required super.position,
    required super.assetPath, // デバッグ用の四角いコライダー判定。
    required super.width,
    required super.height,
    super.rotation = 0.0,
    super.layer = 999999999,
  }) : super(enableCollision: false); // ←デバッグ表示は当たり判定いらない
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

  // ✅ 追加：当たり判定可視化用の付属オブジェクト
  WorldObject? debugColliderVisual;

  // ✅ 追加：付属オブジェクトをまとめて隠す/出す用（任意）
  void setDebugVisible(bool visible) {
    if (debugColliderVisual == null) return;
    debugColliderVisual!.layer = visible ? (layer + 999999) : debugColliderVisual!.layer;
  }
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
  GameFlagPlayer gameFlagPlayer = GameFlagPlayer(); // ゲーム中のフラグを保持するプレイヤー。
  ReceiveInputPlayer receiveInputPlayer = ReceiveInputPlayer(); // ユーザからの入力判断
  MovingDisturverPlayer movingDisturberPlayer = MovingDisturverPlayer(); // 邪魔者の座標を更新
  CollisionGimmickPlayer collisionGimmickPlayer = CollisionGimmickPlayer(); // コライダー判定フラグ
  AdjustFlagPlayer adjustFlagPlayer = AdjustFlagPlayer(); // コライダー判定フラグ処理
  GameJumpAnimationPlayer gameJumpAnimationPlayer = GameJumpAnimationPlayer(); // ユーザからの入力判断
  GameFallAnimationPlayer  gameFallAnimationPlayer  = GameFallAnimationPlayer(); // ユーザからの入力判断
  GameoverJudgmentPlayer gameoverJudgmentPlayer = GameoverJudgmentPlayer(); // ユーザからの入力判断
  GameOverDisplayPlayer gameOverDisplayPlayer = GameOverDisplayPlayer(); // ゲームオーバーの画面を作る。
  GameOverInputPlayer gameOverInputPlayer = GameOverInputPlayer(); // ゲームオーバー画面でのユーザからの入力操作で動く。
}
final world = WorldPool();


// ============================================================== 
// ObjectManagerのためのサブクラス群 
// ============================================================== 
class _RunningTask {
  final WorldObject obj;
  final Function func;
  final dynamic value;

  _RunningTask(this.obj, this.func, this.value);
}
// ============================================================== 
// 🎨 ObjectManager（Python感覚）
// （---------------------------------------------
//   ・junmメソッド
// 　・ほかのオブジェクトに追従メソッド
// 　・地点Aから地点Bに移動メソッド
//   ---------------------------------------------
// 　等の、毎フレーム実行する必要があるメソッドは、
// 　戻り値を次のようにしてください。
//   ---------------------------------------------
// 　・完了したときの戻り値(例:jumpが完了した)→"ok"
// 　・まだ完了していない時の戻り値(例:まだjump中)→"running"
//   ---------------------------------------------
// ============================================================== 
class ObjectManager {
  // ============================================================
  // クラス変数群
  // ============================================================

  // ジャンプ管理用の辞書
  static final Map<WorldObject, _JumpData> _jumpingObjects = {}; // {obj, 着地予定座標}

  // 一次関数移動管理用の辞書
  static final Map<WorldObject, _MoveData> _movingObjects = {}; // {obj, 着地予定座標}

  // 戻り値が"running"のリストを保持するリスト。（この中にjump等の、‘毎フレーム実行必須‘モノが格納される。）
  static final List<_RunningTask> _runningTasks = [];


  // ============================================================
  // ✅ runningTasks 内に、指定した関数が1つでもあれば false
  // （＝指定関数が1つも無ければ true）
  // ============================================================
  static bool hasNoRunningTasksOfFuncs(List<Function> funcs) {
    for (final t in _runningTasks) {
      for (final f in funcs) {
        if (identical(t.func, f)) {
          return false;
        }
      }
    }
    return true;
  }


  // ============================================================
  // ✅ runningTasks 内に、(obj, func) が1つでもあれば false
  // （＝指定ペアが1つも無ければ true）
  // ============================================================
  static bool hasNoRunningTasksOfObjAndFuncs(
    WorldObject obj,
    List<Function> funcs,
  ) {
    for (final t in _runningTasks) {
      if (!identical(t.obj, obj)) continue;

      for (final f in funcs) {
        if (identical(t.func, f)) {
          return false;
        }
      }
    }
    return true;
  }


  // ==============================
  // 🗑 オブジェクト削除（自分自身）
  // [[world.objects["スキップボタン"]!, (true,), 0, ObjectManager.toRemoveSelf]],
  // ==============================
  static String toRemoveSelf(
    WorldObject obj,
    (
      bool removeDebugVisual, // 付属デバッグも消すか
    ) params,
  ) {
    final (removeDebugVisual,) = params;

    // ① runningTasks から obj 関連を全部消す
    _runningTasks.removeWhere((t) => identical(t.obj, obj));

    // ② 移動・ジャンプ管理からも消す（保険）
    _jumpingObjects.remove(obj);
    _movingObjects.remove(obj);

    // ③ debugColliderVisual も消す
    if (removeDebugVisual && obj.debugColliderVisual != null) {
      final vis = obj.debugColliderVisual!;
      // vis 自身のタスクも消す
      _runningTasks.removeWhere((t) => identical(t.obj, vis));
      _jumpingObjects.remove(vis);
      _movingObjects.remove(vis);

      // world から vis を削除（キー検索）
      final visKey = ComponentsService.getObjectName(vis);
      if (visKey != "(unknown)") {
        world.objects.remove(visKey);
      }
      obj.debugColliderVisual = null;
    }

    // ④ obj を world から削除（キー検索）
    final key = ComponentsService.getObjectName(obj);
    if (key == "(unknown)") {
      // world.objects に入ってない（または見つからない）
      return "ok";
    }

    world.objects.remove(key);
    return "ok";
  }


  // ============================================================
  // 🧲 「相手の上に乗っかる」補正（Yだけ版）
  // ・ジャンプ系 runningTask を止める
  // ・obj を ground の上面にぴったり合わせる（Xは触らない）
  // ============================================================
  static String snapOnTopOfYOnly(
    WorldObject obj,
    (
      WorldObject ground, // 乗っかる相手
      double extraGapY,   // ちょい浮かせたい時用（例: 0〜2）
    ) params,
  ) {

    // デバッグのため名前を取得
    String name = ComponentsService.getObjectName(obj);
    debugPrint("🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌");
    debugPrint("$name");
    debugPrint("🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌🐌");
    

    final (ground, extraGapY) = params;

    if (obj.colliderRect == null || ground.colliderRect == null) {
      return "ok";
    }

    // ① ジャンプ系の runningTask を止める
    _runningTasks.removeWhere((t) =>
        identical(t.obj, obj) &&
        (identical(t.func, toJump) || identical(t.func, toJumpToObject)));

    // ② Yだけ補正：ground上面にobj下面を合わせる
    final Rect objRect = obj.colliderRect!;
    final Rect groundRect = ground.colliderRect!;

    final double correctedY =
        groundRect.top - (objRect.height / 2) - extraGapY;

    // ★Xは絶対に触らない
    obj.position = Offset(obj.position.dx, correctedY);

    // ③ ジャンプ辞書も止めたいなら（保険）
    _jumpingObjects.remove(obj);

    return "ok";
  }


  // ============================================================
  // 🧹 指定 obj の「指定 func の running タスク」を全部削除
  // ・obj と func が一致する _RunningTask を removeWhere で消す
  // ============================================================
  static String removeRunningTask(
    WorldObject obj,
    (
      Function func,
    ) params,
  ) {
    final (func,) = params;

    _runningTasks.removeWhere((t) =>
        identical(t.obj, obj) &&
        identical(t.func, func)
    );

    return "ok";
  }


  // ============================================================
  // ✅ runningTasks 内に、
  // よく使う「移動系セット」が一つも実行中でなければ、
  // trueを返す。
  // ============================================================
  static bool hasNoRunningMovementTasks() {
    return hasNoRunningTasksOfFuncs([
      toJump,
      toJumpToObject,
      toLinearMove,
      toLinearMoveBetweenObjects,
      moveToObjectToX,
      toFall,
    ]);
  }


  // ==============================
  // 🔄 ジャンプ管理を完全リセット
  // ==============================
  static void resetAllJumpData() {
    _jumpingObjects.clear();
  }


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


  // ============================================================
  // 🎲 ランダム配置（左上・右下で指定：おこちゃま版）
  // 使い方：(leftX, topY, rightX, bottomY, seed, margin)
  // ・座標が逆でもOK（自動で左右・上下を直す）
  // ・seed は null で毎回ランダム / 数字で再現
  // ・margin は省略OK：端っこから内側にする余白
  // ============================================================
  static String toRandomizePositionByCorners(
    WorldObject obj,
    (
      num leftX,     // 左上X
      num topY,      // 左上Y
      num rightX,    // 右下X
      num bottomY,   // 右下Y
      int? seed,     // nullなら毎回ランダム
      num? margin,   // 省略OK：端っこ回避
    ) params,
  ) {
    final (leftRaw, topRaw, rightRaw, bottomRaw, seed, marginRaw) = params;

    // ① num → double
    final x1 = _toDouble(leftRaw);
    final y1 = _toDouble(topRaw);
    final x2 = _toDouble(rightRaw);
    final y2 = _toDouble(bottomRaw);

    // ② 左右・上下が逆でも安全に直す
    double left   = min(x1, x2);
    double right  = max(x1, x2);
    double top    = min(y1, y2);
    double bottom = max(y1, y2);

    // ③ 余白（省略なら0）
    final m = (marginRaw == null) ? 0.0 : _toDouble(marginRaw);

    // margin で範囲が壊れない時だけ縮める
    if (right - left >= m * 2) {
      left += m;
      right -= m;
    }
    if (bottom - top >= m * 2) {
      top += m;
      bottom -= m;
    }

    // ④ 乱数
    final rng = (seed == null) ? Random() : Random(seed);

    // ⑤ 幅/高さが0でも落ちない
    final w = right - left;
    final h = bottom - top;

    final x = (w <= 0) ? left : left + w * rng.nextDouble();
    final y = (h <= 0) ? top  : top  + h * rng.nextDouble();

    obj.position = Offset(x, y);
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
  // 画像サイズ倍率変更（scale）
  // コライダーも一緒に拡大
  // ==============================
  static String toScale(
    WorldObject obj,
    (
      num scale,
    ) params,
  ) {

    final (scaleRaw,) = params;
    final scale = _toDouble(scaleRaw);

    if (obj is ImageObject) {

      // 見た目サイズ
      obj.width *= scale;
      obj.height *= scale;

      // ⭐ 当たり判定サイズも拡大
      obj.collisionSize = Size(
        obj.collisionSize.width * scale,
        obj.collisionSize.height * scale,
      );
    }
    else if (obj is GifObject) {

      obj.width *= scale;
      obj.height *= scale;
      // GifObjectは今 collisionSize 持ってないから
      // 今の設計ではこれでOK
    }

    return "ok";
  }


  // ==============================
  // 回転を加算する（度で指定）
  // ==============================
  static String toAddRotationDeg(
    WorldObject obj,
    (
      num addDegree,
    ) params,
  ) {
    final (addDegreeRaw,) = params;

    final addDegree = _toDouble(addDegreeRaw);
    final addRad = addDegree * pi / 180;

    if (obj is ImageObject) {
      obj.rotation += addRad;
    }
    else if (obj is GifObject) {
      obj.rotation += addRad;
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

    return "running"; // ずっと追従させたいので、runningを返し、
                      // runAnimationFilmに登録させる。
  }


  // ============================================================
  // 🧹 指定オブジェクトの running タスクを “関数指定” で解除
  // 例：追従だけ解除したい → toFollowWithOffset を渡す
  // ============================================================
  static String clearRunningTaskByFunc(
    WorldObject obj,
    (
      Function func,
    ) params,
  ) {

    // 🔹 レコード分解（Dartの正しい書き方）
    final (func,) = params;

    _runningTasks.removeWhere((t) =>
        identical(t.obj, obj) &&
        identical(t.func, func)
    );

    return "ok";
  }


  // ============================================================
  // 🪄 任意オブジェクトへジャンプ（着地バイアス対応版）
  // 自分自身を指定すればその場ジャンプ可能
  // ============================================================
  static String toJumpToObject(
    WorldObject obj,
    (
      WorldObject targetObj, // 着地先オブジェクト
      num offsetX,           // 着地Xバイアス
      num offsetY,           // 着地Yバイアス
      num jumpPower,
      num durationSec,
      int continuous_jump_max_num,
      bool flag_more_jump
    ) params,
  ) {

    final (
      targetObj,
      offsetXRaw,
      offsetYRaw,
      jumpPowerRaw,
      durationSecRaw,
      continuous_jump_max_num,
      flag_more_jump
    ) = params;

    final offsetX = _toDouble(offsetXRaw);
    final offsetY = _toDouble(offsetYRaw);
    final jumpPower = _toDouble(jumpPowerRaw);
    final durationSec = _toDouble(durationSecRaw);

    final now = DateTime.now().millisecondsSinceEpoch;

    // ⭐ ジャンプ開始時に着地点を固定（＋バイアス）
    final double fixedTargetX =
        targetObj.position.dx + offsetX;

    final double fixedTargetY =
        targetObj.position.dy + offsetY;

    if (!_jumpingObjects.containsKey(obj)) {

      _jumpingObjects[obj] = _JumpData(
        startX: obj.position.dx,
        startY: obj.position.dy,
        landingX: fixedTargetX,
        landingY: fixedTargetY,
        startTimeMs: now,
        jumpCount: 1,
      );

    } else {

      final data = _jumpingObjects[obj]!;

      if (flag_more_jump &&
          data.jumpCount < continuous_jump_max_num) {

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

      if (_jumpingObjects.isEmpty) {
        resetAllJumpData();
      }

      return "ok";
    }

    obj.position = Offset(newX, newY);
    return "running";
  }
  

  // ============================================================
  // ジャンプメソッド（多段ジャンプ拡張対応設計）
  // 
  // 【注意】
  //  ここではrunningリストへの追加はしていません。
  // ============================================================
  static String toJump(
    WorldObject obj,
    (
      num targetX,        // 着地予定のX座標（最終到達位置）
      num targetY,        // 着地予定のY座標（最終到達位置）
      num jumpPower,      // ジャンプの高さ（放物線の頂点の強さ）
      num durationSec,    // ジャンプにかける時間（秒）
      int continuous_jump_max_num,   // 最大連続ジャンプ回数（例：2なら二段ジャンプ）
      bool flag_more_jump // 追加ジャンプかどうか（trueで多段処理）
    ) params,
  ) {

    final (
      targetXRaw,
      targetYRaw,
      jumpPowerRaw,
      durationSecRaw,
      continuous_jump_max_num,
      flag_more_jump
    ) = params;

    final targetX = _toDouble(targetXRaw);
    final targetY = _toDouble(targetYRaw);
    final jumpPower = _toDouble(jumpPowerRaw);
    final durationSec = _toDouble(durationSecRaw);

    final now = DateTime.now().millisecondsSinceEpoch;

    if (!_jumpingObjects.containsKey(obj)) {
      // ⭐ 常に今の位置を開始地点にする
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
          data.jumpCount < continuous_jump_max_num) {

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

      // ⭐ 念のため全体クリア（安全設計）
      if (_jumpingObjects.isEmpty) {
        resetAllJumpData();
      }

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
  // 2オブジェクト間 直線移動（速度指定）
  // ============================================================
  static String toLinearMoveBetweenObjects(
    WorldObject obj,
    (
      WorldObject startObj,
      WorldObject endObj,
      num speedPerSec
    ) params,
  ) {

    final (
      startObj,
      endObj,
      speedRaw
    ) = params;

    final speed = _toDouble(speedRaw);

    final now = DateTime.now().millisecondsSinceEpoch;

    final startX = startObj.position.dx;
    final startY = startObj.position.dy;
    final targetX = endObj.position.dx;
    final targetY = endObj.position.dy;

    // ------------------------------------------
    // 距離計算
    // ------------------------------------------
    final dx = targetX - startX;
    final dy = targetY - startY;

    final distance = sqrt(dx * dx + dy * dy);

    // 速度0防止
    if (speed <= 0) {
      obj.position = Offset(targetX, targetY);
      return "ok";
    }

    final durationSec = distance / speed;

    // ------------------------------------------
    // 初回登録
    // ------------------------------------------
    if (!_movingObjects.containsKey(obj)) {
      _movingObjects[obj] = _MoveData(
        startX: startX,
        startY: startY,
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
  // 横移動専用（開始地点・到着地点をオブジェクトで指定）
  // 到着地点は、オブジェクトのx座標で停止。
  // ============================================================
  static String moveToObjectToX(
    WorldObject obj,
    (
      WorldObject startObj,
      WorldObject targetObj,
      num speedPerSec
    ) params,
  ) {

    final (
      startObj,
      targetObj,
      speedRaw
    ) = params;

    final speed = _toDouble(speedRaw);

    final now = DateTime.now().millisecondsSinceEpoch;

    final startX = startObj.position.dx;
    final startY = startObj.position.dy;
    final targetX = targetObj.position.dx;

    // ------------------------------------------
    // 初回登録
    // ------------------------------------------
    if (!_movingObjects.containsKey(obj)) {

      // 開始地点へ強制セット
      obj.position = Offset(startX, startY);

      _movingObjects[obj] = _MoveData(
        startX: startX,
        startY: startY,
        targetX: targetX,
        targetY: startY, // Y固定
        startTimeMs: now,
      );
    }

    final data = _movingObjects[obj]!;

    final distance = (data.targetX - data.startX).abs();

    if (speed <= 0) {
      obj.position = Offset(data.targetX, data.startY);
      _movingObjects.remove(obj);
      return "ok";
    }

    final durationSec = distance / speed;

    final elapsedSec =
        (now - data.startTimeMs) / 1000.0;

    final progress =
        (elapsedSec / durationSec).clamp(0.0, 1.0);

    final newX =
        data.startX +
        (data.targetX - data.startX) * progress;

    final newY = data.startY; // Y固定

    if (progress >= 1.0) {
      obj.position = Offset(data.targetX, data.startY);
      _movingObjects.remove(obj);
      return "ok";
    }

    obj.position = Offset(newX, newY);
    return "running";
  }


  // ============================================================
  // ⬇⬇⬇  落下メソッド（おこちゃま版：いっぱい床があってもOK）  ⬇⬇⬇
  // ============================================================
  // この toFall はね、
  // 「キャラをちょっとずつ下に落として、
  //  もし床にぶつかったら、床のうえに “ぴたっ” と乗せる」
  // っていう “重力係（じゅうりょくがかり）” だよ。
  //
  // ✅ 返り値（かえりち）
  // ・"running"：まだ落ちてる途中（空中）
  // ・"ok"      ：床に着地できた！（ぴたっ！）
  //
  // ✅ 引数（ひきすう）
  // ・obj        ：落としたいキャラ（アノアノなど）
  // ・fallSpeed  ：1フレームでどれだけ下に落ちるか（大きいほど速い）
  // ・goalGrounds：床になりそうなもの一覧（地面、建物、UFOなど）
  // ============================================================
  static String toFall(
    WorldObject obj,
    (
      num fallSpeed,
      List<WorldObject> goalGrounds,
    ) params,
  ) {
    // ----------------------------------------------------------
    // 🧺 0) もらった荷物をひらく（引数を展開）
    // ----------------------------------------------------------
    final (fallSpeedRaw, goalGrounds) = params;

    // ----------------------------------------------------------
    // 🧼 1) 数字を安全に “double” にする（intでもOKにするおまじない）
    // ----------------------------------------------------------
    final double fallSpeed = _toDouble(fallSpeedRaw);

    // ----------------------------------------------------------
    // ⬇ 2) 落とす。
    // ----------------------------------------------------------
    // 「ジャンプ中ではない」「着地していない」なら、落とす。
    obj.position += Offset(0, fallSpeed);
    return "ok"; // 落下中
  }


  // ============================================================
  // funkの戻り値が"running"のモノを、毎フレーム実行するためのメソッド
  // （Update()内で実行中）
  // ============================================================
  static void addRunningTask(
    WorldObject obj,
    Function func,
    dynamic value,
  ) {

    // ----------------------------------------------------
    // もし、すでにこのオブジェクトが登録されていたら、
    // 昔の方を削除。
    // （異なる関数だとしても、削除。
    // 　　→ つまり、そのオブジェクトの
    // 　　　実行中"runningタスク"の上書きに相当する。）
    // ----------------------------------------------------
    _runningTasks.removeWhere((t) =>
        identical(t.obj, obj) &&
        identical(t.func, func));

    _runningTasks.add(
      _RunningTask(obj, func, value),
    );
  }

  static void updateRunningTasks() {
    // ============================
    // runningリスト内のメソッドを
    // 実行するメソッド。なお、
    // 追従メソッドは、最後に実行する
    // ことで、追従がフレームずれ
    // 起こさないようにしている。
    // ============================

    // ---------------------------
    // ① ジャンプ系タスクを先に実行
    // ---------------------------
    for (final task in List<_RunningTask>.from(_runningTasks)) {

      if (task.func == toJump) {

        final result = task.func(task.obj, task.value);

        if (result == "ok") {
          _runningTasks.remove(task);
        }
      }
    }

    // ---------------------------
    // ② その他タスク（追従など）
    // ---------------------------
    for (final task in List<_RunningTask>.from(_runningTasks)) {

      if (task.func != toJump) {

        final result = task.func(task.obj, task.value);

        if (result == "ok") {
          _runningTasks.remove(task);
        }
      }
    }

    // ✅ 追加：デバッグコライダーの追従更新
    _updateDebugColliderVisuals();
  }

  static void _updateDebugColliderVisuals() {
    if (!DebugFlags.showColliders) return;

    for (final obj in world.objects.values) {
      final vis = obj.debugColliderVisual;
      if (vis == null) continue;

      final rect = obj.colliderRect;
      if (rect == null) continue;

      // 位置：colliderRectの中心に合わせる
      vis.position = rect.center;

      // サイズ：rectに合わせる（ImageObjectなら width/height がある）
      if (vis is ImageObject) {
        vis.width = rect.width;
        vis.height = rect.height;
      }

      // 常に最前面
      vis.layer = obj.layer + 999999;
    }
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

  // ⭐ 当たり判定設定（ImageObjectと同等）
  Offset collisionOffset;
  Size collisionSize;

  GifObject({
    required Offset position,
    required this.assetPaths,
    required this.width,
    required this.height,
    this.rotation = 0.0,
    bool enableCollision = false,

    // ✅ 追加：コライダーをオプション指定可能に
    Offset? collisionOffset,
    Size? collisionSize,

    int layer = 0,
  })  : collisionOffset = collisionOffset ?? Offset.zero,
        collisionSize = collisionSize ?? Size(width, height),
        super(position, layer: layer) {
    this.enableCollision = enableCollision;
  }

  @override
  Rect get colliderRect {
    return Rect.fromCenter(
      center: position + collisionOffset, // ✅ offset反映
      width: collisionSize.width,         // ✅ size反映
      height: collisionSize.height,
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

  // ============================================================
  // 🖼 静止画オブジェクト生成
  // ============================================================
  static void createImage({
    required String objectName,   // world.objects に登録するキー名
    required String assetPath,    // 表示する画像ファイルのパス
    required Offset position,     // 画面中心基準の座標
    required double width,        // 画像の横幅
    required double height,       // 画像の縦幅
    double rotation = 0.0,        // 回転角（ラジアン）

    bool enableCollision = false, // 当たり判定を有効にするか
    Offset? collisionOffset,      // 当たり判定の中心ズレ調整
    Size? collisionSize,          // 当たり判定のサイズ
    int layer = 0,                // 描画順（大きいほど手前）
  }) {
    final image = ImageObject(
      position: position,           // 表示位置
      assetPath: assetPath,         // 画像パス
      width: width,                 // 横幅
      height: height,               // 縦幅
      rotation: rotation,           // 回転角
      enableCollision: enableCollision, // 当たり判定ON/OFF
      collisionOffset: collisionOffset, // 判定位置補正
      collisionSize: collisionSize,     // 判定サイズ
      layer: layer,                 // 表示順
    );

    world.objects[objectName] = image;  // worldに登録

    // ✅ 追加：当たり判定ONなら、デバッグ表示を付属させる
    if (enableCollision) {
      _attachDebugColliderVisual(objectName, image);
    }
  }


  // ============================================================
  // 🎞 GIFアニメーションオブジェクト生成
  // ============================================================
  static void createGIF({
    required String objectName,
    required List<String> assetPaths,
    required Offset position,
    required double width,
    required double height,
    double rotation = 0.0,

    bool enableCollision = false,

    // ✅ 追加：コライダー調整（大きさ・高さ＝offsetY）
    Offset? collisionOffset,
    Size? collisionSize,

    int layer = 0,
  }) {
    final gif = GifObject(
      position: position,
      assetPaths: assetPaths,
      width: width,
      height: height,
      rotation: rotation,
      enableCollision: enableCollision,

      // ✅ 追加
      collisionOffset: collisionOffset,
      collisionSize: collisionSize,

      layer: layer,
    );

    world.objects[objectName] = gif;

    if (enableCollision) {
      _attachDebugColliderVisual(objectName, gif);
    }
  }


  // ✅ 追加：当たり判定の可視化オブジェクトを付属させる
  static void _attachDebugColliderVisual(String ownerName, WorldObject owner) {
    // 表示ONでないなら作る必要すらない（必要ならここを外してもOK）
    if (!DebugFlags.showColliders) return;

    final rect = owner.colliderRect;
    if (rect == null) return;

    final debugName = "__debug_collider__$ownerName";

    final debugObj = DebugColliderImageObject(
      position: owner.position, // とりあえず同位置。後で毎フレームで補正する
      assetPath: "assets/images/debug_red_square.png", // ★用意してね
      width: rect.width,
      height: rect.height,
      layer: owner.layer + 999999, // 常に最前面
    );

    world.objects[debugName] = debugObj;
    owner.debugColliderVisual = debugObj;
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
  double hidden_xy = -10000;

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
    double bias_x = 130;
    double bias_y = 300;
    ObjectCreator.createImage(
      objectName: "アノアノ右目",
      assetPath: "assets/images/nikkori.png",
      position: Offset(bias_x + 200, bias_y + 200),
      width: 30,
      height: 30,
      layer: 100, // 表示順番
    );
    ObjectCreator.createImage(
      objectName: "アノアノ左目",
      assetPath: "assets/images/nikkori.png",
      position: Offset(bias_x, bias_y), 
      width: 30,
      height: 30,
      layer: 101, // 表示順番
    );
    ObjectCreator.createImage(
      objectName: "アノアノ口",
      assetPath: "assets/images/nikkori.png",
      position: Offset(bias_x, bias_y), 
      width: 25,
      height: 25,
      rotation: pi, // pi → 180。0,
      layer: 102, // 表示順番
    );
    ObjectCreator.createImage(
      objectName: "アノアノ輪郭",
      assetPath: "assets/images/kao_rinnkaku_1.png",
      position: Offset(bias_x, bias_y + 5), 
      width: 60,
      height: 60,
      enableCollision: true,
      layer: 103, // 表示順番
      // 見た目より小さいコライダー
      collisionSize: const Size(40, 40),
      // 少し→に寄せる
      collisionOffset: const Offset(4, 6), // 地面と重なると、ジャンプできなくなるので注意
    );

    // 下中央に「スタートボタン」
    ObjectCreator.createImage(
      objectName: "スタートボタン",
      assetPath: "assets/images/start.png",
      position: Offset(hidden_xy, hidden_xy,),
      width: 200,
      height: 200,
      enableCollision: true,
      layer: 200, // 表示順番
    );

  }
}


// ホーム画面プレイヤー
class HomePlayer extends SuperPlayer {
  // =============================================
  // スタートボタンが押されるまで待機する場所
  // =============================================

  // ---------------------------------------- 
  // class変数
  // ---------------------------------------- 
  // スタートボタンflag
  bool flag_start_button = false;
  final screenSize = SystemEnvService.screenSize;

  // アノアノの位置（ホーム画面に置ける位置。）
  double bias_x = 0;
  double bias_y = 120;

  // アニメーションフィルム用キャッシュ
  String frame_result = "ok";
  List<dynamic> list_2d = [];
  int wait_time = 1;
  int? end_time = null;
  int currentIndex = 0;   // ★追加
  late List<List<List<dynamic>>> animation_film_3dlist;
  bool film_end = false;


  // __init__(self)に同じ
  @override
  void init() {

    // ============================================
    // アニメーションフィルムの作成
    // ============================================
    // 初期位置に移動
    // →　[オブジェクト名、代入値(座標等)、待機時間、実行関数]
    this.animation_film_3dlist = [
        // アノアノをにっこり顔で設置
        [[world.objects["アノアノ輪郭"], (this.bias_x, this.bias_y), 0, ObjectManager.toSetPosition],
         [world.objects["アノアノ右目"], (world.objects["アノアノ輪郭"]!, 9, 0), 0, ObjectManager.toFollowWithOffset], // OK
         [world.objects["アノアノ左目"], (world.objects["アノアノ輪郭"]!, -7, 0), 0, ObjectManager.toFollowWithOffset], // OK
         [world.objects["アノアノ口"], (world.objects["アノアノ輪郭"]!, 19, 27), 0, ObjectManager.toFollowWithOffset]], // OK

        // スタートボタンを設置
        [[world.objects["スタートボタン"], (0, 180), 0, ObjectManager.toSetPosition]],
      ];
  }
  
  @override
  void mainScript() 
  {

    // ============================================
    // もしオブジェクト配置がまだならば、配置させる。
    // アノアノを定位置に移動させ、
    // スタートボタンを配置する。
    // ============================================
    if (!this.film_end){
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
      this.film_end = result.$7;    // ★終了フラグは$7
    }

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

  // ボタン管理
  bool flag_skip_button = false;

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
      objectName: "スキップボタン",
      assetPath: "assets/images/skip.png",
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: 70,
      height: 70,
      layer: 201, // 表示順番
      enableCollision: true, // ★これ
    );
    ObjectCreator.createImage(
      objectName: "地面",
      assetPath: "assets/images/jimenn.png",
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: 1000,
      height: 510,
      // width: 1100,
      // height: 1100,
      layer: 301, // 表示順番
      enableCollision: true, // ★これ
      // 見た目より大きいコライダー
      collisionSize: const Size(710, 270),
      // 少し上に寄せる
      collisionOffset: const Offset(0, -30),
    );
    ObjectCreator.createImage(
      objectName: "ちいさいまる",
      assetPath: "assets/images/maru_tiisai.png",
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: 50,
      height: 50,
      layer: 301, // 表示順番
    );
    ObjectCreator.createImage(
      objectName: "ちいさいもこもこ",
      assetPath: "assets/images/mokomoko_syou.png",
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: 50,
      height: 50,
      layer: 302, // 表示順番
    );
    ObjectCreator.createImage(
      objectName: "おおきいもこもこ",
      assetPath: "assets/images/mokomoko_dai.png",
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: 300,
      height: 300,
      layer: 303, // 表示順番
    );
    ObjectCreator.createImage(
      objectName: "空想アノアノ右目",
      assetPath: "assets/images/nikkori.png",
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: 40,
      height: 40,
    );
    ObjectCreator.createImage(
      objectName: "空想アノアノ左目",
      assetPath: "assets/images/nikkori.png",
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: 40,
      height: 40,
      layer: 304, // 表示順番
    );
    ObjectCreator.createImage(
      objectName: "空想アノアノ口",
      assetPath: "assets/images/nikkori.png",
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: 25,
      height: 25,
      rotation: pi, // pi → 180。
      layer: 305, // 表示順番
    );
    ObjectCreator.createImage(
      objectName: "空想アノアノ輪郭",
      assetPath: "assets/images/kao_rinnkaku_2.png",
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: 80,
      height: 80,
      layer: 306, // 表示順番
    );
    ObjectCreator.createGIF(
      objectName: "空想アノアノ羽",
      assetPaths: ["assets/images/hane_1.png","assets/images/hane_2.png"],
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: 60,
      height: 60,
      rotation: 0.5, // pi → 180。
      layer: 307, // 表示順番
    );
    ObjectCreator.createImage(
      objectName: "アノアノ両目_怒",
      assetPath: "assets/images/me_sikame.png",
      position: Offset(this.hidden_xy, this.hidden_xy),
      width: 30,
      height: 30,
      layer: 307, // 表示順番
    );
    ObjectCreator.createImage(
      objectName: "着地地点",
      assetPath: "assets/images/tomoyo.png",
      position: Offset(-150, 100),
      width: 30,
      height: 30,
      layer: 101, // 表示順番
    );


    // アニメーションフィルムの作成
    double jump_height = 50.0;
    double jump_time = 0.5;

    // →　[オブジェクト名、代入値(座標等)、待機時間、実行関数]
    this.animation_film_3dlist = [
        // スタートボタンの退避
        [[world.objects["スタートボタン"], (hidden_xy, hidden_xy), 0, ObjectManager.toSetPosition]],

        // スキップボタンの配置
        [[world.objects["スキップボタン"], (0, 180), 0, ObjectManager.toSetPosition]],

        // 地面を配置
        [[world.objects["地面"], (0, 310), 0, ObjectManager.toSetPosition]],

        // アノアノを左側にジャンプさせる。
        [[world.objects["アノアノ輪郭"], (-150, 100, 300, 0.5, 1, false), 0, ObjectManager.toJump]],
        
        // 空想もこもこ表示
        [[world.objects["ちいさいまる"], (world.objects["アノアノ輪郭"]!, this.hidden_xy, this.hidden_xy), 1, ObjectManager.toFollowWithOffset]], // １秒待機用
        [[world.objects["ちいさいまる"], (world.objects["アノアノ輪郭"]!, 50, -50), 1, ObjectManager.toFollowWithOffset]],
        [[world.objects["ちいさいもこもこ"], (world.objects["アノアノ輪郭"]!, 100, -100), 1, ObjectManager.toFollowWithOffset]],
        [[world.objects["おおきいもこもこ"], (world.objects["アノアノ輪郭"]!, 150, -300), 1, ObjectManager.toFollowWithOffset]],
        
        // 空想アノアノの出現
        [[world.objects["空想アノアノ輪郭"], (world.objects["おおきいもこもこ"]!, 0, 0), 0, ObjectManager.toFollowWithOffset]],
        AnimationDict.get("羽アノアノ"),

        // 空想全部退避。
        AnimationDict.match2d([ // この中に入れた二次元リストはすべてまとめられ、一つの二次元リストになる。
            AnimationDict.get("もこもこ全解除"),
            AnimationDict.get("表情追従全解除"),
            AnimationDict.get("もこもこ全隠し"),
            AnimationDict.get("表情全隠し"),
            AnimationDict.get("ニコニコ笑顔") // 表情も変える。現実アノアノが目をつむってちょっと考える。
        ]),
        
        // 四秒待機用。
        [[world.objects["アノアノ口"], (world.objects["アノアノ輪郭"]!, 19, 27), 4, ObjectManager.toFollowWithOffset]],
        
        // 現実アノアノが高ぶるいする（ちょっと2回ジャンプする。）
        [[world.objects["アノアノ輪郭"], (world.objects["着地地点"]!.position.dx,
                                        world.objects["着地地点"]!.position.dy,
                                        80.0,
                                        jump_time, 
                                        1, 
                                        false),0,ObjectManager.toJump]],
        [[world.objects["アノアノ輪郭"], (-150, 100, 300, 0.5, 1, false), 1, ObjectManager.toJump]],
        [[world.objects["アノアノ輪郭"], (world.objects["着地地点"]!.position.dx,
                                        world.objects["着地地点"]!.position.dy,
                                        80.0,
                                        jump_time, 
                                        1, 
                                        false),0,ObjectManager.toJump]],

        // 現実アノアノが本気の顔になる
        AnimationDict.get("表情追従全解除"),
        AnimationDict.get("表情全隠し"),
        AnimationDict.get("真剣顔")
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


    // ============================================
    // スキップボタンが押されたか判定
    // ============================================
    final button = world.objects["スキップボタン"];
    if (button != null &&
        ComponentsService.isClicked(button)) {
      debugPrint("🐇 スキップボタンが押されました");
      this.flag_skip_button = true;

      // スキップの代わりに、高速でアニメを終わらせる。
      final result = AnimationFilmService.runAnimationFilmSkipTime(
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

      // かつ、移動系メソッドがすべて完了していれば
      if (ObjectManager.hasNoRunningMovementTasks()){
        // ストーリーは終了したことにする。
        this.flag_story_end = true;
      }
    }
  }
}


// ゲームオブジェクトをリセット地点に置くプレイヤー。 
// ゲームオブジェクトをリセット地点に置くプレイヤー。 
class GameInitPlayer extends SuperPlayer {
  // クラス変数
  final Offset hiddenOffset = const Offset(-10000, -10000);
  final Offset anoanoBiasOffset = const Offset(200, 500);
  bool flag_object_created = false;

  // 障害物サイズ
  // ----------------------------
  // ✅ ここを調整するだけで、個別にサイズをいじれる！
  // ※いまの設計だと「見た目サイズ＝コライダーサイズ」になる（GifObjectのcolliderRectがwidth/height参照）
  // ----------------------------

  // 建物サイズ（個別）
  double tatemono_1_size = 130;
  double tatemono_2_size = 100;
  double tatemono_3_size = 80;

  // UFOサイズ（個別）
  double ufo_1_size = 60;
  double ufo_2_size = 30;
  double ufo_3_size = 40;

  // アイテムサイズ（個別）
  double item_hane_1_width = 500;
  double item_hane_1_height = 1000;

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
    this.animation_film_3dlist = [ // 🌙これ自体実行されていないことが判明しました。

        AnimationDict.match2d([ // この中に入れた二次元リストは、一つの二次元リストに変換されます。
          // 空想隠す。
          [
           [world.objects["ちいさいまる"], (this.hiddenOffset.dx, this.hiddenOffset.dy), 0, ObjectManager.toSetPosition],
           [world.objects["ちいさいもこもこ"], (this.hiddenOffset.dx, this.hiddenOffset.dy), 0, ObjectManager.toSetPosition],
           [world.objects["おおきいもこもこ"], (this.hiddenOffset.dx, this.hiddenOffset.dy), 0, ObjectManager.toSetPosition]
          ],

          // Skipボタン隠す。
          [
           [world.objects["スキップボタン"], (this.hiddenOffset.dx, this.hiddenOffset.dy), 0, ObjectManager.toSetPosition],
          ],

          // 真剣顔に変更
          AnimationDict.get("表情追従全解除"), 
          AnimationDict.get("表情全隠し"), 
          AnimationDict.get("真剣顔")
        ])
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
        width: tatemono_1_size,
        height: tatemono_1_size,
        enableCollision: true,
        layer: 401, // 表示順番
        // 見た目より大きいコライダー
        collisionSize: const Size(100, 100),
        // 少し上に寄せる
        collisionOffset: const Offset(0, 0),
      );
      // UFO
      ObjectCreator.createGIF(
        objectName: "UFO_1",
        assetPaths: [
            "assets/images/ufo_1.png",
            "assets/images/ufo_2.png",
          ],
        position: Offset(this.hiddenOffset.dx, this.hiddenOffset.dy),
        width: this.ufo_1_size,
        height: this.ufo_1_size,
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
        width: this.tatemono_2_size,
        height: this.tatemono_2_size,
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
        width: this.ufo_2_size,
        height: this.ufo_2_size,
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
        width: this.tatemono_3_size,
        height: this.tatemono_3_size,
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
        width: this.ufo_3_size,
        height: this.ufo_3_size,
        enableCollision: true,
        layer: 406, // 表示順番
      );

      // ============================================
      // アイテムオブジェクトの生成（見えないところに。）
      // ============================================
      // 羽。
      ObjectCreator.createGIF(
        objectName: "アイテム_羽_1",
        assetPaths: [
            "assets/images/hane_1.png",
            "assets/images/hane_2.png",
          ],
        position: Offset(this.hiddenOffset.dx, this.hiddenOffset.dy),
        width: this.item_hane_1_width,
        height: this.item_hane_1_height,
        enableCollision: true,
        layer: 500, // 表示順番
      );

      // アイテム作成できたので、フラグをオンにする。
      this.flag_object_created = true;
    }

    // ============================================
    // ゲームの初期化
    // (これが実行されなかった
    // →モード遷移で、flag_all_film_finishedが
    // trueでモード遷移するようにコーディングした。)
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
class GameFlagPlayer extends SuperPlayer {

  // ✅ 着地フラグ
  bool now_no_fly = false;

  // ✅ 共有：このフレームで「south＝着地」した床の相手
  final List<WorldObject> groundList = [];

  @override
  void init() {
    now_no_fly = false;
    groundList.clear();
  }

  @override
  void mainScript() {
    // ここでは何もしない（groundListのclearは CollisionGimmickPlayer 側でやる）
  }
}


// ユーザの入力を受け取るプレイヤー 
class ReceiveInputPlayer extends SuperPlayer {

  // ==============================
  // 🔵 クラス変数（入力保持用）
  // ==============================
  bool isTouching = false;
  Offset? tapPosition;
  int game_frame_count = 1;

  @override
  void init() {
    // =============================================
    // オブジェクトの用意
    // =============================================
    // 障害物出発地点
    ObjectCreator.createImage(
      objectName: "障害物出発地点",
      assetPath: "assets/images/tomoyo.png",
      position: Offset(50, 100),
      width: 10,
      height: 10,
      layer: 600000, // 表示順番
    );
    // 障害物出発地点
    ObjectCreator.createImage(
      objectName: "障害物出発地点_ランダム",
      assetPath: "assets/images/tomoyo.png",
      position: Offset(50, 100),
      width: 10,
      height: 10,
      layer: 600000, // 表示順番
    );
    // 障害物終点
    ObjectCreator.createImage(
      objectName: "障害物終点",
      assetPath: "assets/images/tomoyo.png",
      position: Offset(-400, 100),
      width: 10,
      height: 10,
      layer: 600000, // 表示順番
    );
  }

  @override
  void mainScript() 
  {
    // ------------------------------
    // 🟢 現在の入力状態を取得して保持
    // ------------------------------
    isTouching = SystemEnvService.isTouching;
    tapPosition = SystemEnvService.tapPosition;
  }
}


// 邪魔者の座標を更新
// ---------------------------------------------
// 🏃‍♂️ MovingDisturverPlayer（じゃまものを動かす係）
// ・建物やUFOみたいな「ぶつかるやつ」を動かすよ
// ・一定時間ごとに「動かし方のパターン」を切り替えるよ
// ---------------------------------------------
class MovingDisturverPlayer extends SuperPlayer {
  // ==============================
  // 🔵 クラス変数
  // ==============================
  // クラス変数
  // 🏁 disturver_reset_position：じゃまものを「出発させる場所（予備）」だよ
  // ※今のコードでは作ってるけど、まだ直接は使ってない（未来用）
  late Offset disturver_reset_position;
  // 💨 disturver_speed：じゃまものが動く速さ（1秒あたり）
  double disturver_speed = 200; // 邪魔者オブジェクトのスピード

  // 障害物マップを切り替えるの、秒数処理
  // ⏰ lastSwitchTimeSec：最後にパターンを変えた「秒」
  int lastSwitchTimeSec = 0;
  // ⏲ switchIntervalSec：何秒ごとに切り替えるか（今は3秒）
  int switchIntervalSec = 3; // 3秒ごとに切り替える
  // 🧩 currentPattern：いま使ってるパターン番号（1〜3）
  int currentPattern = 1;


  // ==============================
  // フィルム再生用キャッシュ
  // ==============================
  String frame_result = "ok"; // 🎞 frame_result：フィルムの1コマが終わったかの状態（"ok" or "running"）
  late List<dynamic> list_2d; // 📦 list_2d：いま実行中の「2次元リスト（1コマぶん）」の箱
  int wait_time = 1; // ⌛ wait_time：次のコマに進むまで待つ秒数（フィルム用）
  int? end_time = null; // 🕰 end_time：待機が終わる予定の時刻（秒）
  int currentIndex = 0; // 🔢 currentIndex：3Dリストの「いま何コマ目？」（これ超大事） // ★追加
  late List<List<List<dynamic>>> item_and_disturver_animation_film_3dlist_1; // 🧱 patternごとのフィルム（3Dリスト）
  late List<List<List<dynamic>>> item_and_disturver_animation_film_3dlist_2; // 🧱 patternごとのフィルム（3Dリスト）
  late List<List<List<dynamic>>> item_and_disturver_animation_film_3dlist_3; // 🧱 patternごとのフィルム（3Dリスト）
  late List<List<List<dynamic>>> ufo_start_ramdom_put; // 🧱 patternごとのフィルム（3Dリスト）
  bool item_and_disturver_animation_film_3dlist_1_end = false; // ✅ それぞれのフィルムが終わったか（今は未使用のフラグ）
  bool item_and_disturver_animation_film_3dlist_2_end = false; // ✅ それぞれのフィルムが終わったか（今は未使用のフラグ）
  bool item_and_disturver_animation_film_3dlist_3_end = false; // ✅ それぞれのフィルムが終わったか（今は未使用のフラグ）
  bool flag_all_film_finished = false; // ✅ 全部終わったか（今は使ってないけど、将来の拡張用）

  @override
  void init() {
    // 🧺 list_2d を空っぽで用意しておく（null事故防止）
    list_2d = [];          // ★これを追加
    // 📱 画面サイズを取る（出発位置の計算に使う）
    final screenSize = SystemEnvService.screenSize;

    // 🏁 じゃまものの「初期の出発っぽい位置」を作る
    // ・画面の左端のさらに左（ -width/2 ）
    // ・画面の下側（ height/2 ）
    disturver_reset_position = Offset(
      -screenSize.width / 2,
      screenSize.height / 2,
    );


    // ufo出発地点
    // ---------------------------------------------
    // 出発地点を決定させる。🌙
    // ---------------------------------------------
    this.ufo_start_ramdom_put = [
      [[world.objects["障害物出発地点_ランダム"], (200, 0, 400, 50, null, 0), 0, ObjectManager.toRandomizePositionByCorners]],
    ];


    // マップPattern１
    // ---------------------------------------------
    // 🧩 パターン1の「動かし方」
    // ・建物_1 と UFO_1 を動かす
    // ・moveToObjectToX：スタート地点に置いて、ターゲットのXまでスライドする
    // ・待ち時間(ここでは 1 )が入ってるので、フィルム的には「1秒ごとに更新」寄りになる
    // ---------------------------------------------
    this.item_and_disturver_animation_film_3dlist_1 = [
        // 邪魔者の座標を動かす。
        [[world.objects["建物_1"], (world.objects["障害物出発地点"], world.objects["障害物終点"], this.disturver_speed), 0, ObjectManager.moveToObjectToX], // オブジェクトから、オブジェクトのXまで移動。
         [world.objects["UFO_1"], (world.objects["障害物出発地点_ランダム"], world.objects["障害物終点"], this.disturver_speed), 0, ObjectManager.moveToObjectToX]],
      ];  

    // マップPattern２
    // ---------------------------------------------
    // 🧩 パターン2の「動かし方」
    // ※いまは中身がパターン1と同じ（つまり見た目は変わらない）
    // 今後「建物_2」「UFO_2」を動かす等に増やすと、切替の意味が出るよ
    // ---------------------------------------------
    this.item_and_disturver_animation_film_3dlist_2 = [
        // 邪魔者の座標を動かす。
        [[world.objects["建物_1"], (world.objects["障害物出発地点"], world.objects["障害物終点"], this.disturver_speed), 0, ObjectManager.moveToObjectToX], // オブジェクトから、オブジェクトのXまで移動。
         [world.objects["UFO_1"], (world.objects["障害物出発地点_ランダム"], world.objects["障害物終点"], this.disturver_speed), 0, ObjectManager.moveToObjectToX]],
      ];  

    // マップPattern３
    // ---------------------------------------------
    // 🧩 パターン3の「動かし方」
    // ※これも今はパターン1と同じ
    // だから「currentPatternが変わっても挙動が同じ」に見える可能性がある
    // ---------------------------------------------
    this.item_and_disturver_animation_film_3dlist_3 = [
        // 邪魔者の座標を動かす。
        [[world.objects["建物_1"], (world.objects["障害物出発地点"], world.objects["障害物終点"], this.disturver_speed), 0, ObjectManager.moveToObjectToX], // オブジェクトから、オブジェクトのXまで移動。
         [world.objects["UFO_1"], (world.objects["障害物出発地点_ランダム"], world.objects["障害物終点"], this.disturver_speed), 0, ObjectManager.moveToObjectToX]],
      ];  
  }

  @override
  void mainScript() 
  {
    // 🐾 デバッグ用ログ：このPlayerが毎フレーム呼ばれてるか確認できる
    debugPrint("▶ ${runtimeType} mainScript スタート");

    // ⏱ 今の時刻（ミリ秒→秒にしてる）
    final nowSec =
        DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // ==========================================
    // 🔄 一定秒数ごとにパターン切替
    // ==========================================
    // 「いまの秒 - 前に切り替えた秒」が3秒以上なら、パターンを進める
    if (nowSec - lastSwitchTimeSec >= switchIntervalSec) {

      // 📝 最後に切り替えた時間を更新
      lastSwitchTimeSec = nowSec;

      // ➕ パターン番号を1つ進める
      currentPattern++;

      // 🔁 3を超えたら1に戻す（1→2→3→1→...）
      if (currentPattern > 3) {
        currentPattern = 1;
      }

      // フィルム状態リセット
      // 🧼 これをしないと「前のフィルムの続き」になって変な動きになる
      frame_result = "ok";
      // 🧼 待機終了予定もリセット（次のコマの待ちをやり直す）
      end_time = null;

      // 🧼 これ超重要：コマ番号を0に戻す（じゃないと途中から再生する）
      currentIndex = 0;   // ★これがないと前のindexのまま進みます
    }

    // ==========================================
    // 🎬 現在のパターンを実行
    // ==========================================
    // 🧺 いま使うフィルムを入れる箱（あとでrunAnimationFilmに渡す）
    List<List<List<dynamic>>> targetFilm;

    // 🧩 どのパターンのフィルムを使うか選ぶ
    if (currentPattern == 1) {
      targetFilm = item_and_disturver_animation_film_3dlist_1;
    } else if (currentPattern == 2) {
      targetFilm = item_and_disturver_animation_film_3dlist_2;
    } else {
      targetFilm = item_and_disturver_animation_film_3dlist_3;
    }

    // 障害物出発地点処理を含有させる。
    targetFilm = AnimationDict.match3d([
      this.ufo_start_ramdom_put,
      targetFilm
    ]);

    // 🎞 フィルムを1回ぶん進める
    // ・待機が終わったら次のコマを取り出して実行
    // ・"running" が返った動きは ObjectManager の runningTasks に登録される
    final result = AnimationFilmService.runAnimationFilm(
      frame_result,
      targetFilm,
      list_2d,
      wait_time,
      end_time,
      currentIndex,
    );

    // 🧾 返ってきた「更新後の状態」をちゃんと保存する（これを忘れると進まない）
    frame_result = result.$1;
    // 🧺 targetFilm はローカル変数だけど、一応返り値を受け取ってる（仕様上）
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
  bool flag_jumping_now = false; // ジャンプ中ならばtrueにする。
  final Offset hiddenOffset = const Offset(-10000, -10000); // 隠す場所
  final Offset anoanoBiasOffset = const Offset(200, 500); // アノアノのバイアス座標

  // adjustFlagPlayer用。
  int continuous_jump_count = 0;   // 現在のジャンプ回数
  int continuous_jump_max_num = 1;       // 最大ジャンプ回数 ← 何これ謎🌙（2026年2月25日）

  // ==============================
  // フィルム再生用キャッシュ
  // ==============================
  String frame_result = "ok";
  late List<dynamic> list_2d;
  int wait_time = 1;
  int? end_time = null;
  int currentIndex = 0; 
  late List<List<List<dynamic>>> jump_animation_film_3dlist;
  late List<List<List<dynamic>>> more_jump_animation_film_3dlist;
  bool flag_all_film_finished = false;

  @override
  void init() {
    // 初期化（必要なら後で）
    list_2d = [];          

    // →　[オブジェクト名、代入値(座標等)、待機時間、実行関数]
    // アノアノジャンプ
    this.jump_animation_film_3dlist = [
        [[world.objects["アノアノ輪郭"], (-150, 100, 50, 0.5, 1, false), 0, ObjectManager.toJump]],
      ];

    // アノアノジャンプ(重複ジャンプ用)
    this.more_jump_animation_film_3dlist = [
        [[world.objects["アノアノ輪郭"], (-150, 100, 300, 0.5, 1, true), 0, ObjectManager.toJump]],
      ];

    debugPrint("GameJumpAnimationPlayerの初期化が完了しました。");
  }


  @override
  void mainScript() {

    // ======================================================
    // 画面がタッチされたとき
    // ======================================================
    if (world.receiveInputPlayer.isTouching) {

      // -------------------------------------------------
      // 画面がタッチされてかつ、
      // 現在ジャンプしていない時の処理
      // -------------------------------------------------
      if (!this.flag_jumping_now) {

        // 現在ジャンプ中フラグをON
        this.flag_jumping_now = true;  
        
        // 連続ジャンプカウントをインクリメント
        this.continuous_jump_count = 1;

        // フラグ「現在ジャンプしてません」をfalse
        world.gameFlagPlayer.now_no_fly = false;

        // ジャンプをする（または、二回目以降ならばジャンプ放物線を遷移することになる。）
        final result = ObjectManager.toJump(
          world.objects["アノアノ輪郭"]!,
          (-150, 100, 300, 0.5, this.continuous_jump_max_num, false),
        );

        // ジャンプの結果が「running」ならば、running登録。
        // （登録は上書きなので、毎回実行しても問題ないはず。）
        if (result == "running") {
          ObjectManager.addRunningTask(
            world.objects["アノアノ輪郭"]!, ObjectManager.toJump,
            (-150, 100, 300, 0.5, this.continuous_jump_max_num, false),
          );
        }


      // -------------------------------------------------
      // 画面がタッチされてかつ、
      // （連続ジャンプ数 < 最大連続ジャンプ数）の時
      // -------------------------------------------------
      } else if (this.continuous_jump_count < this.continuous_jump_max_num) {

        // -------------------------------------------------
        // まだジャンプできるので、ジャンプする。
        // -------------------------------------------------
        // 連続ジャンプ数をインクリメント
        this.continuous_jump_count += 1;
        
        // フラグ「現在ジャンプしてません」をfalse
        world.gameFlagPlayer.now_no_fly = false;

        // ジャンプをする（引数に true を取らせているので、空中ジャンプするはず。）
        ObjectManager.toJump(
          world.objects["アノアノ輪郭"]!,
          (-150, 100, 300, 0.5, this.continuous_jump_max_num, true),
        );

        // runningリストに登録（上書きなので、ひとつ前のジャンプは抹消される。）
        ObjectManager.addRunningTask(
          world.objects["アノアノ輪郭"]!, ObjectManager.toJump,
          (-150, 100, 300, 0.5, this.continuous_jump_max_num, true),
        );
      }
    }

    // 🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙
    // アノアノ輪郭のジャンプタスクが一つでも存在したら、falseが返ってくる。
    bool isJumpRunning = !ObjectManager.hasNoRunningTasksOfObjAndFuncs(
              world.objects["アノアノ輪郭"]!,
        [ObjectManager.toJump],
      );

    if (
        this.flag_jumping_now && // 現在ジャンプ中 
        !isJumpRunning // しかし、アノアノ輪郭のジャンプ中タスクがrunningリストに存在しない
      ) {
      // 👉 ジャンプが完了した：now_no_fly もここでリセット（着地前提）
      this.flag_jumping_now = false;
      this.continuous_jump_count = 0;
      // adjustFlagPlayer が着地を確認するまで now_no_fly=false のまま落下させる
      // → GameFallAnimationPlayer に引き渡す
    }
    // 🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙🌙

  }
}



// ========================================================
// 本当に落下させるだけ。（ジャンプ中、着地中を除く。）
// ========================================================
class GameFallAnimationPlayer extends SuperPlayer {

  // 落下速度
  double fallSpeed = 40;

  @override
  void init() {}

  @override
  void mainScript() {

    // 床になりうるオブジェクトをリスト化
    final groundList = [
      world.objects["地面"],
      world.objects["建物_1"],
      world.objects["建物_2"],
      world.objects["建物_3"],
      world.objects["UFO_1"],
      world.objects["UFO_2"],
      world.objects["UFO_3"],
    ].whereType<WorldObject>()
    .where((o) => o.enableCollision)
    .toList();

    // ・ジャンプ中ではない
    // ・着地中ではない
    // なら落下
    if (
        !world.gameJumpAnimationPlayer.flag_jumping_now && // ジャンプ中ではない
        !world.gameFlagPlayer.now_no_fly) { // 

      // toFallメソッドで落下させる。
      // ✅ runningTasksに登録せず、直接呼び出すだけ
      ObjectManager.toFall(world.objects["アノアノ輪郭"]!, (fallSpeed, []));
      // ↑ groundListはadjustFlagPlayerに任せるのでここでは不要
    }
  }
}


// ===============================================
// 💥 CollisionGimmickPlayer（ぶつかったか調べる係）
// -----------------------------------------------
// ここは「当たった？」を調べるだけのクラスだよ。
// ぶつかったら「だれに」「どっちから」ぶつかったかをメモする。
// ===============================================
class CollisionGimmickPlayer extends SuperPlayer {

  // -----------------------------------------------
  // 📝 hitList（ぶつかったメモ帳）
  // -----------------------------------------------
  // ここに「ぶつかった相手」と「ぶつかった向き」を入れるよ。
  // 例）(UFO_1, north) みたいな感じ。
  late List<(WorldObject, HitSide)> hitList;

  // -----------------------------------------------
  // 🌱 init（さいしょに1回だけやる準備）
  // -----------------------------------------------
  @override
  void init() {
    // まずは空っぽのメモ帳をつくるよ
    hitList = [];
  }

  // -----------------------------------------------
  // 🔁 mainScript（毎フレームずーっとやる仕事）
  // -----------------------------------------------
  @override
  void mainScript() {

    // ① メモ帳をクリア
    hitList.clear();

    // ② ぶつかるかもしれない相手
    final objects = [
      world.objects["地面"],
      world.objects["建物_1"],
      world.objects["建物_2"],
      world.objects["建物_3"],
      world.objects["UFO_1"],
      world.objects["UFO_2"],
      world.objects["UFO_3"],
    ];

    // ③ 主役
    final player = world.objects["アノアノ輪郭"];
    if (player == null) return;

    // ④ 当たり判定を集める
    for (final obj in objects) {
      if (obj == null) continue;

      final side = ComponentsService.hitSide(player, obj);
      if (side != HitSide.none) {
        hitList.add((obj, side));
      }
    }

    // ⑤ ✅ このフレームの「着地（south）」候補を作る
    world.gameFlagPlayer.groundList.clear();

    for (final hit in hitList) {
      final obj = hit.$1;
      final side = hit.$2;

      if (side == HitSide.south) {
        // ✅ south = 乗っかった（着地）
        world.gameFlagPlayer.groundList.add(obj);
      }
      // west はセーフで無視
      // north/east はゲームオーバー判定は Resolve に任せてもいいし、
      // ここで立ててもいい。今回は Resolve に一本化するので何もしない。
    }
  }
}


// ==============================================================
// 💥 adjustFlagPlayer（ぶつかった後の「状態決め係」）
// --------------------------------------------------------------
class AdjustFlagPlayer extends SuperPlayer {

  // ==========================================================
  // アニメーションフィルム群
  // ==========================================================
  late List<List<List<dynamic>>> animation_film_3dlist_for_stop_jump;
  late List<List<List<dynamic>>> animation_film_3dlist_for_ride_object;
  

  // ==========================================================
  // フィルム再生用キャッシュ
  // ==========================================================
  String frame_result = "ok";
  late List<dynamic> list_2d = [];
  int wait_time = 1;
  int? end_time = null;
  int currentIndex = 0;   // ★追加
  late List<List<List<dynamic>>> animation_film_3dlist;
  bool flag_story_end = false;
  WorldObject? ride_object;

  @override
  void init() {
    // ============================================
    // アニメーションフィルムの作成
    // ============================================
    // アノアノジャンプをストップするフィルム
    this.animation_film_3dlist_for_stop_jump = [
        // アノアノジャンプをストップ
        [[world.objects["アノアノ輪郭"]!, (ObjectManager.toJump,), 0, ObjectManager.removeRunningTask]],
      ];
  }

  @override
  void mainScript() {

    // ① 主役
    final player = world.objects["アノアノ輪郭"];
    if (player == null) return;

    // ② ぶつかったメモ帳
    final hitList = world.collisionGimmickPlayer.hitList;

    // デバッグ表示
    final s = hitList.map((h) {
      final obj = h.$1;
      final side = h.$2;
      final name = ComponentsService.getObjectName(obj);
      return '$name side=${side.name} pos=(${obj.position.dx.toStringAsFixed(1)}, ${obj.position.dy.toStringAsFixed(1)})';
    }).join(' | ');
    debugPrint('HIT = $s');

    // ③ ✅ ゲームオーバー判定：north / east だけ危険
    for (final hit in hitList) {
      final side = hit.$2;

      final bool isDangerHit =
          (side == HitSide.north) ||
          (side == HitSide.east);

      if (isDangerHit) {
        world.gameoverJudgmentPlayer.flag_gameover = true;
        // 1個でも危険なら確定でOKなら break して軽量化してもよい
        // break;
      }
    }

    // ④ ✅ 着地判定：south = 乗っかった
    final landedTargets = world.gameFlagPlayer.groundList;

    if (landedTargets.isNotEmpty) {
      // 一番近い床を選ぶ
      ride_object = ComponentsService.nearestObject(player, landedTargets);

      if (ride_object != null) {
        // ジャンプを止める
        ObjectManager.removeRunningTask(player, (ObjectManager.toJump,));

        // 床の上にYだけスナップ
        ObjectManager.snapOnTopOfYOnly(player, (ride_object!, 10.4));

        // 着地フラグ
        world.gameFlagPlayer.now_no_fly = true;

        // ジャンプ状態リセット
        world.gameJumpAnimationPlayer.flag_jumping_now = false;
        world.gameJumpAnimationPlayer.continuous_jump_count = 0;
      }
    } else {
      // 空中
      ride_object = null;
      world.gameFlagPlayer.now_no_fly = false;
    }

    // デバッグ用フレームカウント
    world.receiveInputPlayer.game_frame_count += 1;
  }

}


// ==============================================================
// 💀 GameoverJudgmentPlayer
// --------------------------------------------------------------
// 【役割】
//  ・adjustFlagPlayer が立てた
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
  // adjustFlagPlayer から ON にされる
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
  double hidden_xy = -10000.0;
  Size screenSize = SystemEnvService.screenSize;
  late Offset center_down;

  String frame_result = "ok";
  late List<dynamic> list_2d;
  int wait_time = 1;
  int? end_time = null;
  int currentIndex = 0;
  late List<List<List<dynamic>>> animation_film_3dlist;
  bool film_finished = false;

  @override
  void init() {
    list_2d = [];
    center_down = Offset(0, screenSize.height / 4);

    ObjectCreator.createImage( 
        objectName: "もう一回やる？ボタン",
        assetPath: "assets/images/once_again.png",
        position: Offset(hidden_xy, hidden_xy),
        width: 250,
        height: 120,
        enableCollision: true,
        layer: 600
      );
    ObjectCreator.createImage(objectName: "悲しい右目",assetPath: "assets/images/once_again.png",position: Offset(hidden_xy, hidden_xy),width: 180,height: 80,enableCollision: true,layer: 350);
    ObjectCreator.createImage(objectName: "悲しい左目",assetPath: "assets/images/once_again.png",position: Offset(hidden_xy, hidden_xy),width: 180,height: 80,enableCollision: true,layer: 351);
    ObjectCreator.createImage(objectName: "悲しい口",assetPath: "assets/images/once_again.png",position: Offset(hidden_xy, hidden_xy),width: 180,height: 80,rotation: pi,enableCollision: true,layer: 352);

    this.animation_film_3dlist = [
      
      AnimationDict.match2d([

        // もう一回やるボタンの表示
        [[world.objects["もう一回やる？ボタン"], (center_down.dx, center_down.dy), 0, ObjectManager.toSetPosition]],
        
        // 表情追従全解除
        AnimationDict.get("表情追従全解除"),

        // 表情追従全解除
        AnimationDict.get("表情全隠し"),

        // アノアノの顔を悲しいに変える。
        AnimationDict.get("悲しい顔"),

      ])
    ];
  }

  @override
  void mainScript() {
    if (!this.film_finished) { // ★逆
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
      this.film_finished = result.$7;
    }
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
      final name = ComponentsService.getObjectName(button);
      debugPrint("$name が押されました。");

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
// 
// 書くPlayerを1フレームで実行するために、idx管理するコードが未実装だ（2026年2月22日🌙）
// ==============================================================
class ScheduleMaking {
  final List<SuperPlayer> players;
  bool _initialized = false;
  ScheduleMaking(this.players);

  void reset() {
    _initialized = false;
  }

  void doing() {

    // ============================================
    // 🩵 初期化フェーズ（init）
    // ============================================
    if (!_initialized) {
      for (final player in players) {

        // --- 水色ログ ---
        debugPrint('\x1B[36m[INIT] ${player.runtimeType}\x1B[0m');

        player.init();
      }
      _initialized = true;
    }

    // ============================================
    // 🔵 メイン処理フェーズ（mainScript）
    // ============================================
    for (final player in players) {

      // --- 青ログ ---
      debugPrint('\x1B[34m[MAIN] ${player.runtimeType}\x1B[0m');

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


// 【！！注意！！】
// このクラスは、flutterが勝手に認識して、勝手にインスタンス化します。
// 
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
        world.gameFallAnimationPlayer, // ユーザの入力に対するジャンプ座標処理
        world.collisionGimmickPlayer, // コライダー判定フラグ
        world.adjustFlagPlayer,  // コライダーflagの処理。（例（着地判定の上書き（建物北に衝突→yを建物北（よりちょっと上）に上書き。）））
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

    // =============================================================
    // ✅ ゲームループ開始
    // =============================================================
    // 🎞 GIF更新（エンジンフレーム同期）
    SystemEnvService.startGif(frameIntervalMs: 501);
    _ticker.start();
  }

  void update() {
    // =============================================================
    // モード分岐プログラム
    // 
    // 【！！注意！！】
    // 「〇〇モードだった場合」
    // で考えること。
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
    // まだストーリーが終わっていないし、スキップも押されてない。
    else if (
          this.schedule_status == "ゲームストーリーモード" &&
          world.gameStoryPlayer.flag_story_end == false
        ) {

      // ゲームストーリーモードのまま。
      next_schedule = Mode_GameStoryMovie;
      this.schedule_status = "ゲームストーリーモード";
    }

    // --------------------------
    // ゲーム初期化モードだった
    // --------------------------
    // ゲームの初期化が終わっていなければ、モードはそのまま。
    else if (
          this.schedule_status == "ゲーム初期化モード" &&
          world.gameInitPlayer.flag_all_film_finished == false
        ) {
      // モードを変化させない。
      next_schedule = Mode_GameInit;
      this.schedule_status = "ゲーム初期化モード";
    }

    // ゲームの初期化が完了していれば、ゲームモードに遷移
    else if (
          this.schedule_status == "ゲーム初期化モード" &&
          world.gameInitPlayer.flag_all_film_finished
        ) {
      // ゲームモードに遷移。
      next_schedule = Mode_Game;
      this.schedule_status = "ゲームモード";
      // フラグをもとに戻す。
      world.gameInitPlayer.flag_all_film_finished = false;
    }

    // --------------------------
    // ゲームモードでかつ、
    // ゲームオーバーflagが立ってい
    // なければ、ゲームモードを継続
    // --------------------------
    else if (
          this.schedule_status == "ゲームモード" &&
          world.gameoverJudgmentPlayer.flag_gameover == false
        ) {

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
    // ゲーム終了画面で「もう一度や
    // る」ボタンが押された
    // --------------------------
    else if (
      this.schedule_status == "ゲームオーバーモード" &&
      world.gameOverInputPlayer.flag_one_more_start_button == true
    ) {

      world.gameOverInputPlayer.flag_one_more_start_button = false;

      next_schedule = Mode_GameInit;
      this.schedule_status = "ゲーム初期化モード";

      // ゲームオーバーのフィルムのフラグのをもとに戻す。
      world.gameOverDisplayPlayer.film_finished = false;
    }

    // --------------------------
    // ゲーム終了画面で何も入力さ
    // れていないなら、モード切替
    // しない。
    // --------------------------
    else if (
      this.schedule_status == "ゲームオーバーモード" &&
      world.gameOverInputPlayer.flag_one_more_start_button == false
    ) {

      next_schedule = Mode_GameOver;
      this.schedule_status = "ゲームオーバーモード";
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
      if (!same_before_schedule_mode) {
        // ★モードが切り替わった瞬間は、次モードの init を必ず走らせる
        next_schedule.reset();
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

    // --------------------------
    // アニメーションフィルム内の
    // funcの戻り値が"running"
    // だったものは、
    // ObjectManegerの
    // クラス変数（リスト型）に
    // 保持されているため、
    // その`runningリスト`が
    // 空でない限り、
    // そのリスト内のすべての行を
    // １回実行するメソッド。
    // 
    // 【注意】
    // next_schedule.doing(); より
    // 後に実行しなければ、追従メソ
    // ッドがずれてしまう。（まぁ
    // ここでもすこし追従がずれるん
    // だけどさ。）
    // --------------------------
    ObjectManager.updateRunningTasks();

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
/// ワールド（中心基準）→ 画面（左上基準）へ変換するための情報
class _RenderContext {
  final double centerX;
  final double centerY;
  const _RenderContext(this.centerX, this.centerY);

  double toScreenLeft(double worldX) => centerX + worldX;
  double toScreenTop(double worldY) => centerY + worldY;
}


/// =============================================================
/// WorldObject に「描画」を生やす（OOPっぽく責務を寄せる）
/// =============================================================
extension WorldObjectRenderExt on WorldObject {

  /// 通常描画（見た目）
  Widget buildVisual(_RenderContext ctx) {
    // CircleObject
    if (this is CircleObject) {
      final o = this as CircleObject;
      return Positioned(
        left: ctx.toScreenLeft(o.position.dx - o.size / 2),
        top:  ctx.toScreenTop (o.position.dy - o.size / 2),
        child: Container(
          width: o.size,
          height: o.size,
          decoration: BoxDecoration(
            color: o.color,
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    // ImageObject
    if (this is ImageObject) {
      final o = this as ImageObject;

      final isDebug = (this is DebugColliderImageObject);

      return Positioned(
        left: ctx.toScreenLeft(o.position.dx - o.width / 2),
        top:  ctx.toScreenTop (o.position.dy - o.height / 2),
        child: Transform.rotate(
          angle: o.rotation,
          child: Image.asset(
            o.assetPath,
            width: o.width,
            height: o.height,
            // ✅ デバッグコライダーだけ、必ず枠いっぱいに引き伸ばす
            fit: isDebug ? BoxFit.fill : null,
          ),
        ),
      );
    }

    // GifObject
    if (this is GifObject) {
      final o = this as GifObject;
      return Positioned(
        left: ctx.toScreenLeft(o.position.dx - o.width / 2),
        top:  ctx.toScreenTop (o.position.dy - o.height / 2),
        child: Transform.rotate(
          angle: o.rotation,
          child: Image.asset(
            o.currentAssetPath,
            width: o.width,
            height: o.height,
            fit: BoxFit.fill, // ✅ 追加
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

}



class WorldRenderer {

  static Widget draw() {
    final screenSize = SystemEnvService.screenSize;

    // まだ画面サイズが取れてない時は空で返す
    if (screenSize == Size.zero) {
      return const SizedBox.shrink();
    }

    final ctx = _RenderContext(
      screenSize.width / 2,
      screenSize.height / 2,
    );

    final sortedObjects = _sortedObjectsByLayer();

    final children = <Widget>[
      // ① 通常描画
      ...sortedObjects.map((o) => o.buildVisual(ctx)),
    ];

    return Stack(children: children);
  }

  static List<WorldObject> _sortedObjectsByLayer() {
    final list = world.objects.values.toList();
    list.sort((a, b) => a.layer.compareTo(b.layer));
    return list;
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



