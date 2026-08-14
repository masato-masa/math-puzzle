// 演算子ごとの合体音の検証。
//
// 2048 のように「合体そのもの」を均一な手応えにせず、何をして
// 合体したかが音だけでも伝わるようにする機能。判定ロジックは
// GameController には無く soundForOp() 単体にある。
import 'package:flutter_test/flutter_test.dart';
import 'package:number_puzzle/game/direction.dart';
import 'package:number_puzzle/game/edges.dart';
import 'package:number_puzzle/game/game_controller.dart';
import 'package:number_puzzle/game/game_rules.dart';
import 'package:number_puzzle/game/models.dart';

void main() {
  test('演算子ごとに違う GameSoundEvent が割り当たる', () {
    expect(soundForOp('+'), GameSoundEvent.mergePlus);
    expect(soundForOp('−'), GameSoundEvent.mergeMinus);
    expect(soundForOp('×'), GameSoundEvent.mergeTimes);
    expect(soundForOp('÷'), GameSoundEvent.mergeDiv);
    expect(soundForOp(null), GameSoundEvent.merge, reason: '不明なら既定音にフォールバック');
  });

  test('collide() は実際に使った演算子を返す', () {
    final result = collide(
      moverValue: 7,
      moverEdges: Edges.fromMap(null),
      targetValue: 3,
      targetEdges: Edges.fromMap({'left': '−'}),
      direction: Direction.right,
    );
    expect(result?.op, '−');
  });

  test('合体すると、その演算子に応じた効果音が実際に鳴る', () {
    final level = Level(
      levelId: 'test',
      title: 'test',
      hint: '',
      tutorial: false,
      rows: 1,
      cols: 3,
      tiles: [
        TileSpec(id: 'a', row: 0, col: 0, value: 5, edges: Edges.fromMap(null)),
        TileSpec(
          id: 'b',
          row: 0,
          col: 1,
          value: 2,
          edges: Edges.fromMap({'left': '×'}),
        ),
      ],
      walls: const [],
      floors: const [],
      exits: const [],
      par: 99,
      limit: 99,
    );
    final c = GameController(level);
    GameSoundEvent? played;
    c.onSound = (e) => played = e;

    c.attemptMove('a', Direction.right);

    expect(played, GameSoundEvent.mergeTimes, reason: '5×2 は × の音のはず');
  });

  test('炎が燃やすと burn の効果音が鳴る', () {
    final level = Level(
      levelId: 'test',
      title: 'test',
      hint: '',
      tutorial: false,
      rows: 1,
      cols: 3,
      tiles: [
        TileSpec(id: 'a', row: 0, col: 0, value: 7, edges: Edges.fromMap(null)),
        TileSpec(id: 'f', row: 0, col: 1, value: kFireValue, edges: Edges.fromMap(null)),
      ],
      walls: const [],
      floors: const [],
      exits: const [],
      par: 99,
      limit: 99,
    );
    final c = GameController(level);
    GameSoundEvent? played;
    c.onSound = (e) => played = e;

    c.attemptMove('f', Direction.left);

    expect(played, GameSoundEvent.burn);
  });
}
