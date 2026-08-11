// ══════════════════════════════════════════════════════════════════════
// Phone OTP entry — 6 individual boxes with autofocus/backspace-to-previous
// navigation, paste support (a full 6-digit paste into any box redistributes
// across all six), OS SMS-autofill hookup (AutofillHints.oneTimeCode, a
// separate OS-level suggestion strip from Firebase's own Android
// auto-verification), a 60s resend cooldown, and auto-submit the instant
// the 6th digit lands. All of this is presentation only — the actual
// verifyPhoneNumber()/PhoneAuthCredential/linkWithCredential/
// signInWithCredential flow lives in auth_repository.dart and
// auth_providers.dart's AuthFlowController, untouched here. This screen
// only ever calls submitVerify(code)/resendOtp() on that existing
// controller — no separate/parallel verification path.
// ══════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_design_system.dart';
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_hero.dart';
import '../widgets/auth_widgets.dart';

const _kOtpLength = 6;
const _kResendCooldown = Duration(seconds: 60);

class VerifyOtpScreen extends ConsumerStatefulWidget {
  const VerifyOtpScreen({super.key});

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(_kOtpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_kOtpLength, (_) => FocusNode());
  Timer? _cooldownTimer;
  int _secondsLeft = _kResendCooldown.inSeconds;
  bool _autoSubmitted = false;
  String? _inlineError;
  // Brief checkmark animation shown the instant verification succeeds,
  // before the success snackbar/navigation take over — purely cosmetic
  // positive feedback (the "Success animation" item from the audit
  // checklist), auto-hides itself so it never blocks the transition to
  // the app shell.
  bool _showSuccessCheck = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes.first.requestFocus();
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _secondsLeft = _kResendCooldown.inSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _clearAndRefocus() {
    for (final c in _controllers) {
      c.clear();
    }
    _autoSubmitted = false;
    if (mounted) _focusNodes.first.requestFocus();
  }

  void _handlePastedDigits(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    for (var i = 0; i < _kOtpLength; i++) {
      _controllers[i].text = i < digits.length ? digits[i] : '';
    }
    if (digits.length >= _kOtpLength) {
      _focusNodes[_kOtpLength - 1].unfocus();
    } else if (digits.isNotEmpty) {
      _focusNodes[digits.length.clamp(0, _kOtpLength - 1)].requestFocus();
    }
    _trySubmit();
  }

  void _onBoxChanged(int index, String value) {
    if (value.length > 1) {
      _handlePastedDigits(value);
      return;
    }
    if (value.isNotEmpty && index < _kOtpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    _trySubmit();
  }

  void _trySubmit() {
    final code = _code;
    if (code.length == _kOtpLength && !_autoSubmitted) {
      _autoSubmitted = true;
      setState(() => _inlineError = null);
      FocusScope.of(context).unfocus();
      ref.read(authFlowControllerProvider.notifier).submitVerify(code);
    }
  }

  Future<void> _handleResend() async {
    if (_secondsLeft > 0) return;
    _clearAndRefocus();
    setState(() => _inlineError = null);
    await ref.read(authFlowControllerProvider.notifier).resendOtp();
    _startCooldown();
  }

  Widget _buildBox(int index, bool hasError) {
    return SizedBox(
      width: 46,
      height: 56,
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace) {
            if (_controllers[index].text.isEmpty && index > 0) {
              _controllers[index - 1].clear();
              _focusNodes[index - 1].requestFocus();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          autofillHints: index == 0 ? const [AutofillHints.oneTimeCode] : null,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            filled: true,
            fillColor: AppColors.authBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                  color: hasError ? AppColors.danger : const Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                  color: hasError ? AppColors.danger : const Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                  color: hasError ? AppColors.danger : AppColors.primaryGreen,
                  width: 2),
            ),
          ),
          onChanged: (v) => _onBoxChanged(index, v),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authFlowControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(next.errorMessage!),
              backgroundColor: AppColors.danger),
        );
        setState(() => _inlineError = next.errorMessage);
        _clearAndRefocus();
      }
      if (next.infoMessage != null &&
          next.infoMessage != previous?.infoMessage) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.infoMessage!)));
      }
      // Success feedback: previous.step was otpSent (this screen was
      // showing a pending verification) and it just cleared to idle with
      // no error — that's _markVerifySucceeded()'s signal that the code
      // was accepted. Navigation itself is NOT this screen's job: the root
      // app.dart's authStateChangesProvider listener drives that (mirrors
      // the web app's authStateChange-driven routing) — this snackbar is
      // purely the "yes, that worked" confirmation the user sees in the
      // moment before the app shell takes over.
      if (previous?.step == AuthFlowStep.otpSent &&
          next.step == AuthFlowStep.idle &&
          next.errorMessage == null) {
        final currentLang = ref.read(appLanguageProvider);
        setState(() => _showSuccessCheck = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(currentLang == AppLanguage.fil
                      ? 'Na-verify na ang numero!'
                      : 'Phone number verified!'),
                ),
              ],
            ),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    });
    final state = ref.watch(authFlowControllerProvider);
    final lang = ref.watch(appLanguageProvider);
    final hasError = _inlineError != null;

    return Scaffold(
      backgroundColor: AppColors.authBackground,
      body: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthHeroScene(compact: true, showBackButton: true),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AuthCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: Container(
                              key: ValueKey(_showSuccessCheck),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Icon(
                                _showSuccessCheck
                                    ? Icons.check_circle
                                    : Icons.sms_outlined,
                                color: AppColors.primaryGreen,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                        Text(tr(lang, 'verifyYourNumber'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        Text(
                          '${tr(lang, 'enterCodeSentTo')} ${state.otpPhoneDisplay ?? tr(lang, 'yourPhone')}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                              _kOtpLength, (i) => _buildBox(i, hasError)),
                        ),
                        if (_inlineError != null) ...[
                          const SizedBox(height: 12),
                          Text(_inlineError!,
                              style: const TextStyle(
                                  color: AppColors.danger, fontSize: 13),
                              textAlign: TextAlign.center),
                        ],
                        const SizedBox(height: 24),
                        AuthGradientButton(
                          label: tr(lang, 'verify'),
                          loading: state.isLoading,
                          loadingLabel: tr(lang, 'loading'),
                          onPressed:
                              state.isLoading || _code.length < _kOtpLength
                                  ? null
                                  : () {
                                      _autoSubmitted = false;
                                      _trySubmit();
                                    },
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: _secondsLeft > 0
                              ? Text(
                                  '${tr(lang, 'resendCodeIn')} ${_secondsLeft}s',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                )
                              : TextButton(
                                  onPressed:
                                      state.isLoading ? null : _handleResend,
                                  child: Text(tr(lang, 'resendCode'),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryGreen)),
                                ),
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
      ),
    );
  }
}
