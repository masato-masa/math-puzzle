import 'package:flutter/material.dart';

import '../game/direction.dart';
import '../game/edges.dart';
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
  final int? newValue;
  const _Preview({
    required this.direction,
    required this.row,
    required this.col,
    required this.isMerge,
    this.newValue,
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

  Direction? _directionTo(TileState from, int row, int col) {
    final dr = row - from.row, dc = col - from.col;
    if (dr == 0 && dc == 0) return null;
    if (dr == 0) return dc > 0 ? Direction.right : Direction.left;
    if (dc == 0) return dr > 0 ? Direction.down : Direction.up;
    return null; // 同じ行・列でなければ向きを決められない
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
    }
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
        // 床で値が変わるときだけ変化後の値を出す（変わらないなら矢印だけ）。
        newValue: res.value != tile.value ? res.value : null,
      ));
    }
    return out;
  }

  Widget _positionedPreview(_Preview p, double cellSize) {
    return Positioned(
      left: p.col * cellSize,
      top: p.row * cellSize,
      width: cellSize,
      height: cellSize,
      child: p.isMerge
          ? MergeResultBadge(cellSize: cellSize, value: p.newValue ?? 0)
          : MoveDestinationMarker(
              cellSize: cellSize,
              direction: p.direction,
              newValue: p.newValue,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.controller.level;

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
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.groundTop, AppColors.ground],
                          stops: [0.0, 0.55],
                        ),
                        border: Border.all(color: AppColors.rule, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.55),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
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
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _onCellTap(r, c),
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
                                    ),
                                  ),
                                ),
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
