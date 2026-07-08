import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../models/app_settings.dart';
import '../../providers/app_providers.dart';
import 'reader_panels.dart';

class ReaderQuickSettingsPanel extends ConsumerWidget {
  const ReaderQuickSettingsPanel({
    super.key,
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 8,
      shadowColor: Colors.black26,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.98),
      borderRadius: BorderRadius.circular(12.r),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 8.w, 0),
            child: Row(
              children: [
                Text('阅读设置', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.close, size: 18.sp),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('阅读背景', style: Theme.of(context).textTheme.labelMedium),
                  SizedBox(height: 6.h),
                  SegmentedButton<ReaderThemeMode>(
                    segments: ReaderThemeMode.values
                        .map(
                          (mode) => ButtonSegment(
                            value: mode,
                            label: Text(mode.label),
                            icon: CircleAvatar(
                              radius: 6,
                              backgroundColor: mode.previewColor,
                            ),
                          ),
                        )
                        .toList(),
                    selected: {settings.themeMode},
                    onSelectionChanged: (value) {
                      ref.read(appSettingsProvider.notifier).update(
                            settings.copyWith(themeMode: value.first),
                          );
                    },
                  ),
                  SizedBox(height: 10.h),
                  Text('字号', style: Theme.of(context).textTheme.labelMedium),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: settings.fontSize,
                          min: 12,
                          max: 28,
                          divisions: 16,
                          label: settings.fontSize.toStringAsFixed(0),
                          onChanged: (value) {
                            ref.read(appSettingsProvider.notifier).update(
                                  settings.copyWith(fontSize: value),
                                );
                          },
                        ),
                      ),
                      SizedBox(
                        width: 36.w,
                        child: Text(
                          settings.fontSize.toStringAsFixed(0),
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Text('行高', style: Theme.of(context).textTheme.labelMedium),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: settings.lineHeight,
                          min: 1.2,
                          max: 2.0,
                          divisions: 8,
                          label: settings.lineHeight.toStringAsFixed(1),
                          onChanged: (value) {
                            ref.read(appSettingsProvider.notifier).update(
                                  settings.copyWith(lineHeight: value),
                                );
                          },
                        ),
                      ),
                      SizedBox(
                        width: 36.w,
                        child: Text(
                          settings.lineHeight.toStringAsFixed(1),
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Text('字重', style: Theme.of(context).textTheme.labelMedium),
                  SizedBox(height: 6.h),
                  SegmentedButton<ReaderFontWeightOption>(
                    segments: ReaderFontWeightOption.values
                        .map(
                          (weight) => ButtonSegment(
                            value: weight,
                            label: Text(weight.label),
                          ),
                        )
                        .toList(),
                    selected: {settings.fontWeight},
                    onSelectionChanged: (value) {
                      ref.read(appSettingsProvider.notifier).update(
                            settings.copyWith(fontWeight: value.first),
                          );
                    },
                  ),
                  SizedBox(height: 10.h),
                  Text('左右边距', style: Theme.of(context).textTheme.labelMedium),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: settings.readerContentWidthPercent,
                          min: 0.55,
                          max: 1.0,
                          divisions: 18,
                          label:
                              '${(settings.readerContentWidthPercent * 100).round()}%',
                          onChanged: (value) {
                            ref.read(appSettingsProvider.notifier).update(
                                  settings.copyWith(
                                    readerContentWidthPercent: value,
                                  ),
                                );
                          },
                        ),
                      ),
                      SizedBox(
                        width: 40.w,
                        child: Text(
                          '${(settings.readerContentWidthPercent * 100).round()}%',
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '数值越小，左右留白越多',
                    style: Theme.of(context).textTheme.bodySmall,
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

class ReaderCornerControls extends StatefulWidget {
  const ReaderCornerControls({
    super.key,
    required this.progress,
    required this.settingsActive,
    required this.onToggleSettings,
  });

  final double progress;
  final bool settingsActive;
  final VoidCallback onToggleSettings;

  @override
  State<ReaderCornerControls> createState() => _ReaderCornerControlsState();
}

class _ReaderCornerControlsState extends State<ReaderCornerControls> {
  bool _hovering = false;

  bool get _visible => _hovering || widget.settingsActive;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24.w, 24.h, 12.w, 12.h),
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: IgnorePointer(
            ignoring: !_visible,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _CornerFab(
                  active: widget.settingsActive,
                  icon: Icons.text_fields_outlined,
                  tooltip: '',
                  onPressed: widget.onToggleSettings,
                ),
                SizedBox(height: 8.h),
                _CornerFab(
                  icon: null,
                  tooltip: '',
                  onPressed: null,
                  child: ReaderProgressIndicator(progress: widget.progress),
                ),
              ],
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
    this.child,
  });

  final IconData? icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        elevation: 2,
        shadowColor: Colors.black26,
        color: active
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 34.w,
            height: 34.w,
            child: child ??
                Icon(
                  icon,
                  size: 18.sp,
                  color: active
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                ),
          ),
        ),
      ),
    );
  }
}
