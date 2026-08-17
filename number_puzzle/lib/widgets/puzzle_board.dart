import 'package:flutter/material.dart';

import '../game/direction.dart';
import '../game/edges.dart';
import '../game/floor.dart';
import '../game/game_controller.dart';
import '../game/models.dart';
import '../game/move_event.dart';
import '../game/tile_state.dart';
import '../theme/app_theme.dart';
import 'controller_listener.dart';
import 'exit_marker_widget.dart';
import 'floor_cell_widget.dart';
import 'move_preview_widget.dart';
import 'tile_widget.dart';

const _kMoveAnim = Duration(milliseconds: 170);
const _kGhostAnim = Duration(milliseconds: 220);
const _kExitMargin = 44.0;

/// 選択中タイルの行き先 1 件分（表示用にほぐしたもの）。
class _Preview {
  final Direction direction;
  final int row, col;
  final bool isMerge;
  final bool isHint;
  const _Preview({
    required this.direction,
    required this.row,
    required this.col,
    required this.isMerge,
    this.isHint = false,
  });
}

class _GhostSpec {
  final int fromRow, fromCol, toRow, toCol, value;
  _GhostSpec({
    required this.fromRow,
    required this.fromCol,
    required this.toRow,
    required this.toCol,
    required this.value,
  });
}

/// 氷スライドの通過マスに一瞬だけ出す軌跡の粒 1 個ぶん。
///
/// 氷は「当たるまで止まらない」ので 1 手で何マスも進むが、タイル本体は
/// AnimatedPositioned で始点から終点へ直接すべるだけなので、途中の
/// マスを本当に通ったのかが伝わりにくい（特に距離が長いとき）。
/// 通過マスに軌跡を灯すことで、物理的に滑った感触を補う。
class _TrailDotSpec {
  final int row, col;
  final int index; // 出現を少しずつ遅らせるための順番
  _TrailDotSpec({required this.row, required this.col, required this.index});
}

/// 盤面の描画とタップ操作。ゲームルールの判定は一切持たず、
/// GameController を呼ぶだけ（このクラスの責務は「見た目とジェスチャー」）。
class PuzzleBoard extends StatefulWidget {
  const PuzzleBoard({super.key, required this.controller});

  final GameController controller;

  @override
  State<PuzzleBoard> createState() => _PuzzleBoardState();
}

class _PuzzleBoardState extends State<PuzzleBoard> {
  final List<_GhostSpec> _ghosts = [];
  final List<_TrailDotSpec> _trail = [];

  // スワイプ操作の途中経過（なぞり始めた位置・マスと、最後の指の位置）
  Offset? _panStart;
  Offset _panLast = Offset.zero;
  (int, int)? _panFrom;

  Direction? _directionTo(TileState from, int row, int col) {
    final dr = row - from.row, dc = col - from.col;
    if (dr == 0 && dc == 0) return null;
    if (dr == 0) return dc > 0 ? Direction.right : Direction.left;
    if (dc == 0) return dr > 0 ? Direction.down : Direction.up;
    return null; // 同じ行・列でなければ向きを決められない
  }

  /// 盤の左上を原点とした座標を、マスの位置に直す。盤の外なら null。
  (int, int)? _cellAt(Offset pos, double cellSize) {
    final level = widget.controller.level;
    final col = (pos.dx / cellSize).floor();
    final row = (pos.dy / cellSize).floor();
    if (row < 0 || row >= level.rows || col < 0 || col >= level.cols) return null;
    return (row, col);
  }

  void _onBoardTap(Offset pos, double cellSize) {
    final cell = _cellAt(pos, cellSize);
    if (cell != null) _onCellTap(cell.$1, cell.$2);
  }

  void _onPanStart(Offset pos, double cellSize) {
    _panStart = pos;
    _panLast = pos;
    _panFrom = _cellAt(pos, cellSize);
  }

  /// スワイプで直接動かす。なぞり始めたマスのタイルを、
  /// 指を動かした向き（縦横のうち移動量が大きい方）へ 1 手動かす。
  ///
  /// タップ 2 回（選ぶ→行き先）でも動かせるが、
  /// 「そのタイルをその向きへ」という操作はスワイプの方が直接的なので、
  /// 両方を受け付けるようにしてある。
  void _onPanEnd(double cellSize) {
    final from = _panFrom;
    final start = _panStart;
    _panFrom = null;
    _panStart = null;
    if (from == null || start == null) return;

    final c = widget.controller;
    if (c.isCleared || c.isFailed) return;

    final delta = _panLast - start;
    // 短すぎるなぞりは誤操作とみなす（タップとの取り違えを防ぐ）。
    if (delta.distance < cellSize * 0.35) return;

    final dir = delta.dx.abs() > delta.dy.abs()
        ? (delta.dx > 0 ? Direction.right : Direction.left)
        : (delta.dy > 0 ? Direction.down : Direction.up);

    final tile = c.tileAt(from.$1, from.$2);
    if (tile == null) return;
    c.selectTile(tile.id);
    _performMove(tile, dir);
  }

  void _onCellTap(int row, int col) {
    final c = widget.controller;
    if (c.isCleared || c.isFailed) return;

    final tapped = c.tileAt(row, col);
    final selectedId = c.selectedTileId;

    if (selectedId == null) {
      if (tapped != null) c.selectTile(tapped.id);
      return;
    }
    if (tapped != null && tapped.id == selectedId) {
      c.selectTile(null);
      return;
    }
    final selected = c.tileById(selectedId);
    if (selected == null) {
      c.selectTile(null);
      return;
    }

    final dir = _directionTo(selected, row, col);
    if (dir != null) {
      _performMove(selected, dir);
    } else if (tapped != null) {
      c.selectTile(tapped.id);
    }
  }

  void _performMove(TileState tile, Direction dir) {
    final origValue = tile.value;
    final event = widget.controller.attemptMove(tile.id, dir);
    if (event.kind == MoveEventKind.merged) {
      _spawnGhost(
        fromRow: event.fromRow,
        fromCol: event.fromCol,
        toRow: event.toRow,
        toCol: event.toCol,
        value: origValue,
      );
    } else if (event.kind == MoveEventKind.moved) {
      // 素の移動で 2 マス以上動くのは氷スライドしかありえない
      // （氷が無ければ 1 手は必ず 1 マスで止まる）。
      final dr = event.toRow - event.fromRow;
      final dc = event.toCol - event.fromCol;
      final dist = dr.abs() + dc.abs();
      if (dist > 1) {
        _spawnTrail(event.fromRow, event.fromCol, event.toRow, event.toCol);
      }
    }
  }

  void _spawnTrail(int fromRow, int fromCol, int toRow, int toCol) {
    final dr = (toRow - fromRow).sign;
    final dc = (toCol - fromCol).sign;
    final dist = (toRow - fromRow).abs() + (toCol - fromCol).abs();
    final dots = <_TrailDotSpec>[
      for (var i = 1; i < dist; i++)
        _TrailDotSpec(row: fromRow + dr * i, col: fromCol + dc * i, index: i),
    ];
    setState(() => _trail.addAll(dots));
    Future.delayed(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      setState(() => _trail.removeWhere(dots.contains));
    });
  }

  void _spawnGhost({
    required int fromRow,
    required int fromCol,
    required int toRow,
    required int toCol,
    required int value,
  }) {
    final ghost = _GhostSpec(
      fromRow: fromRow,
      fromCol: fromCol,
      toRow: toRow,
      toCol: toCol,
      value: value,
    );
    setState(() => _ghosts.add(ghost));
    Future.delayed(_kGhostAnim, () {
      if (!mounted) return;
      setState(() => _ghosts.remove(ghost));
    });
  }

  void _onExitTap(ExitSpec exit) {
    widget.controller.attemptExit(exit);
  }

  /// 選択中のタイルについて、4 方向それぞれの行き先を調べる。
  /// 動かせない向きは省く（盤上には「できること」だけを出す）。
  List<_Preview> _previews() {
    final c = widget.controller;
    final id = c.selectedTileId;
    if (id == null || c.isCleared || c.isFailed) return const [];
    final tile = c.tileById(id);
    if (tile == null) return const [];

    final out = <_Preview>[];
    for (final d in kAllDirections) {
      final res = c.previewMove(id, d);
      if (res.isBlocked) continue;
      out.add(_Preview(
        direction: d,
        row: res.toRow,
        col: res.toCol,
        isMerge: res.isMerge,
        // ヒントで示された向きだけ、他と区別できる見た目にする。
        isHint: c.hintDirection == d,
      ));
    }
    return out;
  }

  Widget _positionedPreview(_Preview p, double cellSize) {
    // 合体できる相手には何も重ねない。
    // 以前は印を出していたが、✕ は「そこへは行けない」という意味に
    // 見えてしまい、合体できる合図としては逆の印象を与えていた。
    // 相手のマスにはタイルが載っているので、枠を重ねると数字も隠れる。
    // ヒントで示された向きのときだけ、光の輪（枠なし）を出す。
    final marker = p.isMerge
        ? const SizedBox.shrink()
        : MoveDestinationMarker(cellSize: cellSize, direction: p.direction);
    return Positioned(
      left: p.col * cellSize,
      top: p.row * cellSize,
      width: cellSize,
      height: cellSize,
      child: p.isHint ? HintGlow(cellSize: cellSize, child: marker) : marker,
    );
  }

  /// 通れるマスがすべて氷か。氷は「装置」ではなく「地形」なので、
  /// 盤一面が氷のときにマスごとの印を出すと画面が記号で埋まってしまう。
  /// その場合は印をやめ、盤そのものを氷の色にして「ここは全部氷」と
  /// 一目で分かる見せ方に切り替える。
  bool get _isIceField {
    final level = widget.controller.level;
    var open = 0;
    for (var r = 0; r < level.rows; r++) {
      for (var c = 0; c < level.cols; c++) {
        if (level.isWall(r, c)) continue;
        open++;
        if (level.floorAt(r, c)?.kind != FloorKind.ice) return false;
      }
    }
    return open > 0;
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.controller.level;
    final iceField = _isIceField;

    return ControllerListener(
      controller: widget.controller,
      builder: (context) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final availW = constraints.maxWidth - _kExitMargin * 2;
            final availH = constraints.maxHeight - _kExitMargin * 2;
            final cellFromW = availW / level.cols;
            final cellFromH = availH / level.rows;
            final cellSize = (cellFromW < cellFromH ? cellFromW : cellFromH)
                .clamp(24.0, 140.0);
            final boardW = cellSize * level.cols;
            final boardH = cellSize * level.rows;

            return SizedBox(
              width: boardW + _kExitMargin * 2,
              height: boardH + _kExitMargin * 2,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: _kExitMargin,
                    top: _kExitMargin,
                    width: boardW,
                    height: boardH,
                    child: Container(
                      decoration: BoxDecoration(
                        // 全面氷の盤は、マスごとの印ではなく盤の色で示す。
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: iceField
                              ? [
                                  Color.lerp(AppColors.groundTop,
                                      AppColors.cyan, 0.22)!,
                                  Color.lerp(AppColors.ground,
                                      AppColors.cyan, 0.14)!,
                                ]
                              : const [AppColors.groundTop, AppColors.ground],
                          stops: const [0.0, 0.55],
                        ),
                        border: Border.all(
                          color: iceField
                              ? AppColors.cyan.withValues(alpha: 0.55)
                              : AppColors.rule,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.55),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      // タップとスワイプを盤全体で 1 か所に受ける。
                      // マスごとに検出器を置くと、スワイプが最初のマスで
                      // 途切れてしまうため。
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) => _onBoardTap(d.localPosition, cellSize),
                        onPanStart: (d) => _onPanStart(d.localPosition, cellSize),
                        onPanUpdate: (d) => _panLast = d.localPosition,
                        onPanEnd: (_) => _onPanEnd(cellSize),
                        child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (var r = 0; r < level.rows; r++)
                            for (var c = 0; c < level.cols; c++)
                              Positioned(
                                left: c * cellSize,
                                top: r * cellSize,
                                width: cellSize,
                                height: cellSize,
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.05),
                                        width: 0.6,
                                      ),
                                    ),
                                    child: FloorCellWidget(
                                      cellSize: cellSize,
                                      isWall: level.isWall(r, c),
                                      floor: level.floorAt(r, c)?.kind,
                                      usesLeft: level.floorAt(r, c) == null
                                          ? null
                                          : widget.controller.floorUsesLeft(r, c),
                                      suppressIce: iceField,
                                    ),
                                  ),
                                ),
                              ),
                          for (final dot in _trail)
                            _SlideTrailDot(
                              key: ValueKey('trail_${dot.row}_${dot.col}_${dot.index}'),
                              row: dot.row,
                              col: dot.col,
                              delay: Duration(milliseconds: dot.index * 22),
                              cellSize: cellSize,
                            ),
                          for (final t in widget.controller.tiles)
                            AnimatedPositioned(
                              key: ValueKey(t.id),
                              duration: _kMoveAnim,
                              curve: Curves.easeOutCubic,
                              left: t.col * cellSize,
                              top: t.row * cellSize,
                              width: cellSize,
                              height: cellSize,
                              child: IgnorePointer(
                                child: TileWidget(
                                  value: t.value,
                                  edges: t.edges,
                                  fixed: t.fixed,
                                  selected: widget.controller.selectedTileId == t.id,
                                  cellSize: cellSize,
                                ),
                              ),
                            ),
                          // 選択中タイルの行き先プレビュー。タイルより上に重ねる。
                          for (final p in _previews()) _positionedPreview(p, cellSize),
                          for (final g in _ghosts)
                            _FlyingGhost(ghost: g, cellSize: cellSize),
                        ],
                      ),
                      ),
                    ),
                  ),
                  for (final exit in level.exits)
                    _positionedExit(exit, cellSize, boardW, boardH),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _positionedExit(ExitSpec exit, double cellSize, double boardW, double boardH) {
    const w = 56.0, h = 30.0;
    final cx = _kExitMargin + exit.col * cellSize + cellSize / 2;
    final cy = _kExitMargin + exit.row * cellSize + cellSize / 2;
    double left, top;
    switch (exit.direction) {
      case ExitDirection.up:
        left = cx - w / 2;
        top = _kExitMargin - h - 6;
      case ExitDirection.down:
        left = cx - w / 2;
        top = _kExitMargin + boardH + 6;
      case ExitDirection.left:
        left = _kExitMargin - w - 6;
        top = cy - h / 2;
      case ExitDirection.right:
        left = _kExitMargin + boardW + 6;
        top = cy - h / 2;
    }

    final tile = widget.controller.tileAt(exit.row, exit.col);
    final ready = tile != null && exit.accepts(tile.value);

    return Positioned(
      left: left,
      top: top,
      width: w,
      height: h,
      child: Center(
        child: ExitMarkerWidget(
          exit: exit,
          ready: ready,
          onTap: () => _onExitTap(exit),
        ),
      ),
    );
  }
}

/// 合体アニメーション用のゴースト。mover が消えた瞬間から短時間だけ、
/// target の位置へ滑り込むように見せる（実データは既に更新済みで、
/// これは視覚効果のみ）。
/// 氷スライドの通過マスに一瞬灯る光の粒。[delay] だけ遅れて現れ、
/// 手前のマスから奥のマスへ順に灯っていくことで「通り過ぎた」向きが
/// 伝わるようにしてある。
class _SlideTrailDot extends StatefulWidget {
  const _SlideTrailDot({
    super.key,
    required this.row,
    required this.col,
    required this.delay,
    required this.cellSize,
  });

  final int row, col;
  final Duration delay;
  final double cellSize;

  @override
  State<_SlideTrailDot> createState() => _SlideTrailDotState();
}

class _SlideTrailDotState extends State<_SlideTrailDot> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.cellSize;
    return Positioned(
      left: widget.col * size,
      top: widget.row * size,
      width: size,
      height: size,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: Center(
            child: Container(
              width: size * 0.22,
              height: size * 0.22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cyan.withValues(alpha: 0.75),
                boxShadow: [
                  BoxShadow(color: AppColors.cyan.withValues(alpha: 0.6), blurRadius: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlyingGhost extends StatefulWidget {
  const _FlyingGhost({required this.ghost, required this.cellSize});
  final _GhostSpec ghost;
  final double cellSize;

  @override
  State<_FlyingGhost> createState() => _FlyingGhostState();
}

class _FlyingGhostState extends State<_FlyingGhost> {
  bool _atDestination = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _atDestination = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.ghost;
    final row = _atDestination ? g.toRow : g.fromRow;
    final col = _atDestination ? g.toCol : g.fromCol;
    return AnimatedPositioned(
      duration: _kGhostAnim,
      curve: Curves.easeIn,
      left: col * widget.cellSize,
      top: row * widget.cellSize,
      width: widget.cellSize,
      height: widget.cellSize,
      child: AnimatedOpacity(
        duration: _kGhostAnim,
        opacity: _atDestination ? 0.0 : 1.0,
        curve: Curves.easeIn,
        child: IgnorePointer(
          child: TileWidget(
            value: g.value,
            edges: Edges.empty(),
            fixed: false,
            selected: false,
            cellSize: widget.cellSize,
          ),
        ),
      ),
    );
  }
}
