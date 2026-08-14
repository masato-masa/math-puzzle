import 'package:flutter/material.dart';

import '../game/floor.dart';
import '../game/models.dart';
import '../theme/app_theme.dart';
import 'floor_cell_widget.dart';

/// レベルに出てくる仕掛けの種類。床だけでなく「出口の性質」も含める
/// （プレイヤーから見ればどちらも "そのステージで問われること" なので）。
enum LevelGimmick { ice, rotate, swap, sqrt, fact, multiExit, rangeExit }

extension LevelGimmickX on LevelGimmick {
  String get glyph => switch (this) {
        LevelGimmick.ice => kFloorGlyph[FloorKind.ice]!,
        LevelGimmick.rotate => kFloorGlyph[FloorKind.rotate]!,
        LevelGimmick.swap => kFloorGlyph[FloorKind.swap]!,
        LevelGimmick.sqrt => kFloorGlyph[FloorKind.sqrt]!,
        LevelGimmick.fact => kFloorGlyph[FloorKind.fact]!,
        LevelGimmick.multiExit => '⇥',
        LevelGimmick.rangeExit => '〜',
      };

  Color get color => switch (this) {
        LevelGimmick.ice => floorColor(FloorKind.ice),
        LevelGimmick.rotate => floorColor(FloorKind.rotate),
        LevelGimmick.swap => floorColor(FloorKind.swap),
        LevelGimmick.sqrt => floorColor(FloorKind.sqrt),
        LevelGimmick.fact => floorColor(FloorKind.fact),
        LevelGimmick.multiExit || LevelGimmick.rangeExit => AppColors.gold,
      };

  String get label => switch (this) {
        LevelGimmick.ice => '氷',
        LevelGimmick.rotate => '回転',
        LevelGimmick.swap => '入替',
        LevelGimmick.sqrt => '平方根',
        LevelGimmick.fact => '階乗',
        LevelGimmick.multiExit => '複数出口',
        LevelGimmick.rangeExit => '範囲出口',
      };
}

/// そのレベルに出てくる仕掛けを、[LevelGimmick] の宣言順で列挙する。
/// 同じ種類の床が何枚あっても 1 つにまとめる。
List<LevelGimmick> gimmicksOf(Level level) {
  final found = <LevelGimmick>{};
  for (final f in level.floors) {
    found.add(switch (f.kind) {
      FloorKind.ice => LevelGimmick.ice,
      FloorKind.rotate => LevelGimmick.rotate,
      FloorKind.swap => LevelGimmick.swap,
      FloorKind.sqrt => LevelGimmick.sqrt,
      FloorKind.fact => LevelGimmick.fact,
    });
  }
  if (level.exits.length > 1) found.add(LevelGimmick.multiExit);
  if (level.exits.any((e) => e.minValue != null && e.maxValue != null)) {
    found.add(LevelGimmick.rangeExit);
  }
  return LevelGimmick.values.where(found.contains).toList();
}

/// 仕掛けを小さな記号の粒で並べる。レベル選択でひと目で
/// 「このステージで何が問われるか」が分かるようにするためのもの。
class GimmickChips extends StatelessWidget {
  const GimmickChips({super.key, required this.gimmicks, this.size = 20});

  final List<LevelGimmick> gimmicks;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (gimmicks.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final g in gimmicks)
          Tooltip(
            message: g.label,
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: g.color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(size * 0.28),
                border: Border.all(color: g.color.withValues(alpha: 0.5), width: 1),
              ),
              child: Text(
                g.glyph,
                style: TextStyle(
                  fontSize: size * 0.58,
                  height: 1.0,
                  fontWeight: FontWeight.w700,
                  color: Color.lerp(g.color, Colors.white, 0.25),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
