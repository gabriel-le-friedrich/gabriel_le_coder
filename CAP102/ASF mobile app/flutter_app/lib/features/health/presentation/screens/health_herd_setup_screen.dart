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
import 'health_herd_runner_screen.dart';

// ══════════════════════════════════════════════════════════════════════
// "Overall Herd" mode, step 1 — how many real pigs to monitor (1..total
// pig count, no active/inactive exclusion), then step 2 — pick exactly
// that many real pigs from the same pigListProvider list Pig Management
// and Specific Pig both use. Combined into one screen/stepper flow so the
// count and the selection can never drift out of sync.
// ══════════════════════════════════════════════════════════════════════
class HealthHerdSetupScreen extends ConsumerStatefulWidget {
  const HealthHerdSetupScreen({super.key});

  @override
  ConsumerState<HealthHerdSetupScreen> createState() =>
      _HealthHerdSetupScreenState();
}

class _HealthHerdSetupScreenState
    extends ConsumerState<HealthHerdSetupScreen> {
  int? _targetCount;
  final Set<String> _selectedIds = {};
  final _searchCtrl = TextEditingController();
  String _search = '';

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
        title: Text(tr(lang, 'overallHerdLabel'),
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
        error: (e, st) =>
            Center(child: Text(tr(lang, 'unableToLoadHealthMessage'))),
        data: (pigs) {
          if (pigs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(tr(lang, 'noPigsAvailableMessage'),
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: HealthMonitorPalette.grayText)),
              ),
            );
          }
          final count = _targetCount ?? (pigs.length < 5 ? pigs.length : 5);
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
                child: Container(
                  decoration: healthCardDecoration(),
                  padding: healthCardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(lang, 'howManyPigsQuestion'),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: HealthMonitorPalette.darkText)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: HealthMonitorPalette.primaryGreen),
                            onPressed: count > 1
                                ? () => setState(() {
                                      _targetCount = count - 1;
                                      if (_selectedIds.length > count - 1) {
                                        _selectedIds
                                          ..clear();
                                      }
                                    })
                                : null,
                          ),
                          Container(
                            width: 56,
                            alignment: Alignment.center,
                            child: Text('$count',
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: HealthMonitorPalette.darkText)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline,
                                color: HealthMonitorPalette.primaryGreen),
                            onPressed: count < pigs.length
                                ? () => setState(() {
                                      _targetCount = count + 1;
                                    })
                                : null,
                          ),
                        ],
                      ),
                      Center(
                        child: Text(
                            '${tr(lang, 'pigsToMonitorLabel')} (${tr(lang, 'ofLabel')} ${pigs.length})',
                            style: const TextStyle(
                                fontSize: 11,
                                color: HealthMonitorPalette.grayText)),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(tr(lang, 'selectPigsToMonitorTitle'),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: HealthMonitorPalette.darkText)),
                    ),
                    Text('${_selectedIds.length} / $count ${tr(lang, 'pigsSelectedLabel')}',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _selectedIds.length == count
                                ? HealthMonitorPalette.primaryGreen
                                : HealthMonitorPalette.grayText)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                  onChanged: (v) => setState(() => _search = v.trim()),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final pig = filtered[i];
                    final selected = _selectedIds.contains(pig.id);
                    return PigPickerTile(
                      imageWidget: pig.photoLocalPath != null
                          ? Image.file(File(pig.photoLocalPath!),
                              fit: BoxFit.cover)
                          : Container(
                              color: HealthMonitorPalette.lightGreen,
                              child: const Center(
                                  child:
                                      Text('🐷', style: TextStyle(fontSize: 20))),
                            ),
                      name: pig.name,
                      pigId: pig.id,
                      breed: pig.breed.isEmpty ? '—' : pig.breed,
                      selected: selected,
                      trailing: Checkbox(
                        value: selected,
                        activeColor: HealthMonitorPalette.primaryGreen,
                        onChanged: (_) => setState(() {
                          if (selected) {
                            _selectedIds.remove(pig.id);
                          } else if (_selectedIds.length < count) {
                            _selectedIds.add(pig.id);
                          }
                        }),
                      ),
                      onTap: () => setState(() {
                        if (selected) {
                          _selectedIds.remove(pig.id);
                        } else if (_selectedIds.length < count) {
                          _selectedIds.add(pig.id);
                        }
                      }),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar:
          pigsAsync.valueOrNull == null || pigsAsync.valueOrNull!.isEmpty
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: CustomButton(
                      label: tr(lang, 'startHerdHealthCheckButton'),
                      backgroundColor: HealthMonitorPalette.primaryGreen,
                      onPressed: _selectedIds.length ==
                              (_targetCount ??
                                  (pigsAsync.valueOrNull!.length < 5
                                      ? pigsAsync.valueOrNull!.length
                                      : 5))
                          ? () {
                              final pigs = pigsAsync.valueOrNull!
                                  .where((p) => _selectedIds.contains(p.id))
                                  .toList();
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) =>
                                    HealthHerdRunnerScreen(pigs: pigs),
                              ));
                            }
                          : null,
                    ),
                  ),
                ),
    );
  }
}
