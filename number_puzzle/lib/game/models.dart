import 'edges.dart';
import 'floor.dart';

/// レベルに定義された初期タイル（不変・レベルデータそのもの）。
class TileSpec {
  final String id;
  final int row;
  final int col;
  final int value;
  final Edges edges;
  final bool fixed;

  const TileSpec({
    required this.id,
    required this.row,
    required this.col,
    required this.value,
    required this.edges,
    this.fixed = false,
  });

  factory TileSpec.fromJson(Map<String, dynamic> json) => TileSpec(
        id: json['id'] as String,
        row: json['row'] as int,
        col: json['col'] as int,
        value: json['value'] as int,
        edges: Edges.fromMap(json['edges'] as Map<String, dynamic>?),
        fixed: json['fixed'] as bool? ?? false,
      );
}

class WallCell {
  final int row;
  final int col;
  const WallCell(this.row, this.col);

  factory WallCell.fromJson(Map<String, dynamic> json) =>
      WallCell(json['row'] as int, json['col'] as int);
}

enum ExitDirection { up, right, down, left }

extension ExitDirectionX on ExitDirection {
  static ExitDirection fromName(String name) =>
      ExitDirection.values.firstWhere((d) => d.name == name);
}

class ExitSpec {
  final int row;
  final int col;
  final ExitDirection direction;
  final int? value;
  final int? minValue;
  final int? maxValue;

  const ExitSpec({
    required this.row,
    required this.col,
    required this.direction,
    this.value,
    this.minValue,
    this.maxValue,
  });

  factory ExitSpec.fromJson(Map<String, dynamic> json) => ExitSpec(
        row: json['row'] as int,
        col: json['col'] as int,
        direction: ExitDirectionX.fromName(json['direction'] as String),
        value: json['value'] as int?,
        minValue: json['minValue'] as int?,
        maxValue: json['maxValue'] as int?,
      );

  bool accepts(int tileValue) {
    if (minValue != null && maxValue != null) {
      return tileValue >= minValue! && tileValue <= maxValue!;
    }
    if (value == null) return true;
    return tileValue == value;
  }

  String get label {
    if (minValue != null && maxValue != null) return '$minValue-$maxValue';
    return value?.toString() ?? '';
  }
}

/// 1 レベルの静的な定義。ソルバー（tools/v3_levels.py）が検証して
/// par / limit を確定させたものをそのまま読み込む。アプリ側では計算しない。
class Level {
  final String levelId;
  final String title;
  final String hint;
  final bool tutorial;
  final int rows;
  final int cols;
  final List<TileSpec> tiles;
  final List<WallCell> walls;
  final List<FloorTile> floors;
  final List<ExitSpec> exits;
  final int par;
  final int limit;

  const Level({
    required this.levelId,
    required this.title,
    required this.hint,
    required this.tutorial,
    required this.rows,
    required this.cols,
    required this.tiles,
    required this.walls,
    required this.floors,
    required this.exits,
    required this.par,
    required this.limit,
  });

  factory Level.fromJson(Map<String, dynamic> json) {
    final size = json['size'] as int?;
    return Level(
      levelId: json['levelId'] as String,
      title: json['title'] as String,
      hint: json['hint'] as String? ?? '',
      tutorial: json['tutorial'] as bool? ?? false,
      rows: json['rows'] as int? ?? size!,
      cols: json['cols'] as int? ?? size!,
      tiles: (json['tiles'] as List)
          .map((t) => TileSpec.fromJson(t as Map<String, dynamic>))
          .toList(),
      walls: (json['walls'] as List? ?? [])
          .map((w) => WallCell.fromJson(w as Map<String, dynamic>))
          .toList(),
      floors: (json['floors'] as List? ?? [])
          .map((f) => FloorTile.fromJson(f as Map<String, dynamic>))
          .toList(),
      exits: (json['exits'] as List)
          .map((e) => ExitSpec.fromJson(e as Map<String, dynamic>))
          .toList(),
      par: json['par'] as int,
      limit: json['limit'] as int? ?? json['par'] as int,
    );
  }

  bool isWall(int row, int col) =>
      walls.any((w) => w.row == row && w.col == col);

  FloorTile? floorAt(int row, int col) {
    for (final f in floors) {
      if (f.row == row && f.col == col) return f;
    }
    return null;
  }

  bool exitIsOnBorder(ExitSpec e) => switch (e.direction) {
        ExitDirection.up => e.row == 0,
        ExitDirection.down => e.row == rows - 1,
        ExitDirection.left => e.col == 0,
        ExitDirection.right => e.col == cols - 1,
      };
}
