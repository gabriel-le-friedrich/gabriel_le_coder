// ══════════════════════════════════════════════════════════════════════
// Declarative routing (GoRouter), replacing the earlier manual
// Navigator.push/MaterialPageRoute + conditional-widget-swap approach.
// The redirect() below is the direct GoRouter equivalent of auth-main.js's
// authStateChange listener driving showAuthShell()/showAppShell() on the
// web. There is no onboarding wizard: once a user is signed in, they land
// straight on the Dashboard — pig creation happens entirely within Pig
// Management's Add Pig screen, and the Dashboard/Growth/Expenses screens
// all handle a brand new, pig-less account gracefully (see DashboardData's
// hasPigs and DashboardRepository.getPigBatchProfile's fallback).
// ══════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/verify_otp_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/dashboard/presentation/screens/calendar_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/tasks_screen.dart';
import '../../features/dashboard/presentation/screens/vet_contacts_screen.dart';
import '../../features/dashboard/presentation/widgets/dashboard_shell_scaffold.dart';
import '../../features/consultation/presentation/screens/expert_consultation_screen.dart';
import '../../features/email/presentation/screens/email_testing_screen.dart';
import '../../features/expenses/presentation/screens/expenses_screen.dart';
import '../../features/feeding/presentation/screens/feeding_screen.dart';
import '../../features/health/domain/health_calculations.dart';
import '../../features/health/presentation/screens/health_form_screen.dart';
import '../../features/health/presentation/screens/health_herd_setup_screen.dart';
import '../../features/health/presentation/screens/health_history_screen.dart';
import '../../features/health/presentation/screens/health_home_screen.dart';
import '../../features/health/presentation/screens/health_select_pig_screen.dart';
import '../../features/notifications/presentation/providers/notification_providers.dart';
import '../../features/notifications/presentation/screens/notification_settings_screen.dart';
import '../../features/pigs/domain/pig.dart';
import '../../features/pigs/presentation/screens/pig_calendar_screen.dart';
import '../../features/pigs/presentation/screens/pig_detail_screen.dart';
import '../../features/pigs/presentation/screens/pig_form_screen.dart';
import '../../features/pigs/presentation/screens/pig_list_screen.dart';
import '../../features/activity_log/presentation/screens/activity_log_screen.dart';
import '../../features/settings/presentation/providers/settings_providers.dart';
import '../../features/settings/presentation/screens/about_screen.dart';
import '../../features/settings/presentation/screens/data_management_screen.dart';
import '../../features/settings/presentation/screens/help_support_screen.dart';
import '../../features/settings/presentation/screens/offline_mode_screen.dart';
import '../../features/settings/presentation/screens/privacy_policy_screen.dart';
import '../../features/settings/presentation/screens/privacy_security_screen.dart';
import '../../features/settings/presentation/screens/profile_edit_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/sync_screen.dart';
import '../../features/settings/presentation/screens/terms_of_service_screen.dart';
import '../services/sync_engine_providers.dart';
import '../widgets/boot_loading_shell.dart';

class AppRoutes {
  AppRoutes._();

  static const boot = '/';
  static const welcome = '/welcome';
  static const register = '/register';
  static const verifyOtp = '/verify-otp';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const dashboard = '/dashboard';
  static const tasks = '/tasks';
  static const feeding = '/feeding';
  static const calendar = '/calendar';
  static const pigs = '/pigs';
  static const expenses = '/expenses';
  static const health = '/health';
  static const healthHub = '/health/hub';
  static const healthSelectPig = '/health/select-pig';
  static const healthHerdSetup = '/health/herd-setup';
  static const notificationSettings = '/settings/notifications';
  static const settings = '/settings';
  static const profileEdit = '/settings/profile';
  static const about = '/settings/about';
  static const privacyPolicy = '/settings/privacy';
  static const termsOfService = '/settings/terms';
  static const activityLog = '/settings/activity-log';
  static const vetContacts = '/vet-contacts';
  static const expertConsultation = '/expert-consultation';
  static const emailTesting = '/settings/email-testing';
  static const synchronization = '/settings/synchronization';
  static const dataManagement = '/settings/data-management';
  static const offlineMode = '/settings/offline-mode';
  static const privacySecurity = '/settings/privacy-security';
  static const helpSupport = '/settings/help-support';
}

/// Routes a signed-out user is allowed to be on without getting redirected
/// straight back to /welcome — the auth flow itself.
const _signedOutRoutes = {
  AppRoutes.welcome,
  AppRoutes.register,
  AppRoutes.verifyOtp,
  AppRoutes.login,
  AppRoutes.forgotPassword,
};

/// Bridges Riverpod's authStateChangesProvider stream to GoRouter's
/// Listenable-based refresh mechanism, so redirect() re-runs every time
/// Firebase's auth state actually changes (sign in / sign out) — without
/// this, GoRouter would only re-evaluate redirect() on explicit navigation
/// calls, and a background sign-out (e.g. token revoked) would never bounce
/// the user back to /welcome on its own.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authStateChangesProvider, (previous, next) => notifyListeners());
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.boot,
    refreshListenable: refreshNotifier,
    redirect: (context, state) async {
      final authAsync = ref.read(authStateChangesProvider);
      final onSignedOutRoute = _signedOutRoutes.contains(state.matchedLocation);

      // Firebase's very first auth event hasn't arrived yet — stay on the
      // boot route (renders BootLoadingShell below), same as the web app
      // keeping its boot-loading-shell up until the first authStateChange.
      if (!authAsync.hasValue && !authAsync.hasError) {
        return state.matchedLocation == AppRoutes.boot ? null : AppRoutes.boot;
      }

      final user = authAsync.valueOrNull;

      if (user == null) {
        return onSignedOutRoute ? null : AppRoutes.welcome;
      }

      // Registration's phone-link step is a special case: Firebase already
      // has a session (created back in createEmailPasswordUser, before the
      // phone-OTP step even starts), so `user` is already non-null WHILE
      // the person is still looking at /verify-otp entering the SMS code.
      // Without this check they'd get bounced straight to the Dashboard
      // before finishing registration. submitVerify() resets `step` back
      // to idle on success, which is what turns this override back off.
      //
      // Defense-in-depth: this also covers /register itself, not just
      // /verify-otp. auth_providers.dart's submitRegister() now sets
      // step: otpSent in the same state update that follows
      // createEmailPasswordUser() (before startPhoneVerification() even
      // runs), so this should already be true the moment Firebase's
      // auth-state stream fires and redirect() re-runs. Keeping /register
      // in this carve-out too guards against any remaining frame where the
      // router re-evaluates while the user is still on /register and
      // register_screen.dart's reactive `context.push(AppRoutes.verifyOtp)`
      // (gated on the same step flag) hasn't executed yet — without this,
      // that gap would still bounce the user to the Dashboard and abandon
      // registration before _finishRegistration()/createUserProfile() runs.
      final flowState = ref.read(authFlowControllerProvider);
      final onVerifyOtpRoute = state.matchedLocation == AppRoutes.verifyOtp;
      final onRegisterRoute = state.matchedLocation == AppRoutes.register;
      if ((onVerifyOtpRoute || onRegisterRoute) &&
          flowState.step == AuthFlowStep.otpSent &&
          flowState.verifyMode == VerifyMode.register) {
        return null;
      }

      // Fully signed in: keep them off the boot shell and off any
      // signed-out-only auth screen, landing on the Dashboard directly (no
      // onboarding step). Any other in-app route is left alone — this only
      // redirects away from routes that don't make sense for an
      // already-fully-signed-in user.
      if (onSignedOutRoute || state.matchedLocation == AppRoutes.boot) {
        return AppRoutes.dashboard;
      }
      return null;
    },
    routes: [
      GoRoute(
          path: AppRoutes.boot,
          builder: (context, state) => const BootLoadingShell()),
      GoRoute(
          path: AppRoutes.welcome,
          builder: (context, state) => const WelcomeScreen()),
      GoRoute(
          path: AppRoutes.register,
          builder: (context, state) => const RegisterScreen()),
      GoRoute(
          path: AppRoutes.verifyOtp,
          builder: (context, state) => const VerifyOtpScreen()),
      GoRoute(
          path: AppRoutes.login,
          // `extra: true` (set by the Welcome screen's "Continue with
          // Mobile OTP" button) opens LoginScreen straight on its phone
          // step; any other entry point (e.g. WelcomeScreen's "Log In"
          // button) omits `extra` and gets the default email step.
          builder: (context, state) =>
              LoginScreen(startOnPhoneStep: state.extra == true)),
      GoRoute(
          path: AppRoutes.forgotPassword,
          builder: (context, state) => const ForgotPasswordScreen()),
      // The 5-tab floating bottom nav (Dashboard/Tasks/Feeding/Pig Growth/
      // Expense) — a StatefulShellRoute so each tab keeps its own scroll
      // position/state alive via IndexedStack while switching. The Pig
      // Growth tab absorbs what used to be two separate modules (the
      // "Weight & ADG" and "Growth" tabs) — see pig_list_screen.dart /
      // pig_detail_screen.dart's file headers for the merge rationale.
      // Every other route below (Health, Pig sub-routes, Settings,
      // Notifications, Activity Log, About/Privacy/Terms) stays a plain
      // top-level GoRoute exactly as before, so pushing to any of them still
      // correctly covers the whole shell (nav bar included), same as any
      // normal full-screen push.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            DashboardShellScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: AppRoutes.dashboard,
                  builder: (context, state) => const _DashboardRoute())
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.tasks,
                builder: (context, state) {
                  final uid =
                      ref.read(authRepositoryProvider).currentUser?.uid ?? '';
                  return TasksScreen(uid: uid);
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.feeding,
                builder: (context, state) {
                  final uid =
                      ref.read(authRepositoryProvider).currentUser?.uid ?? '';
                  return FeedingScreen(uid: uid);
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: AppRoutes.pigs,
                  builder: (context, state) => const PigListScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.expenses,
                builder: (context, state) {
                  final uid =
                      ref.read(authRepositoryProvider).currentUser?.uid ?? '';
                  return ExpensesScreen(uid: uid);
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.calendar,
        builder: (context, state) {
          final uid = ref.read(authRepositoryProvider).currentUser?.uid ?? '';
          return CalendarScreen(uid: uid);
        },
      ),
      GoRoute(
          path: AppRoutes.vetContacts,
          builder: (context, state) => const VetContactsScreen()),
      GoRoute(
        path: AppRoutes.expertConsultation,
        builder: (context, state) {
          final uid = ref.read(authRepositoryProvider).currentUser?.uid ?? '';
          return ExpertConsultationScreen(uid: uid);
        },
      ),
      GoRoute(
        path: AppRoutes.emailTesting,
        builder: (context, state) {
          final uid = ref.read(authRepositoryProvider).currentUser?.uid ?? '';
          return EmailTestingScreen(uid: uid);
        },
      ),
      GoRoute(
          path: AppRoutes.health,
          builder: (context, state) => HealthHistoryScreen(
              initialStatusFilter: state.extra is HealthStatus
                  ? state.extra as HealthStatus
                  : null)),
      GoRoute(
        path: '${AppRoutes.health}/new',
        builder: (context, state) =>
            HealthFormScreen(editing: state.extra as HealthLogEntry?),
      ),
      GoRoute(
          path: AppRoutes.healthHub,
          builder: (context, state) => const HealthHomeScreen()),
      GoRoute(
          path: AppRoutes.healthSelectPig,
          builder: (context, state) => const HealthSelectPigScreen()),
      GoRoute(
          path: AppRoutes.healthHerdSetup,
          builder: (context, state) => const HealthHerdSetupScreen()),
      GoRoute(
          path: AppRoutes.notificationSettings,
          builder: (context, state) => const NotificationSettingsScreen()),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) {
          final uid = ref.read(authRepositoryProvider).currentUser?.uid ?? '';
          return SettingsScreen(uid: uid);
        },
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        builder: (context, state) {
          final uid = ref.read(authRepositoryProvider).currentUser?.uid ?? '';
          return ProfileEditScreen(uid: uid);
        },
      ),
      GoRoute(
        path: AppRoutes.synchronization,
        builder: (context, state) {
          final uid = ref.read(authRepositoryProvider).currentUser?.uid ?? '';
          return SyncScreen(uid: uid);
        },
      ),
      GoRoute(
        path: AppRoutes.dataManagement,
        builder: (context, state) {
          final uid = ref.read(authRepositoryProvider).currentUser?.uid ?? '';
          return DataManagementScreen(uid: uid);
        },
      ),
      GoRoute(
        path: AppRoutes.offlineMode,
        builder: (context, state) {
          final uid = ref.read(authRepositoryProvider).currentUser?.uid ?? '';
          return OfflineModeScreen(uid: uid);
        },
      ),
      GoRoute(
        path: AppRoutes.privacySecurity,
        builder: (context, state) {
          final uid = ref.read(authRepositoryProvider).currentUser?.uid ?? '';
          return PrivacySecurityScreen(uid: uid);
        },
      ),
      GoRoute(
        path: AppRoutes.helpSupport,
        builder: (context, state) {
          final uid = ref.read(authRepositoryProvider).currentUser?.uid ?? '';
          return HelpSupportScreen(uid: uid);
        },
      ),
      GoRoute(
          path: AppRoutes.about,
          builder: (context, state) => const AboutScreen()),
      GoRoute(
          path: AppRoutes.privacyPolicy,
          builder: (context, state) => const PrivacyPolicyScreen()),
      GoRoute(
          path: AppRoutes.termsOfService,
          builder: (context, state) => const TermsOfServiceScreen()),
      GoRoute(
        path: AppRoutes.activityLog,
        builder: (context, state) {
          final uid = ref.read(authRepositoryProvider).currentUser?.uid ?? '';
          return ActivityLogScreen(uid: uid);
        },
      ),
      GoRoute(
          path: '${AppRoutes.pigs}/new',
          builder: (context, state) => const PigFormScreen()),
      GoRoute(
        path: '${AppRoutes.pigs}/:id/edit',
        builder: (context, state) =>
            PigFormScreen(editingPig: state.extra as Pig?),
      ),
      GoRoute(
        path: '${AppRoutes.pigs}/:id/calendar',
        builder: (context, state) =>
            PigCalendarScreen(pigId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '${AppRoutes.pigs}/:id',
        builder: (context, state) =>
            PigDetailScreen(pigId: state.pathParameters['id']!),
      ),
    ],
  );
});

/// Watches the signed-in user's profile reactively (unlike the route
/// `builder`s above, which only ever do one-off synchronous `ref.read`
/// calls) so the greeting name updates live once the profile finishes
/// loading, exactly like the old `_SignedInRouter` widget did.
class _DashboardRoute extends ConsumerWidget {
  const _DashboardRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    if (user == null) {
      // Auth state raced ahead of this build (e.g. mid-logout) — show the
      // boot shell briefly; redirect() will catch up and bounce to
      // /welcome on the very next evaluation.
      return const BootLoadingShell();
    }
    // Fire-and-forget: reconciles OS-scheduled reminders with saved prefs
    // once per session for this uid — see notificationBootstrapProvider's
    // doc for why this covers reboot/app-update restore.
    ref.watch(notificationBootstrapProvider(user.uid));
    // Loads this uid's saved Theme/Language into the app-wide switches
    // app.dart watches — see settingsBootstrapProvider's doc.
    ref.watch(settingsBootstrapProvider(user.uid));
    // Runs one offline-write retry pass now, then keeps listening for
    // reconnects for the rest of this Dashboard session — see
    // syncEngineBootstrapProvider's doc.
    ref.watch(syncEngineBootstrapProvider(user.uid));
    // Pulls any pigs/expenses/health logs/weigh-ins that exist in the
    // cloud but not yet on this device (e.g. a fresh install on a second
    // phone) — see pullMissingDataBootstrapProvider's doc.
    ref.watch(pullMissingDataBootstrapProvider(user.uid));
    final profileAsync = ref.watch(userProfileProvider(user.uid));
    return profileAsync.when(
      data: (profile) => DashboardScreen(
          uid: user.uid, fullName: profile?['fullName'] as String?),
      loading: () => const BootLoadingShell(),
      error: (_, __) => DashboardScreen(uid: user.uid, fullName: null),
    );
  }
}
