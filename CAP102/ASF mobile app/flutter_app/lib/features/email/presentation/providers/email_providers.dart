import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/email_repository.dart';

/// Plain repository provider — mirrors vetContactRepositoryProvider's shape
/// (see lib/features/health/presentation/providers/vet_contact_providers.dart)
/// since EmailRepository has no mutable UI state of its own; the Testing
/// screen keeps its own local state for the last result.
final emailRepositoryProvider =
    Provider<EmailRepository>((ref) => EmailRepository());
