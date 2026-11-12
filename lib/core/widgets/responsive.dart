import 'package:flutter/material.dart';

class Breakpoints {
  static const double phone = 480;
  static const double tablet = 840;
}

extension ResponsiveContext on BuildContext {
  Size get screen => MediaQuery.sizeOf(this);
  double get width => screen.width;
  bool get isPhone => width < Breakpoints.phone;
  bool get isTablet => width >= Breakpoints.phone && width < Breakpoints.tablet;
  bool get isWide => width >= Breakpoints.tablet;

  EdgeInsets get pagePadding => EdgeInsets.symmetric(
        horizontal: isWide ? 28 : (isTablet ? 20 : 16),
        vertical: 12,
      );

  int gridCount({int phone = 1, int tablet = 2, int wide = 3}) {
    if (isWide) return wide;
    if (isTablet) return tablet;
    return phone;
  }

  double get contentMaxWidth => isWide ? 1100 : (isTablet ? 720 : width);
}

/// Centers content and caps width on large screens.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
        child: Padding(
          padding: padding ?? context.pagePadding,
          child: child,
        ),
      ),
    );
  }
}
