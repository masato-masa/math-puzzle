import 'package:audioplayers/audioplayers.dart';

import '../game/game_controller.dart';

/// 効果音の再生を担う。
///
/// 効果音は種類ごとに [AudioPlayer] を 1 つずつ使い回す（[init] で
/// 事前に音源を読み込んでおく）。呼ぶたびに新規作成すると、
/// 生成〜再生の間に挟まる await が多いほどブラウザ側の再生制限に
/// 引っかかりやすく、鳴ったり鳴らなかったりする原因になるため。
///
/// 効果音はいずれもタップ操作の結果として鳴るので、
/// 「ユーザー操作を伴わない再生」を禁じるブラウザの制限には該当しない。
///
/// 音源は tools/gen_audio.py が生成したプレースホルダー（合成音）。
/// 実際の効果音を用意できたら同じファイル名で assets/audio 以下を
/// 差し替えるだけでよく、このクラスの変更は不要。
class SoundService {
  SoundService();

  final Map<GameSoundEvent, AudioPlayer> _sfxPlayers = {};
  Future<void>? _initFuture;

  bool sfxEnabled = true;

  static const Map<GameSoundEvent, String> _sfxAssets = {
    GameSoundEvent.move: 'audio/sfx_move.wav',
    GameSoundEvent.slide: 'audio/sfx_slide.wav',
    GameSoundEvent.merge: 'audio/sfx_merge.wav',
    GameSoundEvent.exit: 'audio/sfx_exit.wav',
    GameSoundEvent.blocked: 'audio/sfx_blocked.wav',
    GameSoundEvent.undo: 'audio/sfx_undo.wav',
    GameSoundEvent.win: 'audio/sfx_win.wav',
    GameSoundEvent.fail: 'audio/sfx_fail.wav',
  };

  static const Map<GameSoundEvent, double> _sfxVolume = {
    GameSoundEvent.move: 0.55,
    GameSoundEvent.slide: 0.5,
    GameSoundEvent.merge: 0.7,
    GameSoundEvent.exit: 0.65,
    GameSoundEvent.blocked: 0.4,
    GameSoundEvent.undo: 0.5,
    GameSoundEvent.win: 0.8,
    GameSoundEvent.fail: 0.6,
  };

  Future<void> init() {
    return _initFuture ??= _doInit();
  }

  Future<void> _doInit() async {
    await Future.wait([
      for (final entry in _sfxAssets.entries) _prepareSfxPlayer(entry.key, entry.value),
    ]);
  }

  Future<void> _prepareSfxPlayer(GameSoundEvent event, String asset) async {
    final player = AudioPlayer();
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setVolume(_sfxVolume[event] ?? 0.6);
    await player.setSourceAsset(asset);
    _sfxPlayers[event] = player;
  }

  Future<void> playEvent(GameSoundEvent event) async {
    if (!sfxEnabled) return;
    await init();
    final player = _sfxPlayers[event];
    if (player == null) return;
    try {
      await player.seek(Duration.zero);
      await player.resume();
    } catch (_) {
      // 再生に失敗しても致命的ではないので無視する。
    }
  }

  void dispose() {
    for (final player in _sfxPlayers.values) {
      player.dispose();
    }
  }
}
