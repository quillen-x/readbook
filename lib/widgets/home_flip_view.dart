import 'dart:math' show pi;

import 'package:flutter/material.dart';

class HomeFlipView extends StatelessWidget {
  const HomeFlipView({
    super.key,
    required this.showDownloads,
    required this.books,
    required this.downloads,
  });

  final bool showDownloads;
  final Widget books;
  final Widget downloads;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (child, animation) {
        final rotate = Tween<double>(begin: pi / 2, end: 0).animate(animation);
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(rotate.value),
              alignment: Alignment.center,
              child: child,
            );
          },
          child: child,
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: showDownloads
          ? KeyedSubtree(
              key: const ValueKey('downloads'),
              child: downloads,
            )
          : KeyedSubtree(
              key: const ValueKey('books'),
              child: books,
            ),
    );
  }
}
