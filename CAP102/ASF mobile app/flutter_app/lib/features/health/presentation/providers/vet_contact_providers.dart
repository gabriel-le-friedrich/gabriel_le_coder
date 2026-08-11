import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/vet_contact_repository.dart';

/// Provides the singleton [VetContactRepository] instance.
final vetContactRepositoryProvider =
    Provider<VetContactRepository>((ref) => VetContactRepository());

/// Null means no vet phone number has been saved yet.
final vetContactProvider =
    FutureProvider.autoDispose.family<VetContact?, String>((ref, uid) {
  return ref.watch(vetContactRepositoryProvider).getVetContact(uid);
});

/// Saves the vet contact and invalidates [vetContactProvider] so every
/// watcher (Vet Contacts screen, Critical Alert sheet) picks up the change.
final saveVetContactActionProvider =
    Provider<Future<void> Function(String uid, VetContact contact)>((ref) {
  return (uid, contact) async {
    await ref.read(vetContactRepositoryProvider).saveVetContact(uid, contact);
    ref.invalidate(vetContactProvider(uid));
  };
});
