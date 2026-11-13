import 'package:flutter/material.dart';

import '../../app/theme.dart';

class FtBrandMark extends StatelessWidget {
  const FtBrandMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.forest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.forest.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(Icons.park, color: Colors.white, size: size * 0.5),
    );
  }
}

class FtSectionCard extends StatelessWidget {
  const FtSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? AppTheme.borderSoft),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: AppTheme.isDark ? 0.35 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class FtStatCard extends StatelessWidget {
  const FtStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.sub,
    this.tone = FtStatTone.green,
  });

  final IconData icon;
  final String value;
  final String label;
  final String? sub;
  final FtStatTone tone;

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    final colors = switch (tone) {
      FtStatTone.green => (
          bg: dark ? const Color(0xFF143028) : const Color(0xFFECFDF5),
          border: dark ? const Color(0xFF1F4A3A) : const Color(0xFFD1FAE5),
          iconBg: dark ? const Color(0xFF1F4A3A) : const Color(0xFFD1FAE5),
          icon: const Color(0xFF059669),
        ),
      FtStatTone.purple => (
          bg: dark ? const Color(0xFF241B3A) : const Color(0xFFF5F3FF),
          border: dark ? const Color(0xFF35285A) : const Color(0xFFEDE9FE),
          iconBg: dark ? const Color(0xFF35285A) : const Color(0xFFEDE9FE),
          icon: const Color(0xFF7C3AED),
        ),
      FtStatTone.blue => (
          bg: dark ? const Color(0xFF152636) : const Color(0xFFF0F9FF),
          border: dark ? const Color(0xFF1F3A50) : const Color(0xFFE0F2FE),
          iconBg: dark ? const Color(0xFF1F3A50) : const Color(0xFFE0F2FE),
          icon: const Color(0xFF0284C7),
        ),
      FtStatTone.orange => (
          bg: dark ? const Color(0xFF2A1E14) : const Color(0xFFFFF7ED),
          border: dark ? const Color(0xFF3F2C1C) : const Color(0xFFFFEDD5),
          iconBg: dark ? const Color(0xFF3F2C1C) : const Color(0xFFFFEDD5),
          icon: const Color(0xFFEA580C),
        ),
      FtStatTone.red => (
          bg: dark ? const Color(0xFF2A151A) : const Color(0xFFFFF1F2),
          border: dark ? const Color(0xFF3F2028) : const Color(0xFFFFE4E6),
          iconBg: dark ? const Color(0xFF3F2028) : const Color(0xFFFFE4E6),
          icon: const Color(0xFFE11D48),
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 17, color: colors.icon),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppTheme.display(size: 22)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.body(weight: FontWeight.w600, size: 13),
          ),
          if (sub != null)
            Text(
              sub!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.body(size: 11, color: AppTheme.muted),
            ),
        ],
      ),
    );
  }
}

enum FtStatTone { green, purple, blue, orange, red }

class FtPageHeader extends StatelessWidget {
  const FtPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.display(size: 22)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTheme.body(size: 13, color: AppTheme.muted),
                  ),
              ],
            ),
          ),
          ...?actions,
        ],
      ),
    );
  }
}
