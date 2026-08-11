import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../pigs/presentation/providers/pig_providers.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../theme/health_monitor_palette.dart';
import '../widgets/health_monitor_widgets.dart';
import 'health_form_screen.dart';

// ══════════════════════════════════════════════════════════════════════
// "Specific Pig" mode — the farmer selects exactly ONE real pig from the
// pig list, then the exact same HealthFormScreen already used everywhere
// else in Health Monitor opens scoped to that pig (widget.pigId/pigName).
// No new pig data, no new selection storage — pigListProvider is the same
// list Pig Management already reads.
// ══════════════════════════════════════════════════════════════════════
class HealthSelectPigScreen extends ConsumerStatefulWidget {
  const HealthSelectPigScreen({super.key});

  @override
  ConsumerState<HealthSelectPigScreen> createState() =>
      _HealthSelectPigScreenState();
}

class _HealthSelectPigScreenState
    extends ConsumerState<HealthSelectPigScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String? _selectedPigId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
    final lang = ref.watch(appLanguageProvider);
    final pigsAsync = ref.watch(pigListProvider(uid));

    return Scaffold(
      backgroundColor: HealthMonitorPalette.background,
      appBar: AppBar(
        backgroundColor: HealthMonitorPalette.background,
        elevation: 0,
        title: Text(tr(lang, 'selectPigTitle'),
            style: const TextStyle(
                color: HealthMonitorPalette.darkText,
                fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: HealthMonitorPalette.darkText),
      ),
      body: pigsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                  HealthMonitorPalette.primaryGreen)),
        ),
        error: (e, st) => Center(
            child: Text(tr(lang, 'unableToLoadHealthMessage'))),
        data: (pigs) {
          final filtered = pigs.where((p) {
            if (_search.isEmpty) return true;
            final q = _search.toLowerCase();
            return p.name.toLowerCase().contains(q) ||
                p.id.toLowerCase().contains(q);
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: tr(lang, 'searchPigHint'),
                    isDense: true,
                    filled: true,
                    fillColor: HealthMonitorPalette.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) =>
                      setState(() => _search = v.trim()),
                ),
              ),
              Expanded(
                child: pigs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(tr(lang, 'noPigsAvailableMessage'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: HealthMonitorPalette.grayText)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final pig = filtered[i];
                          return PigPickerTile(
                            imageWidget: pig.photoLocalPath != null
                                ? Image.file(File(pig.photoLocalPath!),
                                    fit: BoxFit.cover)
                                : Container(
                                    color: HealthMonitorPalette.lightGreen,
                                    child: const Center(
                                        child: Text('🐷',
                                            style: TextStyle(fontSize: 20))),
                                  ),
                            name: pig.name,
                            pigId: pig.id,
                            breed: pig.breed.isEmpty ? '—' : pig.breed,
                            selected: _selectedPigId == pig.id,
                            onTap: () =>
                                setState(() => _selectedPigId = pig.id),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: pigsAsync.valueOrNull == null ||
              pigsAsync.valueOrNull!.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: CustomButton(
                  label: tr(lang, 'startHealthCheckButton'),
                  backgroundColor: HealthMonitorPalette.primaryGreen,
                  onPressed: _selectedPigId == null
                      ? null
                      : () {
                          final pig = pigsAsync.valueOrNull!
                              .firstWhere((p) => p.id == _selectedPigId);
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => HealthFormScreen(
                              pigId: pig.id,
                              pigName: pig.name,
                            ),
                          ));
                        },
                ),
              ),
            ),
    );
  }
}
