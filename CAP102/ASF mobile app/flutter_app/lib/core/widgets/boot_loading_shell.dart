import 'package:flutter/material.dart';

import '../../shared/theme/app_design_system.dart';
import '../../shared/widgets/asf_logo.dart';

/// Equivalent of the web app's boot-loading-shell — shown while Firebase's
/// auth-state stream, or the onboarding-status lookup that follows it, is
/// still resolving. Pulled into its own file (rather than living inside
/// app.dart or app_router.dart) so both can use it without a circular
/// import between the two.
///
/// Uses a gentle pulse on the app glyph plus the shared brand green spinner
/// so the very first frame the user ever sees already matches the rest of
/// the redesigned app, instead of a bare unstyled spinner.
class BootLoadingShell extends StatefulWidget {
  const BootLoadingShell({super.key});

  @override
  State<BootLoadingShell> createState() => _BootLoadingShellState();
}

class _BootLoadingShellState extends State<BootLoadingShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.06).animate(
                CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
              ),
              child: const AsfLogo(size: 96, borderRadius: 24),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Loading your profile...',
              style: AppTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }
}
