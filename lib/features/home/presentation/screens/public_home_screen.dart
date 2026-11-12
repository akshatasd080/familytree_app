import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/ft_widgets.dart';

class PublicHomeScreen extends StatelessWidget {
  const PublicHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW =
                constraints.maxWidth > 720 ? 640.0 : constraints.maxWidth;
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: maxW,
                child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Row(
              children: [
                const FtBrandMark(size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Family Tree',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.display(size: 18),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(
                    'Sign in',
                    style: AppTheme.body(
                      weight: FontWeight.w700,
                      color: AppTheme.forest,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: AspectRatio(
                aspectRatio: 16 / 11,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/hero-family-colored.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTheme.cream,
                        child: const Icon(Icons.park,
                            size: 72, color: AppTheme.forest),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.55),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your family,\none living tree.',
                            style: AppTheme.display(
                              size: 28,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Register, invite relatives, explore generations, share photos & events.',
                            style: AppTheme.body(
                              size: 13,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go('/family/register'),
              child: const Text('Create your family'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => context.go('/login'),
              child: const Text('Find my family / Sign in'),
            ),
            const SizedBox(height: 28),
            Text('Everything your family needs',
                style: AppTheme.display(size: 22)),
            const SizedBox(height: 12),
            ...const [
              _Feature(
                Icons.account_tree,
                'Interactive family tree',
                'See generations and explore each member’s branch.',
              ),
              _Feature(
                Icons.groups,
                'Members & invites',
                'Add relatives with OTP and approve join requests.',
              ),
              _Feature(
                Icons.photo_library,
                'Media & memories',
                'Share photos, like, comment — a private family feed.',
              ),
              _Feature(
                Icons.map_outlined,
                'Family map',
                'Pin where everyone lives with quick search.',
              ),
              _Feature(
                Icons.event,
                'Events & birthdays',
                'Never miss a celebration across the tree.',
              ),
              _Feature(
                Icons.shield_outlined,
                'Private & secure',
                'OTP verification and admin-approved joins.',
              ),
            ],
          ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.title, this.desc);

  final IconData icon;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FtSectionCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.emerald100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.forest, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.body(weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(desc, style: AppTheme.body(size: 12, color: AppTheme.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
