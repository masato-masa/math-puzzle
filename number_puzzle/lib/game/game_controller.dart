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
enum GameSoundEvent { move, slide, merge, exit, blocked, win, fail, undo }

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

  final List<_Snapshot> _history = [];
  void Function(GameSoundEvent event)? onSound;

  bool get isCleared => _cleared;
  bool get isFailed => _failed;
  int get movesLeft => level.limit - moveCount;
  bool get canUndo => _history.isNotEmpty;

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
    _history.clear();
  }

  void restart() {
    _load(level);
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

    if (res.isMerge) {
      final target = res.target!;
      final targetId = target.id;
      target.value = res.value;
      target.edges = res.edges;
      tiles.removeWhere((t) => t.id == tile.id);
      moveCount++;
      message = null;
      _checkEnd();
      onSound?.call(GameSoundEvent.merge);
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
