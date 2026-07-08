import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:window_manager/window_manager.dart';

/// 隐藏系统标题栏后，提供窗口拖拽区域并预留 macOS 交通灯按钮空间。
class WindowDragBar extends StatelessWidget {
  const WindowDragBar({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return DragToMoveArea(
      child: Container(
        height: 28.h,
        width: double.infinity,
        color: colorScheme.surfaceContainerLow,
        
      ),
    );
  }
}
