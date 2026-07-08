import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HoverSettingsFab extends StatefulWidget {
  const HoverSettingsFab({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  State<HoverSettingsFab> createState() => _HoverSettingsFabState();
}

class _HoverSettingsFabState extends State<HoverSettingsFab> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _visible = true),
      onExit: (_) => setState(() => _visible = false),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: IgnorePointer(
            ignoring: !_visible,
            child: Material(
              elevation: 2,
              shadowColor: Colors.black26,
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.onPressed,
                child: SizedBox(
                  width: 40.w,
                  height: 40.w,
                  child: Icon(
                    Icons.settings_outlined,
                    size: 20.sp,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
