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

/// PH mobile numbers are exactly 11 digits in local format (e.g.
/// 09171234567) — matches what normalizePhilippineMobile() in
/// phone_utils.dart ultimately expects once the leading 0 is stripped and
/// +63 is prefixed, but enforced here field-by-field so the user gets
/// immediate feedback instead of a vague "invalid phone number" after
/// submit.
///
/// `appLanguageProvider` defaults to English until a signed-in user's saved
/// preference loads (see settingsBootstrapProvider) — it isn't reset on
/// logout, so a returning user who set Filipino, then logged out, still
/// sees this screen in Filipino for the rest of the app session. A brand
/// new install always starts in English here, since there's no signed-in
/// account yet to read a language preference from.
String? _validateMobileNumber(AppLanguage lang, String? v) {
  final digits = (v ?? '').trim();
  if (digits.isEmpty) return tr(lang, 'required');
  if (digits.length != 11) return tr(lang, 'enter11Digits');
  if (!digits.startsWith('0')) return tr(lang, 'mobileStartsWith0');
  // Every real PH mobile number has "9" as the second digit (0917, 0920,
  // 0995, ...) — matches normalizePhilippineMobile()'s stricter check in
  // phone_utils.dart, surfaced here so the user sees this rejection
  // immediately on the form instead of only after submitting.
  if (digits.length == 11 && digits[1] != '9') {
    return tr(lang, 'mobileInvalidPrefix');
  }
  return null;
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _municipalityCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _mobileFocus = FocusNode();
  final _municipalityFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _navigatedToOtp = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _municipalityCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _nameFocus.dispose();
    _mobileFocus.dispose();
    _municipalityFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authFlowControllerProvider.notifier).submitRegister(
          name: _nameCtrl.text.trim(),
          mobileRaw: _mobileCtrl.text.trim(),
          municipality: _municipalityCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authFlowControllerProvider, (previous, next) {
      if (next.step == AuthFlowStep.otpSent && !_navigatedToOtp) {
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(tr(lang, 'createAccount'),
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 18),
                        AuthTextField(
                          controller: _nameCtrl,
                          focusNode: _nameFocus,
                          label: tr(lang, 'fullName'),
                          icon: Icons.person_outline,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) =>
                              FocusScope.of(context).requestFocus(_mobileFocus),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? tr(lang, 'required')
                              : null,
                        ),
                        const SizedBox(height: 14),
                        AuthTextField(
                          controller: _mobileCtrl,
                          focusNode: _mobileFocus,
                          label: tr(lang, 'mobileNumber'),
                          hint: '09XX XXX XXXX',
                          icon: Icons.smartphone_outlined,
                          keyboardType: TextInputType.phone,
                          maxLength: 11,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => FocusScope.of(context)
                              .requestFocus(_municipalityFocus),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11)
                          ],
                          validator: (v) => _validateMobileNumber(lang, v),
                        ),
                        const SizedBox(height: 14),
                        AuthTextField(
                          controller: _municipalityCtrl,
                          focusNode: _municipalityFocus,
                          label: tr(lang, 'municipalityProvince'),
                          icon: Icons.location_on_outlined,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) =>
                              FocusScope.of(context).requestFocus(_emailFocus),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? tr(lang, 'required')
                              : null,
                        ),
                        const SizedBox(height: 14),
                        AuthTextField(
                          controller: _emailCtrl,
                          focusNode: _emailFocus,
                          label: tr(lang, 'email'),
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => FocusScope.of(context)
                              .requestFocus(_passwordFocus),
                          validator: (v) => (v == null || !v.contains('@'))
                              ? tr(lang, 'enterValidEmail')
                              : null,
                        ),
                        const SizedBox(height: 14),
                        AuthTextField(
                          controller: _passwordCtrl,
                          focusNode: _passwordFocus,
                          label: tr(lang, 'password'),
                          icon: Icons.lock_outline,
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            tooltip: tr(
                                lang,
                                _obscurePassword
                                    ? 'showPassword'
                                    : 'hidePassword'),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => FocusScope.of(context)
                              .requestFocus(_confirmPasswordFocus),
                          validator: (v) => (v == null || v.length < 6)
                              ? tr(lang, 'atLeast6Chars')
                              : null,
                        ),
                        const SizedBox(height: 14),
                        AuthTextField(
                          controller: _confirmPasswordCtrl,
                          focusNode: _confirmPasswordFocus,
                          label: tr(lang, 'confirmPassword'),
                          icon: Icons.lock_outline,
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            tooltip: tr(
                                lang,
                                _obscureConfirmPassword
                                    ? 'showPassword'
                                    : 'hidePassword'),
                            onPressed: () => setState(() =>
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword),
                          ),
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          validator: (v) => (v != _passwordCtrl.text)
                              ? tr(lang, 'passwordsDoNotMatch')
                              : null,
                        ),
                        const SizedBox(height: 22),
                        AuthGradientButton(
                          label: tr(lang, 'createAccount'),
                          loading: state.isLoading,
                          loadingLabel: tr(lang, 'loading'),
                          onPressed: _submit,
                        ),
                      ],
                    ),
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
