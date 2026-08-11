import 'package:flutter/material.dart';

import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../theme/dashboard_palette.dart';

/// Ported verbatim from the legacy web app's static Tip of the Day string
/// (index.html: 'home-tip-head'/'home-tip-txt' — "Ensure fresh water is
/// always available. Pigs drink 2–3× more than the feed they eat daily.").
/// This IS the app's existing tip source; there is no rotating/randomized
/// tip system to preserve or hook up to, so this card shows the same single
/// tip the web app always shows.
class TipOfDayCard extends StatelessWidget {
  const TipOfDayCard({super.key, required this.lang});
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration:
          dashboardCardDecoration(color: const Color(0xFFFFF3E0), radius: 18),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(
              child: Text('💡', style: TextStyle(fontSize: 22))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(lang, 'tipOfTheDay'),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: DashboardPalette.darkGreen
                            .withValues(alpha: 0.85))),
                const SizedBox(height: 4),
                Text(
                  tr(lang, 'tipOfDayText'),
                  style: const TextStyle(
                      fontSize: 12.5, color: Colors.black87, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
