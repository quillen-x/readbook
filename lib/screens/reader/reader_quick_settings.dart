import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../models/app_settings.dart';
import '../../providers/app_providers.dart';

class ReaderQuickSettingsPanel extends ConsumerWidget {
  const ReaderQuickSettingsPanel({
    super.key,
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final dialogTheme = theme.dialogTheme;

    return Material(
      color: dialogTheme.backgroundColor ?? theme.colorScheme.surface,
      elevation: dialogTheme.elevation ?? 6,
      shadowColor: dialogTheme.shadowColor ?? theme.shadowColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 8.w, 8.h),
            child: Row(
              children: [
                Text('阅读设置', style: textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: '关闭',
                  onPressed: onClose,
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
                    control: _ReaderThemeModePicker(
                      selected: settings.themeMode,
                      onChanged: (mode) {
                        ref.read(appSettingsProvider.notifier).update(
                              settings.copyWith(themeMode: mode),
                            );
                      },
                    ),
                  ),
                  _SettingsRow(
                    title: '字重',
                    control: _ReaderFontWeightPicker(
                      selected: settings.fontWeight,
                      onChanged: (weight) {
                        ref.read(appSettingsProvider.notifier).update(
                              settings.copyWith(fontWeight: weight),
                            );
                      },
                    ),
                  ),
                  _SettingsRow(
                    title: '字号',
                    control: _SettingsStepper(
                      valueLabel: settings.fontSize.toStringAsFixed(0),
                      onDecrement: settings.fontSize <= 12
                          ? null
                          : () {
                              ref.read(appSettingsProvider.notifier).update(
                                    settings.copyWith(
                                      fontSize: settings.fontSize - 1,
                                    ),
                                  );
                            },
                      onIncrement: settings.fontSize >= 28
                          ? null
                          : () {
                              ref.read(appSettingsProvider.notifier).update(
                                    settings.copyWith(
                                      fontSize: settings.fontSize + 1,
                                    ),
                                  );
                            },
                    ),
                  ),
                  _SettingsRow(
                    title: '行高',
                    control: _SettingsStepper(
                      valueLabel: settings.lineHeight.toStringAsFixed(1),
                      onDecrement: settings.lineHeight <= 1.2
                          ? null
                          : () {
                              ref.read(appSettingsProvider.notifier).update(
                                    settings.copyWith(
                                      lineHeight: double.parse(
                                        (settings.lineHeight - 0.1).toStringAsFixed(1),
                                      ),
                                    ),
                                  );
                            },
                      onIncrement: settings.lineHeight >= 2.0
                          ? null
                          : () {
                              ref.read(appSettingsProvider.notifier).update(
                                    settings.copyWith(
                                      lineHeight: double.parse(
                                        (settings.lineHeight + 0.1).toStringAsFixed(1),
                                      ),
                                    ),
                                  );
                            },
                    ),
                  ),
                  _SettingsRow(
                    title: '边距',
                    control: _SettingsStepper(
                      valueLabel: '${(settings.readerContentWidthPercent * 100).round()}%',
                      onDecrement: settings.readerContentWidthPercent <= 0.55
                          ? null
                          : () {
                              ref.read(appSettingsProvider.notifier).update(
                                    settings.copyWith(
                                      readerContentWidthPercent: double.parse(
                                        (settings.readerContentWidthPercent - 0.05).clamp(0.55, 1.0).toStringAsFixed(2),
                                      ),
                                    ),
                                  );
                            },
                      onIncrement: settings.readerContentWidthPercent >= 1.0
                          ? null
                          : () {
                              ref.read(appSettingsProvider.notifier).update(
                                    settings.copyWith(
                                      readerContentWidthPercent: double.parse(
                                        (settings.readerContentWidthPercent + 0.05).clamp(0.55, 1.0).toStringAsFixed(2),
                                      ),
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
    );
  }
}

class _ReaderThemeModePicker extends StatelessWidget {
  const _ReaderThemeModePicker({
    required this.selected,
    required this.onChanged,
  });

  final ReaderThemeMode selected;
  final ValueChanged<ReaderThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (var i = 0; i < ReaderThemeMode.values.length; i++) ...[
          if (i > 0) SizedBox(width: 8.w),
          Expanded(
            child: _ReaderThemeModeOption(
              mode: ReaderThemeMode.values[i],
              selected: ReaderThemeMode.values[i] == selected,
              onTap: () => onChanged(ReaderThemeMode.values[i]),
              colorScheme: colorScheme,
            ),
          ),
        ],
      ],
    );
  }
}

class _ReaderThemeModeOption extends StatelessWidget {
  const _ReaderThemeModeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
    required this.colorScheme,
  });

  final ReaderThemeMode mode;
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
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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

class _ReaderFontWeightPicker extends StatelessWidget {
  const _ReaderFontWeightPicker({
    required this.selected,
    required this.onChanged,
  });

  final ReaderFontWeightOption selected;
  final ValueChanged<ReaderFontWeightOption> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (var i = 0; i < ReaderFontWeightOption.values.length; i++) ...[
          if (i > 0) SizedBox(width: 6.w),
          Expanded(
            child: _ReaderFontWeightOption(
              weight: ReaderFontWeightOption.values[i],
              selected: ReaderFontWeightOption.values[i] == selected,
              onTap: () => onChanged(ReaderFontWeightOption.values[i]),
              colorScheme: colorScheme,
            ),
          ),
        ],
      ],
    );
  }
}

class _ReaderFontWeightOption extends StatelessWidget {
  const _ReaderFontWeightOption({
    required this.weight,
    required this.selected,
    required this.onTap,
    required this.colorScheme,
  });

  final ReaderFontWeightOption weight;
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
          padding: EdgeInsets.symmetric(vertical: 8.h),
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
          alignment: Alignment.center,
          child: Text(
            weight.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: weight.weight,
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
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

  static TextStyle? _titleStyle(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 44.w,
                child: Text(title, style: _titleStyle(context)),
              ),
              SizedBox(width: 8.w),
              Expanded(child: control),
            ],
          ),
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
            color: enabled ? colorScheme.onSurface : colorScheme.onSurface.withValues(alpha: 0.35),
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

class ReaderSettingsFab extends StatefulWidget {
  const ReaderSettingsFab({
    super.key,
    required this.settingsActive,
    required this.onToggleSettings,
  });

  final bool settingsActive;
  final VoidCallback onToggleSettings;

  @override
  State<ReaderSettingsFab> createState() => _ReaderSettingsFabState();
}

class _ReaderSettingsFabState extends State<ReaderSettingsFab> {
  bool _hovering = false;

  bool get _visible => _hovering || widget.settingsActive;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.w, 24.h, 24.w, 12.h),
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: IgnorePointer(
            ignoring: !_visible,
            child: _CornerFab(
              active: widget.settingsActive,
              icon: Icons.text_fields_outlined,
              tooltip: '阅读设置',
              onPressed: widget.onToggleSettings,
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerFab extends StatelessWidget {
  const _CornerFab({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        elevation: 2,
        shadowColor: Colors.black26,
        color: active ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 34.w,
            height: 34.w,
            child: Icon(
              icon,
              size: 18.sp,
              color: active ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
