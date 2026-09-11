import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// 全ゲーム共通のヘッダー。
///
///     行1  [戻る]        タイトル        [設定] [?]
///     行2  ステータスバー（手数・クリア数など）
///
/// **行 1 に置いてよいのは、戻る・タイトル・設定・? の 4 つだけ。**
/// 手数もクリア数もすべて行 2（[status]）へ置く。行 2 は中身が空でも
/// [AppSizes.statusBar] の高さを取るので、盤面の縦位置が画面ごとにずれない。
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.onBack,
    this.onSettings,
    this.onHelp,
    this.status,
  });

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onSettings;
  final VoidCallback? onHelp;

  /// 行 2 に並べるもの。無くても高さは確保される。
  final List<Widget>? status;

  @override
  Widget build(BuildContext context) {
    // 左右の列を同じ幅にして、タイトルが本当に中央に来るようにする。
    // 右のボタンが 1 個か 2 個かでタイトルの中心がずれないようにするため。
    const sideWidth = AppSizes.hit * 2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: AppSizes.hit,
          child: Row(
            children: [
              SizedBox(
                width: sideWidth,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: onBack == null
                      ? null
                      : RoundIconButton(
                          icon: Icons.chevron_left,
                          tooltip: 'もどる',
                          onPressed: onBack,
                        ),
                ),
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.display.copyWith(fontSize: 20),
                ),
              ),
              SizedBox(
                width: sideWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onSettings != null)
                      RoundIconButton(
                        icon: Icons.settings,
                        tooltip: '設定',
                        onPressed: onSettings,
                      ),
                    if (onHelp != null) ...[
                      const SizedBox(width: 6),
                      RoundIconButton(
                        icon: Icons.help_outline,
                        tooltip: '遊びかた',
                        onPressed: onHelp,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: AppSizes.statusBar,
          child: status == null || status!.isEmpty
              ? null
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < status!.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      status![i],
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// ヘッダーの丸アイコン。見た目は 36px、当たり判定だけ 44px まで広げる。
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSizes.hit,
      height: AppSizes.hit,
      child: Center(
        child: Material(
          color: AppColors.gold,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: AppSizes.iconButton,
              height: AppSizes.iconButton,
              child: Tooltip(
                message: tooltip ?? '',
                child: Icon(icon, size: 22, color: AppColors.goldDeep),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ヘッダー 2 段目に並べる小さな情報のかたまり。
class StatPill extends StatelessWidget {
  const StatPill({super.key, this.label, this.value, this.valueColor, this.trailing});

  final String? label;
  final String? value;
  final Color? valueColor;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.rule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          if (label != null) Text(label!, style: AppTextStyles.caption),
          if (value != null) ...[
            if (label != null) const SizedBox(width: 5),
            Text(
              value!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 5),
            Text(trailing!, style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }
}

/// 盤面の下に置く操作のボタン。上＝ナビゲーション、下＝操作で全ゲーム揃える。
class ToolButton extends StatelessWidget {
  const ToolButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: AppColors.surface,
        shape: CircleBorder(side: BorderSide(color: AppColors.rule, width: 1.2)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: AppSizes.toolButton,
            height: AppSizes.toolButton,
            child: Tooltip(
              message: tooltip,
              child: Icon(icon, size: 28, color: AppColors.gold),
            ),
          ),
        ),
      ),
    );
  }
}

/// ツール行。
class ToolRow extends StatelessWidget {
  const ToolRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSizes.toolGap),
          children[i],
        ],
      ],
    );
  }
}
