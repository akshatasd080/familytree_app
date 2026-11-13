import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/ft_page.dart';
import '../../../../core/widgets/responsive.dart';

/// Matches web `/family/privacy` placeholder (`FamilyPlaceholder`).
class FamilyPrivacyScreen extends StatelessWidget {
  const FamilyPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FtPage(
      title: 'Privacy Preferences',
      body: ResponsiveBody(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Privacy Preferences', style: AppTheme.display(size: 22)),
              const SizedBox(height: 8),
              Text(
                'This section is available in the app shell and ready for future features.',
                style: AppTheme.body(color: AppTheme.muted, size: 14),
              ),
              const SizedBox(height: 16),
              Text(
                'Coming soon: visibility controls for profile, tree, and media sharing within your family.',
                style: AppTheme.body(size: 13, color: AppTheme.mutedSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
