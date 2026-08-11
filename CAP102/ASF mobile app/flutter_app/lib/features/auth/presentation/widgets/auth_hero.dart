import 'package:flutter/material.dart';

import '../../../../shared/theme/app_design_system.dart';
import '../../../../shared/widgets/asf_logo.dart';

// ══════════════════════════════════════════════════════════════════════
// Shared illustrated "farm at sunrise" hero used across every auth screen
// (Login, Register, Forgot Password, Verify OTP) per the 2026 premium
// redesign spec. Everything here is drawn with plain Flutter primitives —
// gradients, CustomPainter shapes, and the same pig emoji already used in
// boot_loading_shell.dart — deliberately no external image asset, so the
// scene renders identically offline and needs no bundled artwork. This
// file is presentation-only: it takes no providers and fires no callbacks,
// so it can be dropped into any screen without touching auth logic.
// ══════════════════════════════════════════════════════════════════════

/// The illustrated scene: gradient sunrise sky, rolling hills, a small
/// treeline, drifting clouds, corner leaves, and a bobbing pig mascot.
/// [compact] renders a shorter version (used on Register/Forgot Password/
/// OTP, which need more vertical room for form content) with the pig
/// mascot and hill detail simplified but the same palette and branding.
class AuthHeroScene extends StatefulWidget {
  const AuthHeroScene({
    super.key,
    this.compact = false,
    this.showBackButton = false,
    this.showBranding = true,
  });

  final bool compact;
  final bool showBackButton;

  /// When false, the ASF title/subtitle block is omitted entirely so the
  /// illustration can stand alone — used on the Welcome screen, which
  /// places its own centered branding (with an overlapping avatar) below
  /// the hero instead of overlaid on top of it.
  final bool showBranding;

  @override
  State<AuthHeroScene> createState() => _AuthHeroSceneState();
}

class _AuthHeroSceneState extends State<AuthHeroScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.compact ? 210.0 : 340.0;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          // Sunrise sky gradient.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFDCEEF5),
                  Color(0xFFEFF3D8),
                  Color(0xFFFBEFC9),
                ],
              ),
            ),
          ),
          // Soft glowing sun near the horizon.
          Positioned(
            right: 48,
            top: widget.compact ? 30 : 70,
            child: AnimatedBuilder(
              animation: _floatController,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, _floatController.value * -4),
                child: child,
              ),
              child: Container(
                width: widget.compact ? 60 : 84,
                height: widget.compact ? 60 : 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.highlightGold.withValues(alpha: 0.55),
                    AppColors.highlightGold.withValues(alpha: 0.0),
                  ]),
                ),
              ),
            ),
          ),
          // Drifting clouds.
          Positioned(
            left: 24,
            top: widget.compact ? 20 : 36,
            child: AnimatedBuilder(
              animation: _floatController,
              builder: (context, child) => Transform.translate(
                offset: Offset(_floatController.value * 10, 0),
                child: child,
              ),
              child: const _Cloud(scale: 0.85),
            ),
          ),
          Positioned(
            left: 120,
            top: widget.compact ? 8 : 16,
            child: AnimatedBuilder(
              animation: _floatController,
              builder: (context, child) => Transform.translate(
                offset: Offset(-_floatController.value * 8, 0),
                child: child,
              ),
              child: const _Cloud(scale: 0.55),
            ),
          ),
          // Rolling hills + treeline, painted at the base of the scene.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: widget.compact ? 110 : 160,
            child: CustomPaint(
              painter: _HillsPainter(),
              child: const SizedBox.expand(),
            ),
          ),
          // Corner leaf decoration.
          Positioned(
            left: -6,
            top: -6,
            child: Icon(Icons.eco_rounded,
                size: widget.compact ? 34 : 46,
                color: AppColors.accentLime.withValues(alpha: 0.55)),
          ),
          // Branding block.
          if (widget.showBranding)
            Positioned(
              left: 24,
              right: widget.compact ? 100 : 140,
              top: widget.compact ? 44 : 56,
              child: _Branding(compact: widget.compact),
            ),
          // Pig mascot, gently bobbing.
          Positioned(
            right: 20,
            bottom: widget.compact ? 8 : 30,
            child: AnimatedBuilder(
              animation: _floatController,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, _floatController.value * -6),
                child: child,
              ),
              child: _PigMascot(size: widget.compact ? 76 : 108),
            ),
          ),
          if (widget.showBackButton)
            Positioned(
              left: 8,
              top: 8,
              child: SafeArea(
                bottom: false,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.7),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: AppColors.textPrimary),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Branding extends StatelessWidget {
  const _Branding({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('ASF',
            style: TextStyle(
              fontSize: compact ? 26 : 34,
              fontWeight: FontWeight.w800,
              color: AppColors.darkGreen,
              height: 1.0,
            )),
        if (!compact) ...[
          const SizedBox(height: 4),
          const Text(
            'Administration for\nSwine Finisher',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),
        ],
      ],
    );
  }
}

class _PigMascot extends StatelessWidget {
  const _PigMascot({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.55),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text('🐷', style: TextStyle(fontSize: size * 0.62)),
    );
  }
}

class _Cloud extends StatelessWidget {
  const _Cloud({required this.scale});
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.75,
      child: Transform.scale(
        scale: scale,
        child: SizedBox(
          width: 64,
          height: 28,
          child: Stack(
            children: [
              Positioned(left: 0, top: 8, child: _puff(26)),
              Positioned(left: 16, top: 0, child: _puff(34)),
              Positioned(left: 40, top: 10, child: _puff(24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _puff(double d) => Container(
        width: d,
        height: d,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      );
}

/// Rolling hills + a small treeline, painted once (no per-frame rebuilds —
/// the containing widget is what animates, not this painter).
class _HillsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Back hill — lighter green.
    final back = Path()
      ..moveTo(0, h * 0.55)
      ..quadraticBezierTo(w * 0.22, h * 0.32, w * 0.48, h * 0.5)
      ..quadraticBezierTo(w * 0.75, h * 0.68, w, h * 0.4)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
        back, Paint()..color = AppColors.accentLime.withValues(alpha: 0.55));

    // Front hill — darker green, sits lower/closer.
    final front = Path()
      ..moveTo(0, h * 0.78)
      ..quadraticBezierTo(w * 0.25, h * 0.55, w * 0.55, h * 0.75)
      ..quadraticBezierTo(w * 0.8, h * 0.92, w, h * 0.7)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
        front, Paint()..color = AppColors.primaryGreen.withValues(alpha: 0.85));

    // A few simple tree silhouettes on the front hill.
    _tree(canvas, Offset(w * 0.14, h * 0.66), 16);
    _tree(canvas, Offset(w * 0.22, h * 0.72), 12);
    _tree(canvas, Offset(w * 0.88, h * 0.6), 14);
  }

  void _tree(Canvas canvas, Offset base, double size) {
    final trunkPaint = Paint()..color = const Color(0xFF6D4C2A);
    final leafPaint = Paint()..color = AppColors.darkGreen;
    canvas.drawRect(
      Rect.fromCenter(
          center: base.translate(0, size * 0.35),
          width: size * 0.18,
          height: size * 0.5),
      trunkPaint,
    );
    canvas.drawCircle(base.translate(0, -size * 0.1), size * 0.5, leafPaint);
  }

  @override
  bool shouldRepaint(covariant _HillsPainter oldDelegate) => false;
}
