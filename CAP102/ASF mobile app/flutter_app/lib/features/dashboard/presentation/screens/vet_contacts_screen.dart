import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/theme/app_design_system.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../health/data/vet_contact_repository.dart';
import '../../../health/presentation/providers/vet_contact_providers.dart';
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';

/// Vet Contacts — P3 redesign. Keeps the exact same functional core as
/// before (a "Saved Veterinarian" card the farmer fills in once, which is
/// what the Critical Health Alert's "Call Veterinarian" button reads — see
/// vet_contact_providers.dart/health_banner_card.dart, untouched by this
/// pass) and adds a professional, Material 3 directory below it — three
/// sectioned lists (Veterinarians, Agricultural Technicians, Emergency
/// Hotlines) of rounded contact cards with a profession badge, location,
/// phone, and a large "Call Now" button, matching the reference mockup.
///
/// The directory's sample entries are static reference data supplied for
/// this screen's redesign, not a live-synced database — only Dr. Joel
/// Salazar's number was given as an exact digit string (09975975597); the
/// other four entries didn't come with a phone number, so their cards show
/// "Number not listed" instead of a Call button rather than dialing a
/// fabricated number.
class VetContactsScreen extends ConsumerWidget {
  const VetContactsScreen({super.key});

  static const _directory = [
    _DirectoryContact(
      name: 'Dr. Ramon Santos',
      professionKey: 'vetBadgeVet',
      location: 'Magalang, Pampanga',
      badge: _Badge.vet,
    ),
    _DirectoryContact(
      name: 'Dr. Maria Reyes',
      professionKey: 'vetBadgeAnimalHealthOfficer',
      location: 'San Fernando, Pampanga',
      badge: _Badge.animalHealthOfficer,
    ),
    _DirectoryContact(
      name: 'Dr. Joel Salazar',
      professionKey: 'vetBadgeVet',
      location: null,
      badge: _Badge.vet,
      phone: '09975975597',
    ),
  ];

  static const _agTechDirectory = [
    _DirectoryContact(
      name: 'Engr. Jose Manalo',
      professionKey: 'vetBadgeAgTech',
      location: 'PSAU Magalang',
      badge: _Badge.agTech,
    ),
  ];

  static const _emergencyDirectory = [
    _DirectoryContact(
      name: 'DA-BAI Hotline',
      professionKey: null,
      location: null,
      badge: _Badge.emergency,
      subtitleOverride: '24/7 Disease Reports',
    ),
  ];

  static const _categories = [
    _ContactCategory(
      icon: Icons.apartment_outlined,
      titleKey: 'municipalAgOfficeTitle',
      descriptionKey: 'municipalAgOfficeDesc',
    ),
    _ContactCategory(
      icon: Icons.local_hospital_outlined,
      titleKey: 'provincialVetOfficeTitle',
      descriptionKey: 'provincialVetOfficeDesc',
    ),
    _ContactCategory(
      icon: Icons.storefront_outlined,
      titleKey: 'feedSupplyStoreTitle',
      descriptionKey: 'feedSupplyStoreDesc',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
    final contactAsync = ref.watch(vetContactProvider(uid));
    final lang = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(tr(lang, 'vetContactsTitle'),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          contactAsync.when(
            data: (contact) =>
                _SavedVetCard(uid: uid, contact: contact, lang: lang),
            loading: () => const SizedBox(
                height: 88,
                child:
                    Center(child: CircularProgressIndicator(strokeWidth: 2))),
            error: (_, __) =>
                _SavedVetCard(uid: uid, contact: null, lang: lang),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          Container(
            decoration: appCardDecoration(color: AppColors.lightGreen),
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.darkGreen, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr(lang, 'keepContactsBanner'),
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.darkGreen),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          SectionHeader(title: tr(lang, 'vetSectionVeterinarians')),
          for (final c in _directory) ...[
            _DirectoryCard(contact: c, lang: lang),
            const SizedBox(height: AppSpacing.cardGap),
          ],
          const SizedBox(height: AppSpacing.sectionGap - AppSpacing.cardGap),
          SectionHeader(title: tr(lang, 'vetSectionAgTechnicians')),
          for (final c in _agTechDirectory) ...[
            _DirectoryCard(contact: c, lang: lang),
            const SizedBox(height: AppSpacing.cardGap),
          ],
          const SizedBox(height: AppSpacing.sectionGap - AppSpacing.cardGap),
          SectionHeader(title: tr(lang, 'vetSectionEmergencyHotlines')),
          for (final c in _emergencyDirectory) ...[
            _DirectoryCard(contact: c, lang: lang),
            const SizedBox(height: AppSpacing.cardGap),
          ],
          const SizedBox(height: AppSpacing.sectionGap - AppSpacing.cardGap),
          for (final category in _categories) ...[
            _CategoryCard(category: category, lang: lang),
            const SizedBox(height: AppSpacing.cardGap),
          ],
        ],
      ),
    );
  }
}

class _SavedVetCard extends ConsumerWidget {
  const _SavedVetCard(
      {required this.uid, required this.contact, required this.lang});
  final String uid;
  final VetContact? contact;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomCard(
      radius: AppRadius.card,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryGreen,
            child: Icon(Icons.medical_services_outlined, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(lang, 'yourVeterinarian'),
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                if (contact != null) ...[
                  Text(
                      contact!.name.isEmpty
                          ? tr(lang, 'savedContactFallback')
                          : contact!.name,
                      style: const TextStyle(fontSize: 13)),
                  Text(contact!.phone,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ] else
                  Text(
                    tr(lang, 'noVetSavedYet'),
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (contact != null)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.button))),
                        onPressed: () =>
                            launchUrl(Uri(scheme: 'tel', path: contact!.phone)),
                        icon: const Icon(Icons.call, size: 16),
                        label: Text(tr(lang, 'callLabel')),
                      ),
                    if (contact != null) const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.button))),
                      onPressed: () => _showEditDialog(context, ref, contact),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: Text(contact != null
                          ? tr(lang, 'editLabel')
                          : tr(lang, 'addContactLabel')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(
      BuildContext context, WidgetRef ref, VetContact? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.cardSmall)),
        title: Text(tr(lang, 'veterinarianContactTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration:
                    InputDecoration(labelText: tr(lang, 'nameOptionalLabel'))),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              decoration: InputDecoration(labelText: tr(lang, 'phoneNumber')),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr(lang, 'cancel'))),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr(lang, 'save')),
          ),
        ],
      ),
    );
    if (saved == true && phoneCtrl.text.trim().isNotEmpty && context.mounted) {
      await ref.read(saveVetContactActionProvider)(uid,
          VetContact(name: nameCtrl.text.trim(), phone: phoneCtrl.text.trim()));
    }
  }
}

enum _Badge { vet, animalHealthOfficer, agTech, emergency }

class _DirectoryContact {
  const _DirectoryContact({
    required this.name,
    required this.professionKey,
    required this.location,
    required this.badge,
    this.phone,
    this.subtitleOverride,
  });

  final String name;
  final String? professionKey;
  final String? location;
  final _Badge badge;
  final String? phone;
  final String? subtitleOverride;
}

/// One professional, Material 3 directory card: avatar, name, profession
/// badge, location row, phone row (or "Number not listed"), and a large
/// Call Now button — green for regular contacts, red for Emergency Hotline
/// entries, per the reference mockup.
class _DirectoryCard extends StatelessWidget {
  const _DirectoryCard({required this.contact, required this.lang});
  final _DirectoryContact contact;
  final AppLanguage lang;

  bool get _isEmergency => contact.badge == _Badge.emergency;

  IconData get _avatarIcon {
    switch (contact.badge) {
      case _Badge.vet:
      case _Badge.animalHealthOfficer:
        return Icons.medical_services_outlined;
      case _Badge.agTech:
        return Icons.agriculture_outlined;
      case _Badge.emergency:
        return Icons.emergency_outlined;
    }
  }

  String _badgeLabel(AppLanguage lang) {
    switch (contact.badge) {
      case _Badge.vet:
        return tr(lang, 'vetBadgeVet');
      case _Badge.animalHealthOfficer:
        return tr(lang, 'vetBadgeAnimalHealthOfficer');
      case _Badge.agTech:
        return tr(lang, 'vetBadgeAgTech');
      case _Badge.emergency:
        return tr(lang, 'vetBadgeEmergency');
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _isEmergency ? AppColors.danger : AppColors.primaryGreen;
    return CustomCard(
      radius: AppRadius.card,
      semanticsLabel: '${contact.name}, ${_badgeLabel(lang)}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _isEmergency
                ? AppColors.danger.withValues(alpha: 0.12)
                : AppColors.lightGreen,
            child: Icon(_avatarIcon,
                color: _isEmergency ? AppColors.danger : AppColors.darkGreen),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(contact.name,
                          style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    StatusChip(label: _badgeLabel(lang), color: accent),
                  ],
                ),
                const SizedBox(height: 6),
                if (contact.subtitleOverride != null)
                  Text(contact.subtitleOverride!,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textSecondary)),
                if (contact.professionKey != null &&
                    contact.subtitleOverride == null)
                  Text(tr(lang, contact.professionKey!),
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textSecondary)),
                if (contact.location != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(contact.location!,
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                if (contact.phone != null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.button)),
                      ),
                      onPressed: () =>
                          launchUrl(Uri(scheme: 'tel', path: contact.phone)),
                      icon: const Icon(Icons.call, size: 16),
                      label: Text(tr(lang, 'callNowLabel')),
                    ),
                  )
                else
                  Row(
                    children: [
                      const Icon(Icons.phone_disabled_outlined,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(tr(lang, 'numberNotListedLabel'),
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCategory {
  const _ContactCategory(
      {required this.icon,
      required this.titleKey,
      required this.descriptionKey});
  final IconData icon;
  final String titleKey;
  final String descriptionKey;
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.lang});
  final _ContactCategory category;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      radius: AppRadius.card,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.lightGreen,
            child: Icon(category.icon, color: AppColors.darkGreen),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(lang, category.titleKey),
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(tr(lang, category.descriptionKey),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
