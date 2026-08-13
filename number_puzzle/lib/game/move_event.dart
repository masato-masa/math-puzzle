/// GameController.attemptMove / attemptExit の結果。
///
/// UI 層はこれを見て「アニメーションさせるか」「効果音を何にするか」
/// 「メッセージを出すか」を決める。ゲームルール自体はここに依存しない。
enum MoveEventKind {
  /// 空きマスへ（あるいは氷で滑って）移動した
  moved,

  /// ぶつかって計算が成立し、mover が target に合体した
  merged,

  /// 出口から出た
  exited,

  /// 何も起きなかった（手数は消費しない）。message に理由が入る
  blocked,
}

class MoveEvent {
  final MoveEventKind kind;
  final String tileId;
  final int fromRow;
  final int fromCol;
  final int toRow;
  final int toCol;

  /// merged のときだけ非null。合体先タイルの id
  final String? mergedIntoId;

  /// blocked のときだけ非null。UI に出すメッセージ
  final String? message;

  const MoveEvent({
    required this.kind,
    required this.tileId,
    required this.fromRow,
    required this.fromCol,
    required this.toRow,
    required this.toCol,
    this.mergedIntoId,
    this.message,
  });

  bool get didMove => fromRow != toRow || fromCol != toCol;
}
