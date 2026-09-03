import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/app_settings.dart';
import '../providers/app_providers.dart';
import '../utils/import_books.dart';
import '../utils/pick_home_background.dart';
import '../widgets/home_background.dart';
import 'book_management_panel.dart';

class AppSettingsPanel extends ConsumerStatefulWidget {
  const AppSettingsPanel({
    super.key,
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  ConsumerState<AppSettingsPanel> createState() => _AppSettingsPanelState();
}

class _AppSettingsPanelState extends ConsumerState<AppSettingsPanel> {
  bool _showBookManagement = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final dialogTheme = theme.dialogTheme;
    final backgroundPath = settings.homeBackgroundPath;
    final hasBackground =
        backgroundPath != null && File(backgroundPath).existsSync();
    final fadePercent = ((1 - settings.homeBackgroundOpacity) * 100).round();

    return Material(
      color: dialogTheme.backgroundColor ?? theme.colorScheme.surface,
      elevation: dialogTheme.elevation ?? 6,
      shadowColor: dialogTheme.shadowColor ?? theme.shadowColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8.r)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 8.w, 8.h),
                child: Row(
                  children: [
                    Text('设置', style: textTheme.titleLarge),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: '关闭',
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 24.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SettingsRow(
                        title: '主题',
                        control: _AppThemeModePicker(
                          selected: settings.appThemeMode,
                          onChanged: (mode) {
                            ref.read(appSettingsProvider.notifier).update(
                                  settings.copyWith(appThemeMode: mode),
                                );
                          },
                        ),
                      ),
                      _SettingsRow(
                        title: '目录',
                        control: Align(
                          alignment: Alignment.centerRight,
                          child: Switch(
                            value: settings.showTocPanel,
                            onChanged: (value) {
                              ref.read(appSettingsProvider.notifier).update(
                                    settings.copyWith(showTocPanel: value),
                                  );
                            },
                          ),
                        ),
                      ),
                      _SettingsRow(
                        title: '导入',
                        control: Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonalIcon(
                            onPressed: () => importBooksFromPicker(ref),
                            icon: const Icon(Icons.upload_file, size: 18),
                            label: const Text('导入电子书'),
                          ),
                        ),
                      ),
                      _SettingsRow(
                        title: '管理',
                        control: Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() => _showBookManagement = true);
                            },
                            icon: const Icon(Icons.library_books_outlined,
                                size: 18),
                            label: const Text('电子书'),
                          ),
                        ),
                      ),
                  _SettingsRow(
                    title: '背景',
                    control: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (hasBackground) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6.r),
                            child: SizedBox(
                              width: 44.w,
                              height: 30.h,
                              child: HomeBackgroundPreview(
                                backgroundPath: backgroundPath,
                                backgroundOpacity:
                                    settings.homeBackgroundOpacity,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          OutlinedButton.icon(
                            onPressed: () => pickHomeBackground(ref),
                            icon: const Icon(Icons.image_outlined, size: 18),
                            label: const Text('更换'),
                          ),
                          SizedBox(width: 8.w),
                          _IconStepperButton(
                            icon: Icons.delete_outline,
                            tooltip: '清除背景图',
                            onPressed: () => clearHomeBackground(ref),
                          ),
                        ] else
                          OutlinedButton.icon(
                            onPressed: () => pickHomeBackground(ref),
                            icon: const Icon(Icons.image_outlined, size: 18),
                            label: const Text('选择背景图'),
                          ),
                      ],
                    ),
                  ),
                  if (hasBackground)
                    _SettingsRow(
                      title: '透明度',
                      control: _SettingsStepper(
                        valueLabel: '$fadePercent%',
                        onDecrement: fadePercent <= 0
                            ? null
                            : () {
                                ref.read(appSettingsProvider.notifier).update(
                                      settings.copyWith(
                                        homeBackgroundOpacity: 1 -
                                            ((fadePercent - 5).clamp(0, 100) /
                                                100),
                                      ),
                                    );
                              },
                        onIncrement: fadePercent >= 100
                            ? null
                            : () {
                                ref.read(appSettingsProvider.notifier).update(
                                      settings.copyWith(
                                        homeBackgroundOpacity: 1 -
                                            ((fadePercent + 5).clamp(0, 100) /
                                                100),
                                      ),
                                    );
                              },
                      ),
                    ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_showBookManagement)
            Positioned.fill(
              child: BookManagementPanel(
                onClose: () => setState(() => _showBookManagement = false),
              ),
            ),
        ],
      ),
    );
  }
}

class _AppThemeModePicker extends StatelessWidget {
  const _AppThemeModePicker({
    required this.selected,
    required this.onChanged,
  });

  final AppThemeMode selected;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (var i = 0; i < AppThemeMode.values.length; i++) ...[
          if (i > 0) SizedBox(width: 8.w),
          Expanded(
            child: _AppThemeModeOption(
              mode: AppThemeMode.values[i],
              selected: AppThemeMode.values[i] == selected,
              onTap: () => onChanged(AppThemeMode.values[i]),
              colorScheme: colorScheme,
            ),
          ),
        ],
      ],
    );
  }
}

class _AppThemeModeOption extends StatelessWidget {
  const _AppThemeModeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
    required this.colorScheme,
  });

  final AppThemeMode mode;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.secondaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 14.w,
                height: 14.w,
                decoration: BoxDecoration(
                  color: mode.previewColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.8),
                  ),
                ),
              ),
              SizedBox(width: 4.w),
              Flexible(
                child: Text(
                  mode.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    required this.control,
  });

  final String title;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 44.w,
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(child: control),
        ],
      ),
    );
  }
}

class _SettingsStepper extends StatelessWidget {
  const _SettingsStepper({
    required this.valueLabel,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String valueLabel;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove_rounded,
            onPressed: onDecrement,
          ),
          SizedBox(width: 8.w),
          _SettingsValueBadge(label: valueLabel),
          SizedBox(width: 8.w),
          _StepperButton(
            icon: Icons.add_rounded,
            onPressed: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;

    return Material(
      color: enabled
          ? colorScheme.surfaceContainerHighest
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
        side: BorderSide(
          color: enabled ? colorScheme.outline : colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8.r),
        child: SizedBox(
          width: 32.w,
          height: 32.w,
          child: Icon(
            icon,
            size: 18.sp,
            color: enabled
                ? colorScheme.onSurface
                : colorScheme.onSurface.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

class _IconStepperButton extends StatelessWidget {
  const _IconStepperButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.r),
          side: BorderSide(color: colorScheme.outline),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8.r),
          child: SizedBox(
            width: 32.w,
            height: 32.w,
            child: Icon(icon, size: 18.sp, color: colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class _SettingsValueBadge extends StatelessWidget {
  const _SettingsValueBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: BoxConstraints(minWidth: 44.w),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
      ),
    );
  }
}
