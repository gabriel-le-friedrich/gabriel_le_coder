import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_design_system.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_hero.dart';
import '../widgets/auth_widgets.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _emailFocus = FocusNode();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authFlowControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });
    final state = ref.watch(authFlowControllerProvider);
    final lang = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: AppColors.authBackground,
      body: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthHeroScene(compact: true, showBackButton: true),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AuthCard(
                  child: state.forgotEmailSent
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                color: AppColors.accentLime,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const ExcludeSemantics(
                                child: Icon(Icons.mark_email_read_outlined,
                                    size: 36, color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                tr(lang, 'resetLinkSent'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 15, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(tr(lang, 'resetPasswordTitle'),
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 8),
                            Text(tr(lang, 'resetPasswordInstructions'),
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary)),
                            const SizedBox(height: 18),
                            AuthTextField(
                              controller: _emailCtrl,
                              focusNode: _emailFocus,
                              label: tr(lang, 'email'),
                              icon: Icons.mail_outline,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => ref
                                  .read(authFlowControllerProvider.notifier)
                                  .submitForgotPassword(_emailCtrl.text.trim()),
                            ),
                            const SizedBox(height: 18),
                            AuthGradientButton(
                              label: tr(lang, 'sendResetLink'),
                              loading: state.isLoading,
                              loadingLabel: tr(lang, 'loading'),
                              icon: null,
                              onPressed: () => ref
                                  .read(authFlowControllerProvider.notifier)
                                  .submitForgotPassword(_emailCtrl.text.trim()),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
