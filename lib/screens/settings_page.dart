import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/app_settings.dart';
import '../providers/app_providers.dart';
import '../utils/import_books.dart';
import '../utils/pick_home_background.dart';
import '../widgets/home_background.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key, this.showHeader = true});

  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return ListView(
      padding: EdgeInsets.fromLTRB(24.w, showHeader ? 24.h : 8.h, 24.w, 24.h),
      children: [
        if (showHeader) ...[
          Text('设置', style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: 20.h),
        ],
        const _SectionTitle(title: '书架'),
        Padding(
          padding: EdgeInsets.only(bottom: 16.h),
          child: FilledButton.icon(
            onPressed: () => importBooksFromPicker(ref),
            icon: const Icon(Icons.upload_file),
            label: const Text('导入电子书'),
          ),
        ),
        _HomeBackgroundSection(settings: settings),
        const _SectionTitle(title: '界面主题'),
        Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: SegmentedButton<AppThemeMode>(
            segments: AppThemeMode.values
                .map(
                  (mode) => ButtonSegment(
                    value: mode,
                    label: Text(mode.label),
                  ),
                )
                .toList(),
            selected: {settings.appThemeMode},
            onSelectionChanged: (value) {
              ref.read(appSettingsProvider.notifier).update(
                    settings.copyWith(appThemeMode: value.first),
                  );
            },
          ),
        ),
        SwitchListTile(
          title: const Text('阅读时显示目录栏'),
          value: settings.showTocPanel,
          onChanged: (value) {
            ref.read(appSettingsProvider.notifier).update(
                  settings.copyWith(showTocPanel: value),
                );
          },
        ),
      ],
    );
  }
}

void showSettingsDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final screenHeight = MediaQuery.sizeOf(dialogContext).height;

      return Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: SizedBox(
          width: 480.w,
          height: screenHeight * 0.88,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 8.w, 8.h),
              child: Row(
                children: [
                  Text('设置', style: Theme.of(dialogContext).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const Expanded(
              child: SettingsPage(showHeader: false),
            ),
          ],
        ),
      ),
    );
    },
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(title, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

class _HomeBackgroundSection extends ConsumerWidget {
  const _HomeBackgroundSection({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backgroundPath = settings.homeBackgroundPath;
    final hasBackground =
        backgroundPath != null && File(backgroundPath).existsSync();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(title: '首页背景'),
        if (hasBackground)
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: HomeBackgroundPreview(
                  backgroundPath: backgroundPath,
                  backgroundOpacity: settings.homeBackgroundOpacity,
                ),
              ),
            ),
          ),
        if (hasBackground)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('背景透明度'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Slider(
                  value: 1 - settings.homeBackgroundOpacity,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  label:
                      '${((1 - settings.homeBackgroundOpacity) * 100).round()}%',
                  onChanged: (value) {
                    ref.read(appSettingsProvider.notifier).update(
                          settings.copyWith(
                            homeBackgroundOpacity: 1 - value,
                          ),
                        );
                  },
                ),
                Text(
                  '数值越高背景越淡，文字越易阅读',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            trailing: Text(
              '${((1 - settings.homeBackgroundOpacity) * 100).round()}%',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => pickHomeBackground(ref),
                icon: const Icon(Icons.image_outlined),
                label: Text(hasBackground ? '更换背景图' : '选择背景图'),
              ),
            ),
            if (hasBackground) ...[
              SizedBox(width: 8.w),
              IconButton(
                tooltip: '清除背景图',
                onPressed: () => clearHomeBackground(ref),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ],
        ),
        SizedBox(height: 16.h),
      ],
    );
  }
}
