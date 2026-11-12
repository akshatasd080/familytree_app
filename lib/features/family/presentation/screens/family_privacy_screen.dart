import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/ft_page.dart';
import '../../../../core/widgets/responsive.dart';

/// Matches web `/family/privacy` placeholder.
class FamilyPrivacyScreen extends StatelessWidget {
  const FamilyPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FtPage(
      title: 'Privacy Preferences',
      body: ResponsiveBody(
        child: Text(
          'This section is available in the app shell and ready for future features.',
          style: AppTheme.body(color: AppTheme.muted),
        ),
      ),
    );
  }
}
