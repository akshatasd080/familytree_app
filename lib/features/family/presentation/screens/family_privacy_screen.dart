import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/ft_branded_page.dart';
import '../../../../core/widgets/responsive.dart';

/// Matches web `/family/privacy` placeholder — branded shell.
class FamilyPrivacyScreen extends StatelessWidget {
  const FamilyPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FtBrandedPage(
      title: 'Privacy',
      subtitle: 'Control what your family can see',
      body: ResponsiveBody(
        child: FtSoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.forest.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.privacy_tip_outlined,
                  color: AppTheme.forest,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Privacy Preferences',
                style: AppTheme.display(size: 22, color: AppTheme.forestDark),
              ),
              const SizedBox(height: 8),
              Text(
                'This section is ready in the app shell for future controls.',
                style: AppTheme.body(color: AppTheme.muted, size: 14),
              ),
              const SizedBox(height: 14),
              Text(
                'Coming soon: visibility for profile, tree, and media sharing within your family.',
                style: AppTheme.body(size: 13, color: AppTheme.mutedSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
