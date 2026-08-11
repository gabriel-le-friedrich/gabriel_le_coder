import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../shared/theme/app_design_system.dart';
import '../../../../shared/widgets/asf_logo.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../widgets/auth_hero.dart';
import '../widgets/auth_widgets.dart';

/// App entry / landing screen — redesigned per the 2026 "premium farm
/// hero" mockup: full illustrated hero with no text overlay, a circular
/// pig avatar bridging the hero and the floating card below, then
/// branding, a 3-icon feature row, and the Create Account / Log In /
/// Mobile OTP / Forgot Password actions. Every navigation call below
/// (context.push to register/login/forgotPassword) is unchanged from the
/// previous plain version of this screen — only the visuals changed, plus
/// one new entry point ("Continue with Mobile OTP") that pushes to the
/// existing LoginScreen with startOnPhoneStep: true instead of duplicating
/// any OTP logic here.
const double _kHeroHeight = 340;
const double _kAvatarSize = 88;
const double _kAvatarOverlap = 44;

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: AppColors.authBackground,
      body: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthHeroScene(
                    compact: false,
                    showBackButton: false,
                    showBranding: false,
                  ),
                  const SizedBox(height: _kAvatarOverlap),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: AuthCard(
                      margin: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('ASF',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.darkGreen,
                                  height: 1.0)),
                          const SizedBox(height: 6),
                          Text(tr(lang, 'appTagline'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.eco_rounded,
                                  size: 14, color: AppColors.accentLime),
                              const SizedBox(width: 6),
                              Text(tr(lang, 'appMotto'),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryGreen)),
                              const SizedBox(width: 6),
                              const Icon(Icons.eco_rounded,
                                  size: 14, color: AppColors.accentLime),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: _FeatureItem(
                                  icon: Icons.calendar_month_rounded,
                                  label: tr(lang, 'welcomeFeatureTasks'),
                                ),
                              ),
                              Expanded(
                                child: _FeatureItem(
                                  icon: Icons.favorite_border_rounded,
                                  label: tr(lang, 'welcomeFeatureHealth'),
                                ),
                              ),
                              Expanded(
                                child: _FeatureItem(
                                  icon: Icons.trending_up_rounded,
                                  label: tr(lang, 'welcomeFeaturePerformance'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 26),
                          AuthGradientButton(
                            label: tr(lang, 'createAccount'),
                            onPressed: () => context.push(AppRoutes.register),
                          ),
                          const SizedBox(height: 12),
                          AuthOutlinedButton(
                            label: tr(lang, 'logIn'),
                            icon: Icons.lock_outline_rounded,
                            onPressed: () => context.push(AppRoutes.login),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              const Expanded(
                                  child: Divider(color: Color(0xFFE5E7EB))),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(tr(lang, 'orDivider'),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary)),
                              ),
                              const Expanded(
                                  child: Divider(color: Color(0xFFE5E7EB))),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _MobileOtpEntryButton(
                            label: tr(lang, 'continueWithMobileOtp'),
                            onPressed: () =>
                                context.push(AppRoutes.login, extra: true),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Semantics(
                              button: true,
                              label: tr(lang, 'forgotPassword'),
                              child: InkWell(
                                onTap: () =>
                                    context.push(AppRoutes.forgotPassword),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.lock_outline_rounded,
                                        size: 15, color: AppColors.darkGreen),
                                    const SizedBox(width: 6),
                                    Text(tr(lang, 'forgotPassword'),
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.darkGreen)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shield_outlined,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(tr(lang, 'welcomeSecurityFooter'),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(width: 6),
                      const Icon(Icons.eco_outlined,
                          size: 14, color: AppColors.accentLime),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
              const Positioned(
                top: _kHeroHeight - _kAvatarOverlap,
                child: _WelcomeAvatar(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeAvatar extends StatelessWidget {
  const _WelcomeAvatar();

  @override
  Widget build(BuildContext context) {
    return const AsfLogo(
      size: _kAvatarSize,
      borderRadius: 22,
      showShadow: true,
      showBorder: true,
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.accentLime.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 22, color: AppColors.darkGreen),
        ),
        const SizedBox(height: 8),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.2)),
      ],
    );
  }
}

/// The tinted "Continue with Mobile OTP" action — visually distinct from
/// [AuthOutlinedButton] (filled with a soft green tint rather than just a
/// border) to match the mockup, but the same 56dp/18px-radius button
/// family as the rest of the auth screens.
class _MobileOtpEntryButton extends StatelessWidget {
  const _MobileOtpEntryButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.accentLime.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.smartphone_outlined,
                    size: 20, color: AppColors.darkGreen),
                const SizedBox(width: 10),
                Text(label,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGreen)),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_rounded,
                    size: 18, color: AppColors.darkGreen),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
