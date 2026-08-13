// GameSoundEvent は game_controller.dart 側で定義している。
// SoundService から GameController の詳細（ルール層）を知らずに扱えるよう、
// この re-export だけを services 層に置く。
export '../game/game_controller.dart' show GameSoundEvent;
