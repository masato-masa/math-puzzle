import 'direction.dart';
import 'edges.dart';
import 'floor.dart';
import 'game_rules.dart';
import 'models.dart';
import 'move_event.dart';
import 'operators.dart';
import 'tile_state.dart';

/// 効果音トリガー用のイベント種別（GameController は音を鳴らさない。
/// SoundService がこれを購読して実際の再生を行う）。
///
/// 合体音は演算子ごとに鳴らし分ける（2048 のように「合体そのもの」を
/// 均一な手応えにせず、何をして合体したかが音だけでも伝わるように）。
/// mergePlus/Minus/Times/Div のどれにも当てはまらない場合の保険として
/// merge を残してある（本来は起こらない想定）。
enum GameSoundEvent {
  move,
  slide,
  merge,
  mergePlus,
  mergeMinus,
  mergeTimes,
  mergeDiv,
  burn,
  exit,
  blocked,
  win,
  fail,
  undo,
}

GameSoundEvent soundForOp(String? op) => switch (op) {
      '+' => GameSoundEvent.mergePlus,
      '−' => GameSoundEvent.mergeMinus,
      '×' => GameSoundEvent.mergeTimes,
      '÷' => GameSoundEvent.mergeDiv,
      _ => GameSoundEvent.merge,
    };

/// 1 手を解決した結果。まだ盤面には反映していない。
///
/// [GameController.attemptMove]（実際に動かす）と
/// [GameController.previewMove]（盤面に触らず結果だけ知る UI 用）が
/// 同じ判定を共有するための型。ルール判定を 1 か所に集約することで、
/// 「プレビューの表示と実際の挙動がズレる」ことが起きないようにしてある。
class MoveResolution {
  final MoveEventKind kind;
  final int toRow;
  final int toCol;

  /// 成立後の値。合体なら計算結果、移動なら床の効果を適用した後の値。
  final int value;

  /// 成立後の辺。
  final Edges edges;

  /// 氷で 1 マス以上余分に進んだか（効果音の出し分けに使う）。
  final bool slid;

  /// 合体する相手（合体以外では null）。
  final TileState? target;

  /// 移動先の床の残り回数を消費するか。
  final bool spendFloor;

  /// 動かせないときの理由（それ以外では null）。
  final String? reason;

  /// 合体に使われた演算子（+/−/×/÷）。合体・炎による焼却以外では null。
  /// 演算子ごとに効果音を鳴らし分けるのに使う。
  final String? op;

  const MoveResolution({
    required this.kind,
    required this.toRow,
    required this.toCol,
    required this.value,
    required this.edges,
    this.slid = false,
    this.target,
    this.spendFloor = false,
    this.reason,
    this.op,
  });

  bool get isBlocked => kind == MoveEventKind.blocked;
  bool get isMerge => kind == MoveEventKind.merged;
}

class _Snapshot {
  final List<TileState> tiles;
  final Map<String, int> floorCharges;
  final int moveCount;
  _Snapshot(this.tiles, this.floorCharges, this.moveCount);
}

/// 1 レベル分のプレイ状態。移動・衝突・床効果・出口・クリア/失敗判定・Undo を
/// 一手ずつ解決する。ルール（tools/v3_rules.py 相当）は game_rules.dart に
/// 委譲し、ここは「手を進める」責務に専念する。
///
/// package:flutter には一切依存しない（dart:ui が使えない素の Dart VM でも
/// `dart run`/`dart test` でそのまま動かせるようにするため）。変更通知は
/// Flutter の ChangeNotifier ではなく、同じ形の軽量な自前実装で行う。
/// UI 側は widgets/controller_listener.dart 経由で購読する。
class GameController {
  GameController(Level level) {
    _load(level);
  }

  final List<void Function()> _listeners = [];

  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) => _listeners.remove(listener);

  void notifyListeners() {
    for (final listener in List<void Function()>.of(_listeners)) {
      listener();
    }
  }

  void dispose() => _listeners.clear();

  late Level level;
  late List<TileState> tiles;
  late Map<String, int> _floorCharges; // "row,col" -> 残り回数
  int moveCount = 0;
  String? selectedTileId;
  String? message;
  bool _cleared = false;
  bool _failed = false;

  /// ヒント／アンドゥを一度でも使ったか。「ノーヒント・ノーアンドゥ」
  /// クリアの判定に使う（restart しても引き継がない＝その挑戦の記録）。
  bool hintUsed = false;
  bool undoUsed = false;

  /// ヒントで示された向き。表示専用（判定には使わない）。
  /// 実際に手を動かすと消える（1手目以外では意味を持たないため）。
  Direction? hintDirection;

  final List<_Snapshot> _history = [];
  void Function(GameSoundEvent event)? onSound;

  bool get isCleared => _cleared;
  bool get isFailed => _failed;
  int get movesLeft => level.limit - moveCount;
  bool get canUndo => _history.isNotEmpty;

  /// クリア時点でヒント・アンドゥを一度も使っていなければ true。
  bool get isPerfectClear => _cleared && !hintUsed && !undoUsed;

  void _load(Level lv) {
    level = lv;
    tiles = lv.tiles
        .map((t) => TileState(
              id: t.id,
              row: t.row,
              col: t.col,
              value: t.value,
              edges: t.edges,
              fixed: t.fixed,
            ))
        .toList();
    _floorCharges = {
      for (final f in lv.floors)
        if (f.kind != FloorKind.ice && f.uses != null)
          '${f.row},${f.col}': f.uses!,
    };
    moveCount = 0;
    selectedTileId = null;
    message = null;
    _cleared = false;
    _failed = false;
    hintUsed = false;
    undoUsed = false;
    hintDirection = null;
    _history.clear();
  }

  void restart() {
    _load(level);
    notifyListeners();
  }

  /// レベルに埋め込まれた最初の一手のヒントを見る。1手目にしか意味を
  /// 持たない（それ以降の局面を解く手順は埋め込んでいない）ので、
  /// 何か手を動かした後は呼んでも何も起きない。
  ///
  /// 使った時点で「ノーヒントクリア」の対象からは外れる。
  /// 手そのものは消費しない（示すだけ）ので、見るだけなら何度でも良い。
  void peekHint() {
    final hint = level.hintMove;
    if (hint == null || moveCount != 0) return;
    hintUsed = true;
    if (hint.direction != null && hint.row != null) {
      final tile = tileAt(hint.row!, hint.col!);
      if (tile != null) {
        selectedTileId = tile.id;
        hintDirection = hint.direction;
      }
    }
    notifyListeners();
  }

  TileState? tileAt(int row, int col) {
    for (final t in tiles) {
      if (t.row == row && t.col == col) return t;
    }
    return null;
  }

  TileState? tileById(String id) {
    for (final t in tiles) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// [row],[col] の床の残り回数。無制限または床が無ければ null。
  int? floorUsesLeft(int row, int col) => _floorCharges[_floorKey(row, col)];

  String _floorKey(int row, int col) => '$row,$col';

  void _pushHistory() {
    _history.add(_Snapshot(
      tiles.map((t) => t.clone()).toList(),
      Map<String, int>.from(_floorCharges),
      moveCount,
    ));
  }

  void undo() {
    if (_history.isEmpty) return;
    final snap = _history.removeLast();
    tiles = snap.tiles;
    _floorCharges = snap.floorCharges;
    moveCount = snap.moveCount;
    selectedTileId = null;
    message = null;
    _cleared = false;
    _failed = false;
    undoUsed = true;
    onSound?.call(GameSoundEvent.undo);
    notifyListeners();
  }

  void selectTile(String? id) {
    selectedTileId = id;
    message = null;
    notifyListeners();
  }

  /// [tileId] を [direction] へ動かしたらどうなるかを、盤面を変えずに調べる。
  /// UI の移動先プレビュー用。動かせない場合は理由付きで返る。
  MoveResolution previewMove(String tileId, Direction direction) {
    final tile = tileById(tileId);
    if (tile == null) {
      return MoveResolution(
        kind: MoveEventKind.blocked,
        toRow: 0,
        toCol: 0,
        value: 0,
        edges: Edges.empty(),
        reason: 'タイルがありません',
      );
    }
    return _resolveMove(tile, direction);
  }

  /// 1 手ぶんのルール判定。盤面には一切触らない（純粋関数として扱える）。
  ///
  /// 壁・氷の滑り・衝突・床効果をこの順で解決する。実際に動かす
  /// [attemptMove] も、プレビューの [previewMove] もここを通る。
  MoveResolution _resolveMove(TileState tile, Direction direction) {
    MoveResolution blocked(String reason) => MoveResolution(
          kind: MoveEventKind.blocked,
          toRow: tile.row,
          toCol: tile.col,
          value: tile.value,
          edges: tile.edges,
          reason: reason,
        );

    if (tile.fixed || _cleared || _failed) {
      return blocked('このタイルは動かせません');
    }

    final (dr, dc) = direction.delta;
    var cr = tile.row, cc = tile.col;
    TileState? hit;
    var slid = false; // 氷で 1 マス以上余分に進んだか
    while (true) {
      final nr = cr + dr, nc = cc + dc;
      if (nr < 0 || nr >= level.rows || nc < 0 || nc >= level.cols) break;
      if (level.isWall(nr, nc)) break;
      final occupant = tileAt(nr, nc);
      if (occupant != null) {
        hit = occupant;
        break;
      }
      cr = nr;
      cc = nc;
      final floor = level.floorAt(cr, cc);
      if (floor != null && floor.kind == FloorKind.ice) {
        slid = true;
        continue; // 滑り続ける
      }
      break;
    }

    if (hit != null) {
      // 炎は計算せずに相手を燃やす。炎自身も一緒に消える。
      if (canBurn(tile.value, hit.value)) {
        return MoveResolution(
          kind: MoveEventKind.burned,
          toRow: hit.row,
          toCol: hit.col,
          value: hit.value,
          edges: hit.edges,
          slid: slid,
          target: hit,
        );
      }
      final result = collide(
        moverValue: tile.value,
        moverEdges: tile.edges,
        targetValue: hit.value,
        targetEdges: hit.edges,
        direction: direction,
      );
      if (result != null) {
        return MoveResolution(
          kind: MoveEventKind.merged,
          toRow: hit.row,
          toCol: hit.col,
          value: result.value,
          edges: result.edges,
          slid: slid,
          target: hit,
          op: result.op,
        );
      }
      if (cr == tile.row && cc == tile.col) {
        return blocked(_collisionReason(tile.edges, hit.edges, direction));
      }
      // 氷で何マスか滑った末に、合体できない相手にぶつかった場合は
      // その手前のマスまでの移動は成立させる（下へフォールスルー）。
    }

    if (cr == tile.row && cc == tile.col) {
      return blocked('その向きには動けません');
    }

    final floor = level.floorAt(cr, cc);
    final landed = applyFloorLanding(
      kind: floor?.kind,
      value: tile.value,
      edges: tile.edges,
      usesLeft: _floorCharges[_floorKey(cr, cc)],
    );
    if (landed.rejected) {
      return blocked(floor!.kind == FloorKind.sqrt
          ? '平方数でないと √ のマスに入れません'
          : 'この値では ! のマスに入れません');
    }

    return MoveResolution(
      kind: MoveEventKind.moved,
      toRow: cr,
      toCol: cc,
      value: landed.value,
      edges: landed.edges,
      slid: slid,
      spendFloor: landed.spend,
    );
  }

  /// [tileId] を [direction] へ動かす。壁・氷・衝突・床効果を含めて
  /// 1 手ぶんを丸ごと解決する。成功時のみ手数を消費し、履歴を積む。
  MoveEvent attemptMove(String tileId, Direction direction) {
    final tile = tiles.firstWhere((t) => t.id == tileId);
    final startRow = tile.row, startCol = tile.col;
    final res = _resolveMove(tile, direction);

    if (res.isBlocked) {
      return _blocked(tile, res.reason!);
    }

    _pushHistory();
    hintDirection = null; // ヒントは1手目にしか対応していないので消す

    if (res.kind == MoveEventKind.burned) {
      final target = res.target!;
      // 炎も燃やした相手も盤から消える。選択は外す（残る物が無い）。
      tiles.removeWhere((t) => t.id == tile.id || t.id == target.id);
      if (selectedTileId == tile.id || selectedTileId == target.id) {
        selectedTileId = null;
      }
      moveCount++;
      message = null;
      _checkEnd();
      onSound?.call(GameSoundEvent.burn);
      notifyListeners();
      return MoveEvent(
        kind: MoveEventKind.burned,
        tileId: tileId,
        fromRow: startRow,
        fromCol: startCol,
        toRow: res.toRow,
        toCol: res.toCol,
        mergedIntoId: target.id,
      );
    }

    if (res.isMerge) {
      final target = res.target!;
      final targetId = target.id;
      target.value = res.value;
      target.edges = res.edges;
      tiles.removeWhere((t) => t.id == tile.id);
      moveCount++;
      message = null;
      // 合体したら、できあがったタイルをそのまま選択状態にする。
      // 動かしていたタイルは消えるので、ここで選び直さないと選択が
      // 外れてしまい、続けて動かすのに毎回タップし直すことになる。
      if (selectedTileId == tile.id) {
        selectedTileId = targetId;
      }
      _checkEnd();
      onSound?.call(soundForOp(res.op));
      notifyListeners();
      return MoveEvent(
        kind: MoveEventKind.merged,
        tileId: tileId,
        fromRow: startRow,
        fromCol: startCol,
        toRow: res.toRow,
        toCol: res.toCol,
        mergedIntoId: targetId,
      );
    }

    tile.row = res.toRow;
    tile.col = res.toCol;
    tile.value = res.value;
    tile.edges = res.edges;
    if (res.spendFloor) {
      final key = _floorKey(res.toRow, res.toCol);
      _floorCharges[key] =
          (_floorCharges[key] ?? level.floorAt(res.toRow, res.toCol)!.uses!) - 1;
    }
    moveCount++;
    message = null;
    _checkEnd();
    onSound?.call(res.slid ? GameSoundEvent.slide : GameSoundEvent.move);
    notifyListeners();
    return MoveEvent(
      kind: MoveEventKind.moved,
      tileId: tileId,
      fromRow: startRow,
      fromCol: startCol,
      toRow: res.toRow,
      toCol: res.toCol,
    );
  }

  MoveEvent _blocked(TileState tile, String reason) {
    message = reason;
    onSound?.call(GameSoundEvent.blocked);
    notifyListeners();
    return MoveEvent(
      kind: MoveEventKind.blocked,
      tileId: tile.id,
      fromRow: tile.row,
      fromCol: tile.col,
      toRow: tile.row,
      toCol: tile.col,
      message: reason,
    );
  }

  String _collisionReason(Edges moverEdges, Edges targetEdges, Direction direction) {
    final mEdge = moverEdges[direction];
    final tEdge = targetEdges[direction.opposite];
    final mHas = Operators.isOperator(mEdge);
    final tHas = Operators.isOperator(tEdge);
    if (mHas && tHas) return '両方に演算子があるのでぶつかれません';
    if (!mHas && !tHas) return 'どちらにも演算子が無いのでぶつかれません';
    final op = mHas ? mEdge! : tEdge!;
    if (op == '−') return '引くとマイナスになるので当てられません';
    if (op == '÷') return '割り切れないので当てられません';
    return 'この組み合わせでは計算できません';
  }

  MoveEvent? attemptExit(ExitSpec exit) {
    final tile = tileAt(exit.row, exit.col);
    if (tile == null) {
      message = '出口のマスにタイルがありません';
      notifyListeners();
      return null;
    }
    if (!exit.accepts(tile.value)) {
      message = 'この出口から出せるのは ${exit.label} です';
      notifyListeners();
      return null;
    }
    _pushHistory();
    hintDirection = null;
    final row = tile.row, col = tile.col;
    tiles.removeWhere((t) => t.id == tile.id);
    moveCount++;
    message = null;
    selectedTileId = null;
    _checkEnd();
    onSound?.call(GameSoundEvent.exit);
    notifyListeners();
    return MoveEvent(
      kind: MoveEventKind.exited,
      tileId: tile.id,
      fromRow: row,
      fromCol: col,
      toRow: row,
      toCol: col,
    );
  }

  void _checkEnd() {
    if (tiles.isEmpty) {
      _cleared = true;
      onSound?.call(GameSoundEvent.win);
    } else if (movesLeft <= 0) {
      _failed = true;
      onSound?.call(GameSoundEvent.fail);
    }
  }
}
