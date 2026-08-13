import 'package:audioplayers/audioplayers.dart';

import '../game/game_controller.dart';

/// BGM ループと効果音の再生を担う。
///
/// - BGM は専用の [AudioPlayer] を 1 つ確保してループ再生し続ける
///   （タイトル/レベル選択/パズル画面を通じて常時流す）。
/// - 効果音は種類ごとに [AudioPlayer] を 1 つずつ使い回す（[init] で
///   事前に音源を読み込んでおく）。以前は呼ぶたびに新規作成していたが、
///   Web では「新規プレイヤーの生成〜再生」までに挟まる await が多いほど
///   ブラウザの自動再生ブロックに引っかかりやすく、鳴ったり鳴らなかったり
///   する原因になっていたため、生成コストを [init] 側に前倒しした。
///
/// Web のブラウザは「ユーザー操作なしの音声再生」をブロックする。
/// アプリ起動直後の [playBgm] 呼び出しはこのブロックに引っかかることが
/// あるため、main.dart 側で最初のタップ／クリックのたびに [playBgm] を
/// 再試行し、実際に鳴らせるタイミングで確実に開始できるようにしている。
///
/// 音源は tools/gen_audio.py が生成したプレースホルダー（合成音）。
/// 実際の楽曲・効果音を用意できたら同じファイル名で assets/audio 以下を
/// 差し替えるだけでよく、このクラスの変更は不要。
class SoundService {
  SoundService();

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final Map<GameSoundEvent, AudioPlayer> _sfxPlayers = {};
  Future<void>? _initFuture;

  bool bgmEnabled = true;
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
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setVolume(0.28);
    await _bgmPlayer.setSourceAsset('audio/bgm_loop.wav');
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

  Future<void> playBgm() async {
    if (!bgmEnabled) return;
    await init();
    if (_bgmPlayer.state == PlayerState.playing) return;
    try {
      await _bgmPlayer.resume();
    } catch (_) {
      // ブラウザの自動再生ブロック。次のユーザー操作時に main.dart から
      // 再試行される。
    }
  }

  Future<void> stopBgm() => _bgmPlayer.stop();

  Future<void> setBgmEnabled(bool enabled) async {
    bgmEnabled = enabled;
    if (enabled) {
      await playBgm();
    } else {
      await stopBgm();
    }
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
    _bgmPlayer.dispose();
    for (final player in _sfxPlayers.values) {
      player.dispose();
    }
  }
}
