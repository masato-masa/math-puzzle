import 'package:flutter/material.dart';

import '../game/course.dart';
import '../services/progress_service.dart';
import '../services/settings_service.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// 遊びかた・設定・テストツール。4 つのゲームで同じ形・同じ文言にしてある。
/// 中身だけ差し替えられるよう、外枠はここにまとめている。
Future<void> _showSheet(
  BuildContext context, {
  required String title,
  required List<Widget> children,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.sheetRadius),
        side: const BorderSide(color: AppColors.rule, width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.display.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _bullet(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('・', style: TextStyle(color: AppColors.textMuted)),
          Expanded(child: Text(text, style: AppTextStyles.body.copyWith(fontSize: 14))),
        ],
      ),
    );

Widget _closeButton(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pop(),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: const Text('とじる'),
      ),
    );

/// シートの中に積む行。設定のトグルもテストツールのボタンもこの形。
Widget _row({required Widget child, VoidCallback? onTap, Color? color}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.ground,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: DefaultTextStyle(
              style: AppTextStyles.body.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color ?? AppColors.textPrimary,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );

const _helpRules = [
  'タイルを動かしてぶつけると、書かれた演算子で計算が起きます。',
  '出口から数字を出し切るとクリアです。',
  '氷の床は止まるまで滑り、紫の床は辺を、琥珀の床は値を変えます。',
  '手数には上限があります。上限を超えるとやり直しです。',
];

const _helpControls = [
  'タイルをドラッグすると、その向きへ動きます。',
  '「もどす」で 1 手ずつ取り消せます。',
  '「ヒント」は 1 手目にだけ出せます。',
];

Future<void> showHelpSheet(BuildContext context) {
  return _showSheet(
    context,
    title: '遊びかた',
    children: [
      ..._helpRules.map(_bullet),
      const SizedBox(height: 6),
      Text('操作', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      ..._helpControls.map(_bullet),
      _closeButton(context),
    ],
  );
}

/// 設定。今は音の入切だけ。増やすときもここに行を足す。
Future<void> showSettingsSheet(
  BuildContext context, {
  required SettingsService settings,
  required ValueChanged<bool> onSfxChanged,
}) {
  return _showSheet(
    context,
    title: '設定',
    children: [
      StatefulBuilder(
        builder: (context, setSheetState) => _row(
          child: Row(
            children: [
              const Expanded(child: Text('音')),
              Switch(
                value: settings.sfxEnabled,
                activeThumbColor: AppColors.goldDeep,
                activeTrackColor: AppColors.gold,
                onChanged: (v) {
                  onSfxChanged(v);
                  setSheetState(() {});
                },
              ),
            ],
          ),
        ),
      ),
      _closeButton(context),
    ],
  );
}

/// テストツール。本番の操作導線には出さず、ホーム右下の小さなピルからだけ開く
/// （蛇パズル snake-puzzle/src/app/test.tsx と同じ方針）。
Future<void> showDevSheet(
  BuildContext context, {
  required List<Course> courses,
  required ProgressService progress,
  required VoidCallback onChanged,
}) {
  final levels = {
    for (final c in courses)
      for (final l in c.levels) l.levelId: l.par,
  };

  var status = '';

  return _showSheet(
    context,
    title: 'テストツール',
    children: [
      StatefulBuilder(
        builder: (context, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '本番では使わない、動作確認用のボタンです。',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
            ),
            _row(
              child: const Text('全ステージ開放'),
              onTap: () async {
                await progress.unlockAllForTesting(levels);
                onChanged();
                setSheetState(() => status = '${levels.length} ステージをクリア済みにしました。');
              },
            ),
            _row(
              color: AppColors.warn,
              child: const Text('きろくを ぜんぶ けす'),
              onTap: () async {
                await progress.clearAll();
                onChanged();
                setSheetState(() => status = 'きろくを消しました。');
              },
            ),
            SizedBox(
              height: 20,
              child: Text(
                status,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(color: AppColors.gold),
              ),
            ),
            _closeButton(context),
          ],
        ),
      ),
    ],
  );
}
