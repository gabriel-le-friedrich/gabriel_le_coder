import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../shared/theme/app_design_system.dart';
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_hero.dart';
import '../widgets/auth_widgets.dart';

/// Login — redesigned per the 2026 "premium farm hero" spec: illustrated
/// sunrise hero, floating white card, gradient primary button. Email +
/// Password are shown together on one view (no more Email/Mobile-OTP
/// tabs); "Continue with Mobile OTP" swaps the card's content in place to
/// the phone-number step instead of navigating to a separate screen, so
/// the OTP-sent navigation (`context.push(AppRoutes.verifyOtp)`) and every
/// AuthFlowController call below are the exact same calls the old tabbed
/// screen made — only the surrounding widget tree changed.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.startOnPhoneStep = false});

  /// True when navigated here via the Welcome screen's "Continue with
  /// Mobile OTP" button — opens straight on the phone-number step instead
  /// of the default email/password step. Purely an initial-UI-state flag;
  /// every call this screen makes into AuthFlowController is unchanged
  /// regardless of which step it starts on.
  final bool startOnPhoneStep;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _mobileFocus = FocusNode();
  bool _obscurePassword = true;
  bool _remember = true;
  bool _navigatedToOtp = false;
  late bool _showPhoneStep = widget.startOnPhoneStep;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _mobileCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _mobileFocus.dispose();
    super.dispose();
  }

  String _greetingKey() {
    final h = DateTime.now().hour;
    if (h < 12) return 'goodMorning';
    if (h < 17) return 'goodAfternoon';
    return 'goodEvening';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authFlowControllerProvider, (previous, next) {
      if (next.step == AuthFlowStep.otpSent &&
          next.verifyMode == VerifyMode.login &&
          !_navigatedToOtp) {
        _navigatedToOtp = true;
        context.push(AppRoutes.verifyOtp);
      }
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeroScene(),
            Transform.translate(
              offset: const Offset(0, -28),
              child: AuthCard(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: _showPhoneStep
                      ? _PhoneStep(
                          key: const ValueKey('phone'),
                          mobileCtrl: _mobileCtrl,
                          mobileFocus: _mobileFocus,
                          isLoading: state.isLoading,
                          lang: lang,
                          onBack: () => setState(() => _showPhoneStep = false),
                          onSend: () => ref
                              .read(authFlowControllerProvider.notifier)
                              .submitLoginPhone(_mobileCtrl.text.trim()),
                        )
                      : _EmailStep(
                          key: const ValueKey('email'),
                          emailCtrl: _emailCtrl,
                          passwordCtrl: _passwordCtrl,
                          emailFocus: _emailFocus,
                          passwordFocus: _passwordFocus,
                          obscurePassword: _obscurePassword,
                          remember: _remember,
                          isLoading: state.isLoading,
                          lang: lang,
                          greetingKey: _greetingKey(),
                          onToggleObscure: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                          onToggleRemember: (v) =>
                              setState(() => _remember = v ?? true),
                          onLogIn: () => ref
                              .read(authFlowControllerProvider.notifier)
                              .submitLoginEmail(
                                email: _emailCtrl.text.trim(),
                                password: _passwordCtrl.text,
                                remember: _remember,
                              ),
                          onForgotPassword: () =>
                              context.push(AppRoutes.forgotPassword),
                          onContinueWithOtp: () =>
                              setState(() => _showPhoneStep = true),
                        ),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -12),
              child: _NewFarmerCard(lang: lang),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _EmailStep extends StatelessWidget {
  const _EmailStep({
    super.key,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.emailFocus,
    required this.passwordFocus,
    required this.obscurePassword,
    required this.remember,
    required this.isLoading,
    required this.lang,
    required this.greetingKey,
    required this.onToggleObscure,
    required this.onToggleRemember,
    required this.onLogIn,
    required this.onForgotPassword,
    required this.onContinueWithOtp,
  });

  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;
  final bool obscurePassword;
  final bool remember;
  final bool isLoading;
  final AppLanguage lang;
  final String greetingKey;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool?> onToggleRemember;
  final VoidCallback onLogIn;
  final VoidCallback onForgotPassword;
  final VoidCallback onContinueWithOtp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${tr(lang, greetingKey)} 👋',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryGreen)),
        const SizedBox(height: 4),
        Text(tr(lang, 'welcomeBackTitle'),
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text(tr(lang, 'welcomeBackLoginSubtitle'),
            style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary, height: 1.35)),
        const SizedBox(height: 24),
        AuthTextField(
          controller: emailCtrl,
          focusNode: emailFocus,
          label: tr(lang, 'email'),
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) =>
              FocusScope.of(context).requestFocus(passwordFocus),
        ),
        const SizedBox(height: 14),
        AuthTextField(
          controller: passwordCtrl,
          focusNode: passwordFocus,
          label: tr(lang, 'password'),
          icon: Icons.lock_outline_rounded,
          obscureText: obscurePassword,
          textInputAction: TextInputAction.done,
          suffixIcon: IconButton(
            icon: Icon(
                obscurePassword ? Icons.visibility_off : Icons.visibility,
                size: 20),
            tooltip:
                tr(lang, obscurePassword ? 'showPassword' : 'hidePassword'),
            onPressed: onToggleObscure,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: remember,
                    onChanged: onToggleRemember,
                    activeColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(tr(lang, 'rememberMe'),
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
            Semantics(
              button: true,
              label: tr(lang, 'forgotPassword'),
              child: InkWell(
                onTap: onForgotPassword,
                child: Text(tr(lang, 'forgotPassword'),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGreen)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        AuthGradientButton(
          label: tr(lang, 'logIn'),
          loading: isLoading,
          loadingLabel: tr(lang, 'loading'),
          onPressed: onLogIn,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(tr(lang, 'orDivider'),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ),
            const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
          ],
        ),
        const SizedBox(height: 20),
        AuthOutlinedButton(
          label: tr(lang, 'continueWithMobileOtp'),
          onPressed: onContinueWithOtp,
        ),
      ],
    );
  }
}

class _PhoneStep extends StatelessWidget {
  const _PhoneStep({
    super.key,
    required this.mobileCtrl,
    required this.mobileFocus,
    required this.isLoading,
    required this.lang,
    required this.onBack,
    required this.onSend,
  });

  final TextEditingController mobileCtrl;
  final FocusNode mobileFocus;
  final bool isLoading;
  final AppLanguage lang;
  final VoidCallback onBack;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Semantics(
              button: true,
              label: tr(lang, 'backToEmailLogin'),
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.arrow_back_rounded,
                      color: AppColors.textPrimary),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(tr(lang, 'welcomeBackTitle'),
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text(tr(lang, 'mobileOtpTab'),
            style:
                const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        AuthTextField(
          controller: mobileCtrl,
          focusNode: mobileFocus,
          label: tr(lang, 'mobileNumber'),
          hint: '09XX XXX XXXX',
          icon: Icons.smartphone_rounded,
          keyboardType: TextInputType.phone,
          maxLength: 11,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
        ),
        const SizedBox(height: 20),
        AuthGradientButton(
          label: tr(lang, 'sendCode'),
          loading: isLoading,
          loadingLabel: tr(lang, 'loading'),
          icon: Icons.sms_outlined,
          onPressed: onSend,
        ),
      ],
    );
  }
}

class _NewFarmerCard extends StatelessWidget {
  const _NewFarmerCard({required this.lang});
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return AuthCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.authBackground,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('🐖', style: TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(lang, 'newFarmerTitle'),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(tr(lang, 'newFarmerBody'),
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.3)),
                const SizedBox(height: 10),
                Semantics(
                  button: true,
                  label: tr(lang, 'createAccount'),
                  child: InkWell(
                    onTap: () => context.push(AppRoutes.register),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tr(lang, 'createAccount'),
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkGreen)),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right,
                            size: 18, color: AppColors.darkGreen),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
