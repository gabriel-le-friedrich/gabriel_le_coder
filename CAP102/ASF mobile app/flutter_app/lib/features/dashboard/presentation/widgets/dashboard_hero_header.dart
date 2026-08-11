import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../providers/weather_providers.dart';
import '../theme/dashboard_palette.dart';
import 'dashboard_app_bar_actions.dart';
import 'greeting_header.dart' show dashboardGreetingWord;

// ══════════════════════════════════════════════════════════════════════
// The redesigned Dashboard's illustrated "farm at sunrise" hero — replaces
// the old flat white AppBar with a full-bleed scene (sky gradient, rolling
// hills, a barn, a fence line, drifting clouds, a big friendly pig mascot)
// per the 2026 premium-dashboard mockup. Everything here is drawn with
// plain Flutter primitives (gradients, CustomPainter, emoji) — no bundled
// image asset, matching how the Auth screens' hero was built. This widget
// is presentation-only: the hamburger button still calls
// Scaffold.of(context).openDrawer() (same Drawer, same DashboardDrawer),
// and the right-side controls are the exact existing
// DashboardAppBarActions widget (language pill / notification bell /
// profile avatar) — every one of those taps still goes to the exact same
// route it always has. No provider, repository, or business-logic change.
// ══════════════════════════════════════════════════════════════════════

class DashboardHeroHeader extends StatefulWidget {
  const DashboardHeroHeader({
    super.key,
    required this.uid,
    required this.fullName,
    required this.firstName,
    required this.lang,
    this.onRetryName,
    this.province,
  });

  final String uid;
  final String? fullName;
  final String? firstName;
  final AppLanguage lang;
  final VoidCallback? onRetryName;

  /// The farmer's saved province (from their profile) — used only to look
  /// up current weather for the hero's weather card (see [_WeatherCard]).
  /// Null/empty simply hides that card; nothing else on the hero depends
  /// on it.
  final String? province;

  @override
  State<DashboardHeroHeader> createState() => _DashboardHeroHeaderState();
}

class _DashboardHeroHeaderState extends State<DashboardHeroHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: SizedBox(
        height: widget.province?.trim().isNotEmpty == true ? 306 : 268,
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
                    Color(0xFFE7F1DA),
                    Color(0xFFEFF6E4),
                  ],
                ),
              ),
            ),
            // Soft glowing sun.
            Positioned(
              right: 36,
              top: 18,
              child: AnimatedBuilder(
                animation: _floatController,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _floatController.value * -4),
                  child: child,
                ),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      const Color(0xFFF4B400).withValues(alpha: 0.5),
                      const Color(0xFFF4B400).withValues(alpha: 0.0),
                    ]),
                  ),
                ),
              ),
            ),
            // Weather card — top-right, only rendered when the farmer has a
            // saved province. Purely additive/read-only (see
            // core/services/weather_service.dart); hides itself on any
            // failure or missing province rather than showing an error.
            if (widget.province?.trim().isNotEmpty == true)
              Positioned(
                right: 14,
                top: 58,
                child:
                    _WeatherCard(province: widget.province!, lang: widget.lang),
              ),
            // Drifting clouds.
            Positioned(
              left: 20,
              top: 14,
              child: AnimatedBuilder(
                animation: _floatController,
                builder: (context, child) => Transform.translate(
                  offset: Offset(_floatController.value * 10, 0),
                  child: child,
                ),
                child: const _Cloud(scale: 0.8),
              ),
            ),
            Positioned(
              left: 150,
              top: 4,
              child: AnimatedBuilder(
                animation: _floatController,
                builder: (context, child) => Transform.translate(
                  offset: Offset(-_floatController.value * 8, 0),
                  child: child,
                ),
                child: const _Cloud(scale: 0.5),
              ),
            ),
            // Rolling hills, barn, and fence — painted at the base.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 170,
              child: CustomPaint(
                painter: _FarmScenePainter(),
                child: const SizedBox.expand(),
              ),
            ),
            // Big friendly pig mascot, bottom-right, gently bobbing.
            Positioned(
              right: -6,
              bottom: 6,
              child: AnimatedBuilder(
                animation: _floatController,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _floatController.value * -6),
                  child: child,
                ),
                child: const Text('🐷', style: TextStyle(fontSize: 118)),
              ),
            ),
            // Foreground content: top row + greeting.
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(Icons.menu,
                                color: DashboardPalette.darkGreen),
                            tooltip: tr(widget.lang, 'openMenu'),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                alignment: Alignment.center,
                                child: const Text('🐷',
                                    style: TextStyle(fontSize: 18)),
                              ),
                              const SizedBox(width: 8),
                              const Flexible(
                                child: Text(
                                  'ASF',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: DashboardPalette.darkGreen,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DashboardAppBarActions(
                            uid: widget.uid, fullName: widget.fullName),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  '${dashboardGreetingWord(widget.lang)}, ${widget.firstName ?? tr(widget.lang, 'farmerFallback')} 👋',
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    color: DashboardPalette.darkGreen,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                              if (widget.firstName == null &&
                                  widget.onRetryName != null)
                                Semantics(
                                  button: true,
                                  label:
                                      tr(widget.lang, 'retryLoadingNameLabel'),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: widget.onRetryName,
                                    child: const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Icon(Icons.refresh_rounded,
                                          size: 18,
                                          color: DashboardPalette.textGray),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr(widget.lang, 'dashboardHeroSubtitle'),
                            style: const TextStyle(
                              fontSize: 13,
                              color: DashboardPalette.textGray,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small glass weather card — temperature, condition, humidity, and (when
/// relevant) a heat-alert chip. Watches [weatherProvider] directly via a
/// [Consumer] rather than making the whole hero a ConsumerWidget, so the
/// hero's greeting/hamburger/notification controls never wait on a network
/// call. Renders nothing while loading or on any failure — see
/// core/services/weather_service.dart's WeatherService.fetchForProvince,
/// which already collapses every failure mode to `null`.
class _WeatherCard extends StatelessWidget {
  const _WeatherCard({required this.province, required this.lang});
  final String province;
  final AppLanguage lang;

  IconData _iconFor(String condition) {
    final c = condition.toLowerCase();
    if (c.contains('thunder')) return Icons.thunderstorm_rounded;
    if (c.contains('rain') || c.contains('drizzle')) {
      return Icons.water_drop_rounded;
    }
    if (c.contains('fog')) return Icons.foggy;
    if (c.contains('cloud') && !c.contains('partly')) {
      return Icons.cloud_rounded;
    }
    if (c.contains('partly')) return Icons.wb_cloudy_rounded;
    return Icons.wb_sunny_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final weatherAsync = ref.watch(weatherProvider(province));
        final snapshot = weatherAsync.valueOrNull;
        if (weatherAsync.isLoading || snapshot == null) {
          return const SizedBox.shrink();
        }
        return Container(
          width: 158,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_iconFor(snapshot.conditionLabel),
                      size: 20, color: const Color(0xFFF4B400)),
                  const SizedBox(width: 6),
                  Text('${snapshot.temperatureC.round()}°C',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                ],
              ),
              const SizedBox(height: 2),
              Text(snapshot.conditionLabel,
                  style: const TextStyle(
                      fontSize: 11.5,
                      color: DashboardPalette.textGray,
                      fontWeight: FontWeight.w600)),
              Text('${tr(lang, 'humidityLabel')} ${snapshot.humidityPercent}%',
                  style: const TextStyle(
                      fontSize: 11.5, color: DashboardPalette.textGray)),
              if (snapshot.heatAlertLevel != 'none') ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (snapshot.heatAlertLevel == 'high'
                            ? DashboardPalette.warningRed
                            : DashboardPalette.accentOrange)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 12,
                          color: snapshot.heatAlertLevel == 'high'
                              ? DashboardPalette.warningRed
                              : DashboardPalette.accentOrange),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${tr(lang, 'heatAlertLabel')} ${snapshot.heatAlertLevel == 'high' ? tr(lang, 'heatAlertHigh') : tr(lang, 'heatAlertModerate')}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: snapshot.heatAlertLevel == 'high'
                                ? DashboardPalette.warningRed
                                : DashboardPalette.accentOrange,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
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

/// Rolling hills, a small barn (with a roof + silo), and a simple fence
/// line — painted once (no per-frame rebuilds; the containing widget is
/// what animates, not this painter).
class _FarmScenePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Back hill — lighter green.
    final back = Path()
      ..moveTo(0, h * 0.5)
      ..quadraticBezierTo(w * 0.22, h * 0.28, w * 0.48, h * 0.46)
      ..quadraticBezierTo(w * 0.75, h * 0.64, w, h * 0.36)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
        back, Paint()..color = const Color(0xFF8BC34A).withValues(alpha: 0.5));

    // Front hill — darker green, sits lower/closer.
    final front = Path()
      ..moveTo(0, h * 0.74)
      ..quadraticBezierTo(w * 0.25, h * 0.52, w * 0.55, h * 0.72)
      ..quadraticBezierTo(w * 0.8, h * 0.9, w, h * 0.68)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(front,
        Paint()..color = DashboardPalette.primaryGreen.withValues(alpha: 0.8));

    // A couple of tree silhouettes.
    _tree(canvas, Offset(w * 0.86, h * 0.58), 16);
    _tree(canvas, Offset(w * 0.94, h * 0.66), 12);

    // Barn — simple rectangle body + triangular roof + a small silo.
    final barnBase = Offset(w * 0.16, h * 0.62);
    const barnWidth = 46.0;
    const barnHeight = 30.0;
    final barnPaint = Paint()..color = const Color(0xFFB0413E);
    final roofPaint = Paint()..color = const Color(0xFF6D2E2A);
    canvas.drawRect(
      Rect.fromLTWH(
          barnBase.dx - barnWidth / 2, barnBase.dy, barnWidth, barnHeight),
      barnPaint,
    );
    final roof = Path()
      ..moveTo(barnBase.dx - barnWidth / 2 - 6, barnBase.dy)
      ..lineTo(barnBase.dx, barnBase.dy - 20)
      ..lineTo(barnBase.dx + barnWidth / 2 + 6, barnBase.dy)
      ..close();
    canvas.drawPath(roof, roofPaint);
    // Barn door.
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(barnBase.dx, barnBase.dy + barnHeight - 8),
          width: 12,
          height: 16),
      Paint()..color = const Color(0xFF4A1F1D),
    );
    // Silo beside the barn.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barnBase.dx + barnWidth / 2 + 10, barnBase.dy - 10, 12,
            barnHeight + 10),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFFBFC4C7),
    );

    // Fence line — a few evenly spaced posts + a top rail, in front of the
    // hills near the bottom edge.
    final fencePaint = Paint()
      ..color = const Color(0xFF8D6E4E)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    final fenceY = h * 0.86;
    canvas.drawLine(
        Offset(w * 0.30, fenceY), Offset(w * 0.62, fenceY), fencePaint);
    for (double x = w * 0.30; x <= w * 0.62; x += 8) {
      canvas.drawLine(Offset(x, fenceY - 6), Offset(x, fenceY + 6), fencePaint);
    }
  }

  void _tree(Canvas canvas, Offset base, double size) {
    final trunkPaint = Paint()..color = const Color(0xFF6D4C2A);
    final leafPaint = Paint()..color = DashboardPalette.darkGreen;
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
  bool shouldRepaint(covariant _FarmScenePainter oldDelegate) => false;
}
