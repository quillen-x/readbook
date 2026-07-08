import 'dart:io';

import 'package:flutter/material.dart';

class HomeBackground extends StatelessWidget {
  const HomeBackground({
    super.key,
    required this.backgroundPath,
    required this.backgroundOpacity,
    required this.child,
  });

  final String? backgroundPath;
  final double backgroundOpacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final path = backgroundPath;
    if (path == null || !File(path).existsSync()) {
      return child;
    }

    final overlayColor = Theme.of(context).colorScheme.surface;
    final overlayAlpha = (1.0 - backgroundOpacity.clamp(0.0, 1.0)) * 0.95;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: _HomeBackgroundImage(path: path),
        ),
        if (overlayAlpha > 0)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: overlayColor.withValues(alpha: overlayAlpha),
              ),
            ),
          ),
        child,
      ],
    );
  }
}

class _HomeBackgroundImage extends StatelessWidget {
  const _HomeBackgroundImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: Align(
            alignment: Alignment.center,
            child: Image.file(
              File(path),
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.medium,
            ),
          ),
        );
      },
    );
  }
}

/// 设置页预览用，叠加上下文遮罩以模拟首页效果。
class HomeBackgroundPreview extends StatelessWidget {
  const HomeBackgroundPreview({
    super.key,
    required this.backgroundPath,
    required this.backgroundOpacity,
  });

  final String backgroundPath;
  final double backgroundOpacity;

  @override
  Widget build(BuildContext context) {
    return HomeBackground(
      backgroundPath: backgroundPath,
      backgroundOpacity: backgroundOpacity,
      child: const SizedBox.expand(),
    );
  }
}
