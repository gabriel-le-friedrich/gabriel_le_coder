import '../../health/domain/health_calculations.dart';
import '../../notifications/domain/reminder_types.dart';
import 'app_language.dart';

// ══════════════════════════════════════════════════════════════════════
// Minimal bilingual dictionary for the Settings feature's own screens,
// mirroring the legacy web app's T.en/T.fil + t(key) pattern (index.html)
// at a much smaller scope: the legacy dictionary covers the ENTIRE web
// UI, but porting full app-wide translation to every existing Flutter
// screen (Dashboard/Growth/Expenses/Health/Notifications/Pigs — dozens of
// files already written in English) is a much larger follow-on effort.
// This gives Settings a fully working, honestly-scoped bilingual UI today
// and a ready-made pattern (`tr(lang, key)`) to extend to other features
// incrementally later.
// ══════════════════════════════════════════════════════════════════════

const Map<String, String> _en = {
  'settings': 'Settings',
  'profile': 'Profile',
  'profileSubtitle': 'Name, location, farm details',
  'language': 'Language',
  'languageSubtitle': 'English / Filipino',
  'notifications': 'Notifications',
  'notificationsSubtitle': 'Reminders and alerts',

  // ── Settings redesign — main Settings screen, Profile & Farm, and the
  // new Synchronization/Data Management/Offline Mode/Privacy & Security/
  // Help & Support screens (all reuse existing data/logic; see each
  // screen's file header for what's real vs. newly-surfaced). ──
  'settingsHeaderSubtitle':
      'Manage your account, app preferences, and farm settings.',
  'activeAccountStatus': 'Active Account',
  'profileFarmLabel': 'Profile & Farm',
  'profileFarmSubtitle': 'Manage your personal and farm details',
  'accountSectionTitle': 'ACCOUNT',
  'dataSyncSectionTitle': 'DATA & SYNCHRONIZATION',
  'securitySupportSectionTitle': 'SECURITY & SUPPORT',
  'synchronizationLabel': 'Synchronization',
  'synchronizationSubtitle': 'Keep your data backed up to the cloud',
  'dataManagementLabel': 'Data Management',
  'dataManagementSubtitle': 'Export records and manage stored data',
  'offlineModeLabel': 'Offline Mode',
  'offlineModeSubtitle': 'How ASF works without an internet connection',
  'privacySecurityLabel': 'Privacy & Security',
  'privacySecuritySubtitle': 'How your data is protected',
  'helpSupportLabel': 'Help & Support',
  'helpSupportSubtitle': 'Get help using the app',
  'onlineStatus': 'Online',
  'offlineStatus': 'Offline',
  'syncNowButton': 'Sync Now',
  'syncingLabel': 'Syncing…',
  'syncCompleteMessage': 'Sync complete.',
  'syncFailedMessage': 'Sync failed. It will retry automatically.',
  'synchronizationScreenIntro':
      'ASF automatically backs up your pigs, weigh-ins, health logs, and expenses to the cloud whenever you have a connection. You can also trigger a sync manually below.',
  'connectionStatusLabel': 'Connection Status',
  'accountSecureTitle': 'Your Account is Secure',
  'accountSecureBody':
      'Your account is protected by Firebase Authentication, and your farm records are stored securely both on this device and in the cloud.',
  'memberSinceLabel': 'Member Since',
  'roleLabel': 'Role',
  'personalInformationTitle': 'Personal Information',
  'farmInformationTitle': 'Farm Information',
  'farmLocationLabel': 'Farm Location',
  'accountSecurityTitle': 'Account Security',
  'offlineModeExplainTitle': 'Works Without Internet',
  'offlineModeExplainBody':
      "You can keep recording weigh-ins, feedings, health checks, and expenses even without a signal. Everything is saved on this device first and uploaded automatically the next time you're online.",
  'dataManagementIntro':
      'Export your records as CSV or PDF from Expenses or Health Logs, review your Activity Log, or reset your progress below.',
  'expensesRecordsLabel': 'Expenses & Records',
  'expensesRecordsSubtitle': 'View, add, and export expense records',
  'healthLogsExportSubtitle': 'View and export health monitoring records',
  'dangerZoneLabel': 'DANGER ZONE',
  'helpSupportIntro':
      'Need help? Reach out to an agricultural expert for advice, or check the app details below.',
  'alertNotificationsTitle': 'ALERT NOTIFICATIONS',
  'reminderNotificationsTitle': 'REMINDER NOTIFICATIONS',
  'addProfilePhotoLabel': 'Add Profile Photo',
  'unableToLoadProfileMessage': 'Unable to load profile information.',

  // ── Notification Settings screen (notification_settings_screen.dart) ──
  'allNotifications': 'All Notifications',
  'allNotificationsSubtitle':
      'Master switch — turns every reminder on or off at once.',
  'discardChangesTitle': 'Discard changes?',
  'discardChangesBody': 'You have unsaved notification preference changes.',
  'keepEditing': 'Keep Editing',
  'discardChangesButton': 'Discard',
  'resetToDefaults': 'Reset to Defaults',
  'resetToDefaultsTitle': 'Reset to Defaults?',
  'resetToDefaultsBody':
      'This restores every reminder to its default time and enabled state.',
  'reset': 'Reset',
  'couldNotLoadNotificationSettings': 'Could not load notification settings.',
  'nextReminderPrefix': 'Next',

  'theme': 'Theme',
  'themeSubtitle': 'Light, dark, or system default',
  'activityLog': 'Activity Log',
  'activityLogSubtitle': 'History of every action in this app',
  'emailTesting': 'Email Testing',
  'emailTestingSubtitle': 'Send test emails to verify the email service',
  'expertConsultation': 'Expert Consultation',
  'expertConsultationSubtitle': 'Get help from an agricultural expert',
  'about': 'About',
  'aboutSubtitle': 'App version and developer info',
  'privacyPolicy': 'Privacy Policy',
  'termsOfService': 'Terms of Service',
  'logout': 'Log Out',
  'logoutConfirmTitle': 'Log out?',
  'logoutConfirmBody':
      "You'll need to sign in again to access your farm data. Your data stays saved on this device.",

  // ── Reset Progress (C10) — danger-zone action in Settings that wipes
  // pigs/logs/photos on this device AND in the cloud, returning to Day 1.
  // Three steps: warning dialog -> type-to-confirm -> cancelable countdown.
  'resetProgress': 'Reset Progress',
  'resetProgressSubtitle':
      'Start over from Day 1 — clears all pigs and records',
  'resetProgressWarningTitle': 'Reset all progress?',
  'resetProgressWarningBody':
      'This permanently deletes every pig, weekly photo, weight/feeding/health/expense record — on this device AND in the cloud. Your account, phone/email, and app settings are kept. This cannot be undone.',
  'resetProgressTypeConfirmTitle': 'Type RESET to confirm',
  'resetProgressTypeConfirmBody':
      'To make sure this is intentional, type RESET below.',
  'resetProgressTypeConfirmHint': 'RESET',
  'resetProgressCountdownTitle': 'Resetting in…',
  'resetProgressCountdownBody':
      'You can still cancel. Progress will be wiped when the countdown reaches 0.',
  'resetProgressDone': 'All progress has been reset. Welcome back to Day 1.',
  'resetProgressFailed':
      'Something went wrong while resetting. Please try again.',
  'cancel': 'Cancel',
  'save': 'Save',
  'saving': 'Saving...',
  'fullName': 'Full Name',
  'municipality': 'Municipality / City',
  'province': 'Province',
  'farmName': 'Farm Name',
  'farmerType': 'Farmer Type',
  'email': 'Email',
  'phoneNumber': 'Phone Number',
  'profileSaved': 'Profile updated.',
  'selectLanguage': 'Select Language',
  'selectTheme': 'Select Theme',
  'light': 'Light',
  'dark': 'Dark',
  'system': 'System default',

  // ── Shared / common (buttons, statuses, generic dialogs — used across
  // every feature module, not just Settings) ──
  'retry': 'Retry',
  'delete': 'Delete',
  'edit': 'Edit',
  'add': 'Add',
  'close': 'Close',
  'done': 'Done',
  'yes': 'Yes',
  'no': 'No',
  'ok': 'OK',
  'loading': 'Loading...',
  'somethingWentWrong': 'Something went wrong. Please try again.',
  'required': 'Required',
  'optional': 'Optional',
  'takePhoto': 'Take Photo',
  'chooseFromGallery': 'Choose from Gallery',
  'maxSizeNotice': 'Max 3 MB — images are compressed automatically.',

  // ── Dashboard drawer navigation ──
  'navDashboard': 'Dashboard',
  'navDailyTasks': 'Daily Tasks',
  'navFeedingGuide': 'Feeding Guide',
  'navHealthMonitor': 'Health Monitor',
  'navHealthLogs': 'Health Logs',
  'navWeightAdg': 'Weight & ADG',
  'navPigGrowth': 'Pig Growth',
  'navExpenseRoi': 'Expense & ROI',
  'navVetContacts': 'Vet Contacts',
  'navCalendar': '120-Day Calendar',
  'navSettings': 'Settings',
  'navMyPigs': 'My Pigs',
  'navActivityLog': 'Activity Log',
  'navLogOut': 'Log Out',
  'navSectionMain': 'MAIN',
  'navSectionRecords': 'RECORDS',
  'navSectionAccount': 'ACCOUNT',

  // ── Dashboard screen chrome ──
  'dashboardTitle': 'Dashboard',
  'openMenu': 'Open menu',
  'openProfileTooltip': 'Open profile and settings',
  'switchLanguageTooltip': 'Switch app language',
  'upcomingReminders': 'Upcoming Reminders',
  'healthTrend': 'Health Trend',
  'marketDayArrived': '🐷 Market Day has arrived!',
  'couldNotLoadReminders': 'Could not load reminders.',
  'off': 'Off',
  'dashboardLoadError': 'Something went wrong loading your Dashboard.',
  'currentDay': 'Current Day',
  'cycleComplete': 'Cycle complete',
  'daysLeft': 'days left',
  'avgDailyGain': 'Avg Daily Gain',
  'currentWeight': 'Current Weight',
  'projectedNetProfit': 'Projected Net Profit',
  'noPigsYet': 'No pigs yet',
  'fcr': 'FCR',
  'growthPercent': 'Growth %',
  'adgExcellent': 'Excellent',
  'adgOnTrack': 'On Track',
  'adgBelowTarget': 'Below Target',
  'adgNeedsAttention': 'Needs Attention',
  'weeklyWeightRequired': 'Weekly weight required',
  'noWeeklyDataYet': 'No weekly data yet',
  'thisWeekSuffix': 'kg this week',

  // ── Dashboard redesign (2026 premium farm dashboard) ──
  'dashboardHeroSubtitle': "Here's what's happening with your farm today.",
  'daysOnTrack': 'Days on Track',
  'tasksTodayStat': 'Tasks Today',
  'avgWeightStat': 'Average Weight',
  'herdStatusStat': 'Herd Status',
  'doneShortSuffix': 'Done',
  'leftShortSuffix': 'Left',
  'allGoodCaption': 'All good!',
  'herdCaptionMonitor': 'Keep watching',
  'herdCaptionRisk': 'Check soon',
  'herdCaptionCritical': 'Vet recommended',
  'noHerdDataYetCaption': 'No data yet',
  'herdOverviewTitle': 'Herd Overview',
  'totalPigsLabel': 'Total Pigs',
  'activePigsLabel': 'Active Pigs',
  'finisherLabel': 'Finisher',
  'growingLabel': 'Growing',
  'healthSummaryLabel': 'Health Summary',
  'quickActionsTitle': 'Quick Actions',
  'recordWeightAction': 'Record Weight',
  'healthCheckAction': 'Health Check',
  'feedingGuideAction': 'Feeding Guide',
  'expensesAction': 'Expenses',
  'pigPhotosAction': 'Pig Photos',
  // ── Dashboard v2 (weather card, restyled summary grid, Health Overview
  // donut, grouped Today's Tasks) ──
  'activeAnimalsCaption': 'Active Animals',
  'growthProgressStat': 'Growth Progress',
  'targetWeightSuffix': ' kg target',
  'humidityLabel': 'Humidity',
  'heatAlertLabel': 'Heat Alert:',
  'heatAlertModerate': 'Moderate',
  'heatAlertHigh': 'High',
  'healthOverviewTitle': 'Health Overview',
  'overallStatusLabel': 'Overall Status',
  'morningGroupLabel': 'Morning',
  'eveningGroupLabel': 'Evening',

  // ── Auth (Welcome / Login / Register) ──
  'appTagline': 'Administration for Swine Finisher',
  'appMotto': '"From Day-1 to Market-Day"',
  'createAccount': 'Create an Account',
  'logIn': 'Log In',
  'forgotPassword': 'Forgot password?',
  'rememberMe': 'Remember me',
  'sendCode': 'Send Code',
  'welcomeBackTitle': 'Welcome Back',
  'welcomeBackLoginSubtitle':
      'Continue monitoring your pigs, feeding schedules, and production records.',
  'newFarmerTitle': 'New Farmer?',
  'newFarmerBody': 'Create an ASF account to start tracking pigs today.',
  'continueWithMobileOtp': 'Continue with Mobile OTP',
  'backToEmailLogin': 'Back to Email Login',
  'orDivider': 'OR',
  'welcomeFeatureTasks': 'Track Daily Tasks',
  'welcomeFeatureHealth': 'Monitor Health',
  'welcomeFeaturePerformance': 'Improve Performance',
  'welcomeSecurityFooter': 'Your data is secure and private',
  'mobileNumber': 'Mobile Number',
  'password': 'Password',
  'showPassword': 'Show password',
  'hidePassword': 'Hide password',
  'previousMonth': 'Previous month',
  'nextMonth': 'Next month',
  'refreshTooltip': 'Refresh',
  'filterByDateTooltip': 'Filter by date',
  'clearDateFilterTooltip': 'Clear date filter',
  'updateProfilePhotoTooltip': 'Update profile photo',
  'confirmPassword': 'Confirm Password',
  'municipalityProvince': 'Municipality, Province',
  'enterValidEmail': 'Enter a valid email',
  'atLeast6Chars': 'At least 6 characters',
  'passwordsDoNotMatch': 'Passwords do not match',
  'enter11Digits': 'Enter exactly 11 digits (e.g. 09171234567)',
  'mobileStartsWith0': 'Mobile number should start with 0',
  'mobileInvalidPrefix': 'Enter a valid PH mobile number (e.g. 09171234567)',
  'emailTab': 'Email',
  'mobileOtpTab': 'Mobile OTP',
  'resetPasswordTitle': 'Reset Password',
  'resetPasswordInstructions':
      "Enter the email you registered with. We'll send you a link to reset your password.",
  'sendResetLink': 'Send Reset Link',
  'resetLinkSent': 'Password reset link sent. Check your email.',
  'enterOtpTitle': 'Enter Verification Code',
  'enterOtpInstructions': 'Enter the 6-digit code sent to your mobile number.',
  'verifyCode': 'Verify Code',
  'resendCode': 'Resend Code',
  'resendCodeIn': 'Resend code in',
  'verifyYourNumber': 'Verify Your Number',
  'enterCodeSentTo': 'Enter the 6-digit code sent to',
  'yourPhone': 'your phone',
  'verify': 'Verify',

  // ── Feature screen titles (match the drawer labels for the same route) ──
  'healthHistoryTitle': 'Health History',
  'feedingGuideTitle': 'Feeding Guide',
  'growthTitle': 'Growth & Performance',
  'weightAdgTitle': 'Weight & ADG',
  'expenseRoiTitle': 'Expense & ROI',
  'exportCsv': 'Export CSV',
  'exportPdf': 'Export PDF',

  // ── Health Monitor form (health_form_screen.dart) ──
  // NOTE: the underlying symptom OPTION catalogs (kBehaviorOptions,
  // kAppetiteOptions, kPhysicalOptions, kWasteOptions in
  // health_calculations.dart) are intentionally NOT translated here. Their
  // `.label` strings are read by the scoring engine's unit tests, CSV/PDF
  // export, and Dashboard trend tooltips — retrofitting them to be
  // language-aware would mean touching the one module in this app with the
  // most existing test coverage, for a cosmetic gain, with real regression
  // risk. Everything else on this screen (titles, buttons, dialogs,
  // section chrome) is translated below.
  'editObservation': 'Edit Observation',
  'healthMonitorTitle': 'Health Monitor',
  'editingLogFrom': 'Editing log from',
  'dailyObservationLog': 'Daily observation log',
  'viewHealthLogs': 'View Health Logs',

  // ── Health Monitor redesign — Home hub, Specific Pig, Overall Herd
  // (health_monitor_home_screen.dart, pig_health_select_screen.dart,
  // herd_*.dart). All counts/summaries shown by these screens come from
  // real HealthLogEntry/Pig data — see each screen's own doc for exactly
  // which provider backs which number. ──
  'healthMonitorSubtitle': 'Monitor your pigs\' health and act early.',
  'todaysOverviewTitle': "TODAY'S OVERVIEW",
  'notYetCheckedLabel': 'Not Yet Checked',
  'startHealthMonitoringTitle': 'START HEALTH MONITORING',
  'howWouldYouLikeToMonitor': 'How would you like to monitor?',
  'specificPigLabel': 'Specific Pig',
  'specificPigSubtitle': 'Check the health of one pig',
  'overallHerdLabel': 'Overall Herd',
  'overallHerdSubtitle': 'Monitor multiple pigs',
  'healthCategoriesTitle': 'HEALTH CATEGORIES',
  'sevenDayTrendTitle': '7-Day Health Trend',
  'lastHealthCheckTitle': 'Last Health Check',
  'healthTipsTitle': 'Health Tips',
  'noPigsAvailableMessage': 'No pigs available for health monitoring.',
  'noHealthChecksMessage': 'No health checks recorded yet.',
  'startFirstHealthCheckMessage':
      'Start your first health check to begin monitoring your pigs.',
  'notEnoughTrendDataMessage':
      'Not enough health records to show a trend yet.',
  'selectPigTitle': 'Select Pig',
  'startHealthCheckButton': 'Start Health Check',
  'howManyPigsQuestion': 'How many pigs would you like to monitor?',
  'pigsToMonitorLabel': 'Pigs to monitor',
  'selectPigsButton': 'Select Pigs',
  'selectPigsToMonitorTitle': 'Select Pigs to Monitor',
  'pigsSelectedLabel': 'pigs selected',
  'startHerdHealthCheckButton': 'Start Herd Health Check',
  'herdHealthSummaryTitle': 'Herd Health Summary',
  'pigsMonitoredLabel': 'Pigs Monitored',
  'attentionRequiredTitle': 'Attention Required',
  'attentionRequiredBody': 'require immediate attention.',
  'reviewCriticalPigsButton': 'Review Critical Pigs',
  'reviewAtRiskPigsButton': 'Review At-Risk Pigs',
  'newHealthCheckButton': 'New Health Check',
  'unableToLoadHealthMessage': 'Unable to load health information.',
  'noPigsSelectedYet': 'pig(s) selected',
  'pigOfLabel': 'Pig',
  'healthMonitorNavLabel': 'Health Monitor',
  'allMonitoredPigsLabel': 'All Monitored Pigs',
  'unassignedLabel': 'Unassigned',
  'herdExitConfirmTitle': 'Leave herd check?',
  'herdExitConfirmBody': 'Progress for pigs not yet saved will be lost.',
  'exitHerdCheckButton': 'Exit',
  'healthTip1':
      'Check each pig at the same time every day so changes in behavior are easier to notice.',
  'healthTip2':
      'A sudden drop in appetite is often the earliest sign something is wrong — don\'t wait to log it.',
  'healthTip3':
      'Isolate a pig showing severe or emergency symptoms while you arrange a vet visit.',
  'notesOptional': 'Notes (optional)',
  'notesHint': 'Describe any unusual observations...',
  'assessedByOptional': 'Assessed By (optional)',
  'assessedByHint': 'Defaults to your name if left blank',
  'saveObservation': 'Save Health Observation',
  'selectOne': 'SELECT ONE',
  'multipleSelect': 'MULTIPLE SELECT',
  'noneSelected': 'None selected',
  'incompleteAssessmentTitle': 'Incomplete Health Assessment',
  'incompleteAssessmentBody':
      'Please complete all required health categories before saving.',
  'alreadyRecordedTitle': 'Already Recorded',
  'alreadyRecordedBody':
      'A health assessment has already been recorded for Day',
  'editTodaysAssessment': "Edit Today's Assessment",
  'unfinishedAssessmentTitle': 'Unfinished Assessment',
  'unfinishedAssessmentBody': 'Restore your unfinished health assessment?',
  'discard': 'Discard',
  'restore': 'Restore',
  'criticalHealthAlert': 'Critical Health Alert',
  'criticalAlertBody':
      'One or more severe symptoms were detected. Immediate veterinary attention is strongly recommended.',
  'callVeterinarian': 'Call Veterinarian',
  'viewContactList': 'View Contact List',
  'callNow': 'Call Now',
  'callConfirmPrefix': 'Call',
  'healthSavedSnackbar':
      '✅ Health observation saved. Daily health inspection completed.',
  'tasksUnlocked': 'Tasks unlocked',
  'healthSummary': '📋 Health Summary',
  'behaviorLabel': 'Behavior',
  'appetiteLabel': 'Appetite',
  'physicalLabel': 'Physical',
  'wasteLabel': 'Waste',
  'overallStatus': 'Overall Status',
  'severityCounts': 'Severity Counts',
  'healthyChip': 'Healthy',
  'monitoringChip': 'Monitoring',
  'atRiskChip': 'At Risk',
  'criticalChip': 'Critical',
  'reasonLabel': 'Reason',
  'recommendationLabel': 'Recommendation',
  'healthyIndicators': 'Healthy Indicators',
  'needsMonitoring': 'Needs Monitoring',
  'atRiskSection': 'At Risk',
  'criticalSection': 'Critical',
  'physicalCondition': '🩺 Physical Condition',
  'searchHint': 'Search...',
  'noRecordsFound': 'No records found.',
  'deleteHealthObsTitle': 'Delete this health observation?',
  'deleteConfirmBody': 'This action cannot be undone.',
  'delete2': 'Delete',

  // ── Health History (health_history_screen.dart) ──
  'logHealth': 'Log Health',
  'searchNotesHint': 'Search notes or observations',
  'allChip': 'All',
  'todayChip': 'Today',
  'thisWeekChip': 'This Week',
  'thisMonthChip': 'This Month',
  'customDate': 'Custom date',
  'clearCustomDateFilter': 'Clear custom date filter',
  'noHealthObsYet': 'No health observations recorded yet.',
  'deleteObsBodyPrefix': 'This removes the',
  'deleteObsBodySuffix': 'entry. This cannot be undone.',
  'goBack': 'Go Back',
  'healthMonitorErrorTitle': 'Health Monitor Error',
  'healthMonitorErrorBody':
      'Something went wrong while loading your health records.',
  'skippedRecordsNotice': 'Some invalid health records were ignored.',
  'batchLabel': 'Batch',
  'pigLabel': 'Pig',
  'assessedByLabel': 'Assessed by',

  // ── Feeding Guide (feeding_screen.dart) ──
  'addPigToSeeFeedingPlan':
      'Add a pig in Pig Management to see your feeding plan.',
  // Bug A5 fix: Daily Tasks screen's zero-pigs guard (tasks_screen.dart).
  'addPigToLogTasks': 'Add a pig in Pig Management before logging daily tasks.',
  'todaysFeedingScheduleSection': "Today's Feeding Schedule",
  'morning': 'Morning',
  'morningTimeHint': '7:30 – 8:00 AM',
  'afternoon': 'Afternoon',
  'afternoonTimeHint': 'PM Feeding',
  'todaysFeedingSection': "Today's Feeding",
  'totalFeedTodayLabel': 'Total Feed Today',
  'feedingsCompletedLabel': 'Feedings Completed',
  'dailyFeedingProgressSection': 'Daily Feeding Progress',
  'goalAchievedLabel': 'Goal Achieved',
  'feedCostCalculatorSection': 'Feed Cost Calculator',
  'feedStatisticsSection': 'Feed Statistics',
  'growthTimelineSection': 'Growth Timeline',
  'stageGuideSection': 'Stage Guide',
  'feedRecommendationSection': 'Feed Recommendation',
  'feedingTipsSection': 'Feeding Tips',
  'todaysSummarySection': "Today's Summary",
  'feedHistorySection': 'Feed History',
  'dayLabel': 'Day',
  'couldNotLoadFeedingPlan': 'Could not load your feeding plan.',
  'editFeedPriceTitle': 'Edit Feed Price',
  'feedPriceHint': 'Feed Price (₱ per kg)',
  'feedPriceUpdated': 'Feed price updated.',
  'healthAlertTitle': '🚨 Health Alert',
  'increasedMonitoringTitle': '⚠️ Increased Monitoring Recommended',
  'healthAlertCriticalMsg':
      "The latest health assessment is Critical. Review the Health Monitor before proceeding with today's feeding.",
  'healthAlertRiskMsg':
      "Today's feeding should be accompanied by closer observation.",
  'currentFeedingPlan': '🐷 CURRENT FEEDING PLAN',
  'productionDayPrefix': 'Production Day',
  'currentWeightLabel': 'Current Weight',
  'dailyFeedLabel': 'Daily Feed',
  'targetWeightLabel': 'Target Weight',
  'remainingLabel': 'Remaining',
  'expectedDailyGainLabel': 'Expected Daily Gain',
  'estimatedNextStageLabel': 'Estimated Next Stage',
  'daysRemainingSuffix': 'Days Remaining',
  'nextStagePrefix': 'Next Stage:',
  'marketReady': 'Market Ready',
  'fedLabel': 'Fed',
  'notYetFedLabel': 'Not Yet Fed',
  'completionLabel': 'Completion',
  'dailyFeedingCompleteBanner': '🎉 Daily Feeding Complete',
  'completedLabel': 'Completed',
  'pendingLabel': 'Pending',
  'feedPricePerKgLabel': 'Feed Price (per kg)',
  'todaysFeedLabel': "Today's Feed",
  'todaysCostLabel': "Today's Cost",
  'thirtyDayEstLabel': '30-Day Est.',
  'thisWeekLabel': 'This Week',
  'estThisMonthLabel': 'Est. This Month',
  'doneCaption': 'Done',
  'currentCaption': 'Current',
  'nextCaption': 'Next',
  'upcomingCaption': 'Upcoming',
  'reachedCaption': 'Reached',
  'finalGoalCaption': 'Final Goal',
  'stageColHeader': 'Stage',
  'weightColHeader': 'Weight',
  'feedPerDayColHeader': 'Feed/Day',
  'statusColHeader': 'Status',
  'passedStatus': 'Passed',
  'feedTypeEarly': 'Grower/Finisher feed, 16–18% crude protein',
  'feedTypeMid': 'Finisher feed, 14–16% crude protein',
  'feedTypeLate': 'Finisher feed, 13–15% crude protein',
  'feedTypeLabel': 'Feed Type',
  'waterLabel': 'Water',
  'waterAdLibitum': 'Clean water available at all times (ad libitum)',
  'todaysRecommendation': "Today's Recommendation",
  'recoHealthyBullet': 'Continue the normal feeding schedule.',
  'recoMonitorBullet1': 'Observe feed intake closely.',
  'recoMonitorBullet2':
      "If the pig does not finish today's ration, record the appetite again tomorrow.",
  'recoRiskBullet1': 'The pig has shown signs requiring closer observation.',
  'recoRiskBullet2':
      'Maintain the recommended feed amount unless advised otherwise by a veterinarian.',
  'recoRiskBullet3': 'Monitor appetite and hydration every feeding.',
  'recoCriticalBullet1': 'Critical condition detected.',
  'recoCriticalBullet2':
      'Consult a veterinarian immediately before changing the feeding program.',
  'recoCriticalBullet3': 'Continue offering clean water.',
  'recoCriticalBullet4': 'Record all observations.',
  'feedAllowanceLabel': 'Feed Allowance',
  'waterUnlimited': 'Unlimited clean water',
  'waterEnsureConstant': 'Ensure constant access.',
  'feedTip1':
      'Feed at the same time every day to keep pigs calm and reduce stress.',
  'feedTip2':
      'Always provide feed in clean, dry troughs to avoid spoilage and waste.',
  'feedTip3':
      'Watch for leftover feed — it may signal reduced appetite worth checking in Health Monitor.',
  'feedTip4': 'Adjust feed amount gradually when moving between growth stages.',
  'weightLabel': 'Weight',
  'feedLabel': 'Feed',
  'costLabel': 'Cost',
  'nextFeedingLabel': 'Next Feeding',
  'statusLabel': 'Status',
  'morningFeeding': 'Morning feeding',
  'afternoonFeeding': 'Afternoon feeding',
  'noneBothDone': 'None — both done',
  'completeStatus': 'Complete ✓',
  'inProgressStatus': 'In Progress',
  'notStartedStatus': 'Not Started',

  // ── Weight & ADG (growth_screen.dart) ──
  'somethingWentWrongLoadingGrowth':
      'Something went wrong loading Growth data.',
  'syncedWithMobileApp': 'Synced with mobile app',
  'thisWeeksAdg': "THIS WEEK'S ADG",
  'poorTier': 'Poor',
  'healthyTier': 'Healthy',
  'noDataYet': 'No data yet',
  'targetRangeLabel': 'Target Range:',
  'feedConversionRatioTitle': 'FEED CONVERSION RATIO (FCR)',
  'goodTier': 'Good',
  'needsImprovementTier': 'Needs Improvement',
  'thisWeeksFcr': "This Week's FCR",
  'thisWeeksFcrTrend': "THIS WEEK'S FCR TREND",
  'lowerFcrBetterNotice': 'Lower values indicate better feed efficiency.',
  'weekPrefix': 'Week',
  'recordNewWeightTitle': 'Record New Weight',
  'recordForWeekLabel': 'Recording for',
  'addNotesOptional': '+ Add notes (optional)',
  'enterValidWeightKg': 'Enter a valid weight in kg.',
  'replaceThisWeeksWeighInTitle': "Replace this week's weigh-in?",
  'weighInExistsPrefix': 'A weigh-in already exists for Week',
  'replaceWithSuffix': 'Replace it with',
  'weeklyPhotoUnlocksSuffix': 'photo becomes available on Day',
  'replaceButton': 'Replace',
  'weighInHistoryTitle': 'WEIGH-IN HISTORY',
  'noWeightRecordsYet': 'No weight records yet.',
  'baselineLabel': 'Baseline',
  'fcrHistoryTitle': 'FCR HISTORY',
  'feedConsumedPrefix': 'Feed Consumed:',
  'deleteWeighInTitle': 'Delete this weigh-in?',
  'deleteWeighInBodyPrefix': 'This removes the Week',
  'deleteWeighInBodyMiddle': 'entry (',
  'deleteWeighInBodySuffix': 'kg). This cannot be undone.',
  'editWeighInTitle': 'Edit Weigh-in',
  'weightKgLabel': 'Weight (kg)',
  'trackHerdsGrowthSubtitle': "Track your herd's growth and weight progress.",
  'weeklyGainLabel': 'Weekly Gain',
  'averageWeightLabel': 'Average Weight',
  'lastWeighInLabel': 'Last Weigh-in',
  'progressToTargetLabel': 'Progress to Target',
  'onTrackLabel': 'On Track',
  'weightProgressSectionTitle': 'Weight Progress',
  'notEnoughDataYetTitle': 'Not enough data yet',
  'notEnoughDataYetFcrBody':
      'Record more feeding and weight information to view your trend.',
  'todayLabel': 'Today',

  // ── Growth Overview (growth_overview_screen.dart) ──
  'growthProgressTitle': 'Growth Progress',
  'growthPctRequiredNotice': 'Weekly weight required to calculate growth %.',
  'progressTowardMarketWeight': 'Progress toward market weight',
  'percentOfWayToMarket': 'of the way to market weight',
  'couldNotLoadGrowthData': 'Could not load Growth data.',
  'adgTrendTitle': 'ADG Trend',
  'fcrTrendTitle': 'FCR Trend',
  'notEnoughWeeklyWeighIns': 'Not enough weekly weigh-ins yet.',
  'currentWeekLabelShort': 'Current Week',
  'currentDayLabelShort': 'Current Day',
  'recordWeeklyWeightLabel': 'Record Weekly Weight',
  'noWeeklyWeighInsYetTitle': 'No weekly weigh-ins yet.',
  'noWeeklyWeighInsYetBody':
      "Record your first weekly weight to start tracking your pig's growth.",
  'goToWeightRecordsLabel': 'Go to Weight Records',
  'weeklyGrowthTimelineTitle': 'Weekly Growth Timeline',
  'weekCompleteLabel': 'complete',
  'weekCurrentLabel': 'current week',

  // ── Growth Overview redesign (growth_overview_screen.dart) ──
  'growthPerformanceSubtitle':
      "Monitor your pigs' growth, performance, and development.",
  'growthOverviewLabel': 'GROWTH OVERVIEW',
  'growthStatusStarting': 'Just getting started',
  'growthStatusSteady': 'Growing steadily',
  'growthStatusAlmostThere': 'Almost there',
  'growthStatusReady': 'Ready for market',
  'vsLastRecordLabel': 'vs last record',
  'vsPreviousPeriodLabel': 'vs previous period',
  'actualWeightLegend': 'Actual Weight',
  'notEnoughGrowthDataBody':
      'Record more weekly weigh-ins to see your growth chart.',
  'averageDailyGainSectionTitle': 'AVERAGE DAILY GAIN',
  'kgFeedPerKgGainLabel': 'kg feed / kg gain',
  'thisWeeksPerformanceTitle': "THIS WEEK'S PERFORMANCE",
  'weightGainLabel': 'Weight Gain',
  'performanceTrendLabel': 'Performance Trend',
  'productionStageTitle': 'PRODUCTION STAGE',
  'estimatedTransitionLabel': 'Estimated transition',
  'growthMilestonesTitle': 'GROWTH MILESTONES',
  'startingWeightMilestoneLabel': 'Starting Weight',
  'currentStageMilestoneLabel': 'Current Stage',
  'upcomingLabel': 'Upcoming',
  'marketReadyLabel': 'Market Ready',
  'viewAllHistoryLabel': 'View all history',
  'recordWeightActionTitle': 'Record Weight',
  'recordWeightActionSubtitle': 'Add new weight and update growth data',
  'adgLabel': 'ADG',
  'fcrLabel': 'FCR',
  'growthAnalyticsSectionTitle': 'Growth Analytics',
  'trendImprovingLabel': 'Improving',
  'trendDecliningLabel': 'Declining',
  'trendStableLabel': 'Stable',
  'fromLastWeekSuffix': 'from last week',

  // ── Expense & ROI (expenses_screen.dart) ──
  'liveCostTracking': 'Live cost tracking',
  'noExpensesRecordedYet': 'No expenses recorded yet.',
  'expenseBreakdownSection': 'EXPENSE BREAKDOWN',
  'recentEntriesSection': 'RECENT ENTRIES',
  'somethingWentWrongLoadingExpenses': 'Something went wrong loading Expenses.',
  'expenseUpdatedSnackbar': 'Expense updated.',
  'expenseAddedSnackbar': 'Expense added.',
  'deleteExpenseTitle': 'Delete this expense?',
  'deleteExpenseBodyPrefix': 'This removes',
  'deleteExpenseBodySuffix': '. This cannot be undone.',
  'expenseDeletedSnackbar': 'Expense deleted.',
  'totalSpentLabel': 'TOTAL SPENT',
  'moreOptionsTitle': 'More Options',
  'financialSummarySection': 'FINANCIAL SUMMARY',
  'projectedRevenueLabel': 'Projected Revenue',
  'totalExpensesLabel': 'Total Expenses',
  'netProfitLabel': 'Net Profit',
  'roiPercentLabel': 'ROI %',
  'noExpensesYetTitle': 'No expenses yet',
  'tapAddFirstExpense': 'Tap the + button to record your first expense.',
  'addExpenseButton': 'Add Expense',
  'editExpenseTitle': 'Edit Expense',
  'descriptionLabel': 'Description',
  'descriptionHint': 'e.g. Finisher Feed (50 kg sack)',
  'amountPesoLabel': 'Amount (₱)',
  'dateUpperLabel': 'DATE',
  'additionalRemarksHint': 'Additional remarks...',
  'saveChanges': 'Save Changes',
  'saveExpense': 'Save Expense',
  'amountMustBeGreaterThanZero': 'Amount must be greater than 0.',

  // ── Expense & ROI redesign v2 (green hero / financial stats / donut /
  // ROI Analytics) ──
  'expenseOverviewEyebrow': 'EXPENSE OVERVIEW',
  'thisProductionCycleLabel': 'This production cycle',
  'financialStatisticsSection': 'FINANCIAL STATISTICS',
  'avgDailyCostLabel': 'Avg Daily Cost',
  'costSuffixLabel': 'Cost',
  'notEnoughExpenseDataYet': 'Not enough expense data yet',
  'notEnoughExpenseDataBody':
      'Add a few expenses to see your category breakdown here.',
  'roiAnalyticsTitle': 'ROI Analytics',
  'viewRoiAnalyticsLabel': 'View ROI Analytics',
  'profitabilityOverviewSection': 'PROFITABILITY OVERVIEW',
  'costVsRevenueTrendSection': 'COST VS REVENUE TREND',
  'totalRoiLabel': 'Total ROI',
  'categorySectionLabel': 'Category',
  'addExpenseScreenSubtitle': 'Log a new cost for this production cycle',
  'editExpenseScreenSubtitle': 'Update the details of this expense',
  'revenueLabel': 'Revenue',
  'liveCostTrackingSubtitle': 'Live cost tracking for smarter farm decisions.',
  'totalLabel': 'Total',

  'categoryFeed': 'Feed',
  'categoryMedicine': 'Medicine',
  'categoryVaccines': 'Vaccines',
  'categoryVitamins': 'Vitamins',
  'categoryTransportation': 'Transportation',
  'categoryLabor': 'Labor',
  'categoryUtilities': 'Utilities',
  'categoryEquipment': 'Equipment',
  'categoryOther': 'Other',

  // ── Pig Calendar (pig_calendar_screen.dart) ──
  'calendarSuffix': 'Calendar',
  'pigFallback': 'Pig',
  'growthTimelineSectionUpper': 'GROWTH TIMELINE',
  'noWeeklyPhotosYet': 'No weekly photos recorded yet.',
  'couldNotLoadCalendar': 'Could not load the calendar.',
  'hasPhotoLegend': 'Has Photo',
  'noPhotoLegend': 'No Photo',
  'todayLegend': 'Today',
  'noImageUploaded': 'No image uploaded',
  'uploadedPrefix': 'Uploaded:',

  // ── Add/Edit Pig (pig_form_screen.dart) ──
  'editPigTitle': 'Edit Pig',
  'addPigTitle': 'Add Pig',
  'pigInformationSection': 'PIG INFORMATION',
  'pigIdLabel': 'Pig ID',
  'pigNameLabel': 'Pig Name',
  'breedLabel': 'Breed',
  'breedHint': 'e.g. Landrace Cross',
  'genderLabel': 'Gender',
  'maleLabel': 'Male',
  'femaleLabel': 'Female',
  'scheduleSection': 'SCHEDULE',
  'arrivalDateLabel': 'Arrival Date',
  'birthDateLabel': 'Birth Date',
  'productionSection': 'PRODUCTION',
  'initialWeightKgLabel': 'Initial Weight (kg)',
  'editStartingWeightHelper':
      'Use "Edit Starting Weight" on Growth History to change this.',
  'enterValidWeight': 'Enter a valid weight',
  'penNumberLabel': 'Pen Number',
  'penNumberHint': 'e.g. Pen 4',
  'photoUploadSection': 'PHOTO UPLOAD',
  'mmddyyyyPlaceholder': 'mm/dd/yyyy',
  'saveChangesButton': 'Save Changes',
  'savePigButton': 'Save Pig',

  // Pig Growth Dashboard (pig_list_screen.dart)
  'pigGrowthTitle': 'Pig Growth',
  'weeklyPhotoTrackingSubtitle': 'Weekly photo tracking for every pig',
  'registeredPigsSection': 'REGISTERED PIGS',
  'couldNotLoadPigs': 'Could not load your pigs.',
  'deleteThisPigTitle': 'Delete this pig?',
  'deletePigBodyPrefix': 'This removes',
  'deletePigBodySuffix': 'and its weekly photos. This cannot be undone.',
  'weeksRecordedStat': 'WEEKS RECORDED',
  'latestUploadStat': 'LATEST UPLOAD',
  'completionStat': 'COMPLETION',
  'growthPhotosStat': 'GROWTH PHOTOS',
  'addPigButton': 'Add Pig',
  'searchPigHint': 'Search by Pig Name or Pig ID',
  'filterAllPigs': 'All Pigs',
  'filterActive': 'Active',
  'filterCompletedGrowth': 'Completed Growth',
  'filterMale': 'Male',
  'filterFemale': 'Female',
  'sortByLabel': 'Sort by',
  'sortName': 'Name',
  'sortAge': 'Age',
  'sortLatestUpload': 'Latest Upload',
  'sortWeight': 'Weight',
  'noPigRecordsTitle': 'No Pig Records Yet',
  'noPigRecordsBody':
      "You haven't added any pigs yet. Tap Add Pig above to create your first pig.",
  'unknownBreed': 'Unknown breed',
  'ageMetricLabel': 'AGE',
  'weightMetricLabel': 'WEIGHT',
  'lastUploadMetricLabel': 'LAST UPLOAD',
  'weeksMetricLabel': 'WEEKS',
  'daysUnit': 'days',
  'wksUnit': 'wks',
  'growthProgressLabel': 'Growth Progress',
  'weeksCompletedSuffix': 'Weeks Completed',
  'viewGrowthButton': 'View Growth →',
  'statusActive': 'Active',
  'statusInProgress': 'In Progress',
  'statusCompleted': 'Completed',
  'statusNoPhotosYet': 'No Photos Yet',

  // Growth History (pig_detail_screen.dart)
  'growthHistoryTitle': 'Growth History',
  'calendarViewTooltip': 'Calendar View',
  'editPigTooltip': 'Edit Pig',
  'pigNotFoundMessage': 'Pig not found.',
  'couldNotLoadWeightRecords': 'Could not load weight records.',
  'couldNotLoadThisPig': 'Could not load this pig.',
  'addNoteTooltip': 'Add Note',
  'takePhotoBeforeNoteMessage':
      'Take a photo for this week before adding a note.',
  'noteForWeekPrefix': 'Note for Week',
  'addGrowthNoteHint': 'Add a growth note...',
  'uploadingPhotoMessage': 'Uploading photo…',
  'imageExceeds3MbMessage': 'Image exceeds 3 MB. Please choose another image.',
  'startingWeightPrefix': 'Starting Weight:',
  'growthChartSection': 'GROWTH CHART',
  'recordTwoWeightsNotice': 'Record at least two weights to see a trend.',
  'firstWeightLegend': 'First Weight',
  'latestWeightLegend': 'Latest Weight',
  'weightTimelineSection': 'WEIGHT TIMELINE',
  'sinceLastWeighInSuffix': 'since last weigh-in',
  'weeklyProgressPhotosSection': 'WEEKLY PROGRESS PHOTOS',
  'noGrowthPhotosYet': 'No growth photos uploaded yet.',
  'startTrackingPigNotice':
      'Start tracking this pig by uploading its first weekly photo.',
  'uploadPhotoButton': 'Upload Photo',
  'growthComparisonSection': 'GROWTH COMPARISON',
  'uploadAnotherWeekNotice': "Upload another week's photo\nto compare growth.",
  'weekALabel': 'Week A',
  'weekBLabel': 'Week B',
  'selectTwoWeeksNotice': 'Select two weeks with photos to compare.',
  'noImageAvailableMessage': 'No image available.',
  'notesSection': 'NOTES',
  'noNotesAddedYet': 'No notes added yet.',

  // ── Pig Growth redesign (pig_list_screen.dart / pig_detail_screen.dart) ──
  'trackPigsGrowthSubtitle': "Track your pigs' growth and weekly development.",
  'weeksRecordedCaption': 'Weeks Recorded',
  'latestUpdateCaption': 'Latest Update',
  'completionCaption': 'Completion',
  'growthPhotosCaption': 'Growth Photos',
  'statusLabelCaption': 'Status',
  'weeksRemainingSuffix': 'weeks remaining',
  'herdGrowthSectionTitle': 'Herd Growth',
  'herdGrowthDisclaimer':
      'Weight, ADG, and FCR are recorded once per production batch and shared across all pigs.',
  'remainingSuffix': 'remaining',
  'weeklyProgressSectionTitle': 'Weekly Progress',
  'latestPhotoSectionTitle': 'Latest Photo',
  'viewAllLabel': 'View All',
  'informationSectionTitle': 'Information',
  'dateOfBirthLabel': 'Date of Birth',
  'penAreaLabel': 'Pen / Area',
  'notesFieldLabel': 'Notes',
  'noNotesRecorded': 'No notes recorded',
  'actionsSectionTitle': 'Actions',
  'addPhotoActionLabel': 'Add Photo',
  'editPigActionLabel': 'Edit Pig',
  'deletePigActionLabel': 'Delete Pig',
  'unableToLoadGrowthData': 'Unable to load growth data.',
  'tryAgainButton': 'Try Again',
  'noGrowthRecordsYetTitle': 'No growth records yet',
  'noGrowthRecordsYetBody':
      "Record the first weight to start tracking this pig's development.",
  'noPhotosUploadedYetTitle': 'No photos uploaded yet',
  'noPhotosUploadedYetBody':
      'Add a weekly photo to monitor visual development.',
  'startTrackingHerdBody': 'Start tracking your herd by adding your first pig.',

  // ── Production-readiness translation sweep (round 2) ──
  // OTA update dialog
  'otaUpdateAvailable': 'Update Available',
  'otaLater': 'Later',
  'otaUpdateNow': 'Update Now',
  'otaDefaultNotes': 'Improvements and bug fixes.',
  // Activity Log
  'activityLogTitle': 'Activity Log',
  'searchDescriptionHint': 'Search description...',
  'noActivityFound': 'No activity found.',
  'couldNotLoadActivityLog': 'Could not load the activity log.',
  'allFilter': 'All',
  'notYetSyncedTooltip': 'Not yet synced to the cloud',
  // About screen
  'aboutDescription':
      'A mobile pig farm management application for monitoring and guiding '
          'swine finisher raising practices throughout the full 120-day growing period.',
  'versionLabel': 'Version',
  'developerLabel': 'Developer',
  'institutionLabel': 'Institution',
  'campusLabel': 'Campus',
  // Profile photo picker
  'couldNotLoadImage': 'Could not load that image. Please try another.',
  'updateProfilePhotoTitle': 'Update Profile Photo',
  'maxSizeCompressed': 'Max size 3 MB — images are compressed automatically.',
  'chooseGallery': 'Choose Gallery',
  // Farmer Type dropdown display labels (kFarmerTypeOptions stays English/canonical)
  'farmerTypeBackyard': 'Backyard Raiser',
  'farmerTypeCommercial': 'Commercial Raiser',
  'farmerTypeSemiCommercial': 'Semi-Commercial',
  'farmerTypeHobbyist': 'Hobbyist',
  // Calendar screen (Full 120-Day Overview)
  'fullOverviewTitle': 'Full 120-Day Overview',
  'ofLabel': 'of',
  'daysCompletedSuffix': 'days completed',
  'completedLegend': 'Completed',
  'upcomingLegend': 'Upcoming',
  // Tasks screen (Daily Activities)
  'dailyActivitiesTitle': 'Daily Activities',
  'completeAllTasksSuffix': 'Complete all tasks to advance',
  'doneSuffix': 'Done',
  'somethingWentWrongTasks': 'Something went wrong loading your tasks.',
  'morningRoutine': 'MORNING ROUTINE',
  'eveningRoutine': 'EVENING ROUTINE',
  'taskLockedTitle': '🔒 Task Locked',
  'taskLockedBody':
      'This task requires a Health Monitor assessment before it can be completed.\n\n'
          'Please complete the Health Monitor first to unlock this task.',
  'goToHealthMonitor': 'Go to Health Monitor',
  'lockTask10Message':
      'Complete Vitality Inspection, Respiratory Check, and Temp & Ventilation before recording today\'s daily logs.',
  // Vet Contacts
  'vetContactsTitle': 'Vet Contacts',
  'keepContactsBanner':
      "Keep other emergency contacts saved here too so they're one tap away.",
  'yourVeterinarian': 'Your Veterinarian',
  'savedContactFallback': 'Saved contact',
  'noVetSavedYet':
      'No veterinarian saved yet. Add one so the Critical Health Alert can call them directly.',
  'callLabel': 'Call',
  'editLabel': 'Edit',
  'addContactLabel': 'Add Contact',
  'veterinarianContactTitle': 'Veterinarian Contact',
  'nameOptionalLabel': 'Name (optional)',
  'municipalAgOfficeTitle': 'Municipal / City Agriculture Office',
  'municipalAgOfficeDesc':
      'Reports on disease outbreaks (including ASF) and access to local livestock support programs.',
  'provincialVetOfficeTitle': 'Provincial Veterinary Office',
  'provincialVetOfficeDesc':
      'Escalation point for suspected disease outbreaks or when your local vet needs backup.',
  'feedSupplyStoreTitle': 'Feed & Supply Store',
  'feedSupplyStoreDesc':
      'For feed, supplements, and basic veterinary supplies.',
  'vetSectionVeterinarians': 'Veterinarians',
  'vetSectionAgTechnicians': 'Agricultural Technicians',
  'vetSectionEmergencyHotlines': 'Emergency Hotlines',
  'vetBadgeVet': 'Vet',
  'vetBadgeAnimalHealthOfficer': 'Animal Health Officer',
  'vetBadgeAgTech': 'Agricultural Technician',
  'vetBadgeEmergency': 'Emergency Hotline',
  'callNowLabel': 'Call Now',
  'numberNotListedLabel': 'Number not listed',
  // Dashboard greeting header
  'goodMorning': 'Good Morning',
  'goodAfternoon': 'Good Afternoon',
  'goodEvening': 'Good Evening',
  'cycleCompleteLabel': 'Production cycle complete! 🎉',
  'calendarPillLabel': 'Calendar',
  'logTodayLabel': 'Log Today',
  'completeTasksFirstSnackbar': '❌ Complete all tasks first!',
  'incompleteTasksDialogBody':
      'You still have unfinished tasks for today. Go to the Tasks screen to finish them?',
  'goToTasks': 'Go to Tasks',
  'completeExclaim': 'Complete! 🎉',
  'proceedToDayPrefix': 'Proceed to Day',
  'farmerFallback': 'Farmer',
  'retryLoadingNameLabel': 'Tap to retry loading your name',
  // Health Banner Card (Dashboard)
  'noHealthObservationsYet': 'No health observations yet',
  'logTodayHealthCheckSubtitle':
      "Log today's Behavior/Appetite/Physical/Waste check.",
  'healthNotLoggedYetTitle': "Today's Health · Not logged yet",
  'lastRecordedPrefix': 'Last recorded:',
  'onDayLabel': 'on Day',
  'logTodayCheckToStayOnTrack': "Log today's check to stay on track.",
  'noneRecorded': 'None recorded',
  'todaysHealthLabel': "Today's Health",
  'vetRecommendedSuffix': 'Veterinarian Recommended',
  'lastAssessmentLabel': 'Last Assessment',
  'todayAtLabel': 'Today',
  // Tip of the Day
  'tipOfTheDay': 'Tip of the Day',
  'tipOfDayText':
      'Ensure fresh water is always available. Pigs drink 2–3× more than the feed they eat daily.',
  // Today's Tasks card (Dashboard)
  'todaysTasksTitle': "Today's Tasks",
  'progressLabel': 'Progress',
  'completedTasksLabel': 'COMPLETED TASKS',
  'pendingTasksLabel': 'PENDING TASKS',
  'noTasksCompletedYet': 'No tasks completed yet',
  'allDoneLabel': 'All done! 🎉',
  'viewAllTasksLabel': 'View All Tasks →',
};

const Map<String, String> _fil = {
  'settings': 'Mga Setting',
  'profile': 'Profile',
  'profileSubtitle': 'Pangalan, lokasyon, detalye ng bukid',
  'language': 'Wika',
  'languageSubtitle': 'English / Filipino',
  'notifications': 'Mga Paalala',
  'notificationsSubtitle': 'Mga paalala at abiso',

  // ── Settings redesign ──
  'settingsHeaderSubtitle':
      'Pamahalaan ang iyong account, mga setting ng app, at bukid.',
  'activeAccountStatus': 'Aktibong Account',
  'profileFarmLabel': 'Profile at Bukid',
  'profileFarmSubtitle': 'Pamahalaan ang iyong personal at detalye ng bukid',
  'accountSectionTitle': 'ACCOUNT',
  'dataSyncSectionTitle': 'DATA AT SYNCHRONIZATION',
  'securitySupportSectionTitle': 'SEGURIDAD AT SUPORTA',
  'synchronizationLabel': 'Synchronization',
  'synchronizationSubtitle': 'Panatilihing naka-backup ang iyong data sa cloud',
  'dataManagementLabel': 'Pamamahala ng Data',
  'dataManagementSubtitle': 'I-export ang mga record at pamahalaan ang data',
  'offlineModeLabel': 'Offline Mode',
  'offlineModeSubtitle': 'Paano gumagana ang ASF kahit walang internet',
  'privacySecurityLabel': 'Privacy at Seguridad',
  'privacySecuritySubtitle': 'Paano protektado ang iyong data',
  'helpSupportLabel': 'Tulong at Suporta',
  'helpSupportSubtitle': 'Kumuha ng tulong sa paggamit ng app',
  'onlineStatus': 'Online',
  'offlineStatus': 'Offline',
  'syncNowButton': 'I-sync Ngayon',
  'syncingLabel': 'Nagsi-sync…',
  'syncCompleteMessage': 'Tapos na ang pag-sync.',
  'syncFailedMessage': 'Nabigo ang pag-sync. Susubukan muli awtomatiko.',
  'synchronizationScreenIntro':
      'Awtomatikong nagba-backup ang ASF ng iyong mga baboy, timbang, health logs, at gastos sa cloud tuwing may koneksyon ka. Maaari ka ring mag-sync nang manu-mano sa ibaba.',
  'connectionStatusLabel': 'Status ng Koneksyon',
  'accountSecureTitle': 'Secure ang Iyong Account',
  'accountSecureBody':
      'Protektado ang iyong account ng Firebase Authentication, at ligtas na naka-imbak ang iyong mga rekord ng bukid sa device na ito at sa cloud.',
  'memberSinceLabel': 'Miyembro Simula',
  'roleLabel': 'Tungkulin',
  'personalInformationTitle': 'Personal na Impormasyon',
  'farmInformationTitle': 'Impormasyon ng Bukid',
  'farmLocationLabel': 'Lokasyon ng Bukid',
  'accountSecurityTitle': 'Seguridad ng Account',
  'offlineModeExplainTitle': 'Gumagana Kahit Walang Internet',
  'offlineModeExplainBody':
      'Maaari kang magpatuloy na mag-record ng timbang, pagpapakain, health check, at gastos kahit walang signal. Unang naka-imbak ang lahat sa device na ito at awtomatikong ina-upload sa susunod na online ka.',
  'dataManagementIntro':
      'I-export ang iyong mga rekord bilang CSV o PDF mula sa Gastos o Health Logs, suriin ang iyong Activity Log, o i-reset ang progreso sa ibaba.',
  'expensesRecordsLabel': 'Gastos at mga Rekord',
  'expensesRecordsSubtitle': 'Tingnan, magdagdag, at i-export ang mga gastos',
  'healthLogsExportSubtitle': 'Tingnan at i-export ang mga health record',
  'dangerZoneLabel': 'MAPANGANIB NA SEKSYON',
  'helpSupportIntro':
      'Kailangan ng tulong? Makipag-ugnayan sa isang eksperto sa agrikultura, o tingnan ang detalye ng app sa ibaba.',
  'alertNotificationsTitle': 'MGA ALERTONG PAALALA',
  'reminderNotificationsTitle': 'MGA REGULAR NA PAALALA',
  'addProfilePhotoLabel': 'Magdagdag ng Profile Photo',
  'unableToLoadProfileMessage': 'Hindi ma-load ang impormasyon ng profile.',

  // ── Notification Settings screen ──
  'allNotifications': 'Lahat ng Paalala',
  'allNotificationsSubtitle':
      'Pangunahing switch — binubuksan o pinapatay ang lahat ng paalala nang sabay-sabay.',
  'discardChangesTitle': 'Iwaksi ang mga pagbabago?',
  'discardChangesBody':
      'May mga hindi pa na-save na pagbabago sa iyong mga paalala.',
  'keepEditing': 'Ipagpatuloy ang Pag-edit',
  'discardChangesButton': 'Iwaksi',
  'resetToDefaults': 'I-reset sa Default',
  'resetToDefaultsTitle': 'I-reset sa Default?',
  'resetToDefaultsBody':
      'Ibabalik nito ang bawat paalala sa default na oras at estado.',
  'reset': 'I-reset',
  'couldNotLoadNotificationSettings':
      'Hindi mai-load ang mga setting ng paalala.',
  'nextReminderPrefix': 'Susunod',

  'theme': 'Tema',
  'themeSubtitle': 'Maliwanag, madilim, o default ng system',
  'activityLog': 'Talaan ng Aktibidad',
  'activityLogSubtitle': 'Kasaysayan ng bawat aksyon sa app na ito',
  'emailTesting': 'Pagsubok ng Email',
  'emailTestingSubtitle':
      'Magpadala ng test email para masuri ang serbisyo ng email',
  'expertConsultation': 'Konsultasyon sa Eksperto',
  'expertConsultationSubtitle':
      'Humingi ng tulong mula sa eksperto sa agrikultura',
  'about': 'Tungkol Dito',
  'aboutSubtitle': 'Bersyon ng app at impormasyon ng developer',
  'privacyPolicy': 'Patakaran sa Privacy',
  'termsOfService': 'Mga Tuntunin ng Serbisyo',
  'logout': 'Mag-log Out',
  'logoutConfirmTitle': 'Mag-log out?',
  'logoutConfirmBody':
      'Kailangan mong mag-sign in muli para ma-access ang datos ng iyong bukid. Nananatiling naka-save ang iyong datos sa device na ito.',

  'resetProgress': 'I-reset ang Progreso',
  'resetProgressSubtitle':
      'Magsimula ulit sa Araw 1 — buburahin ang lahat ng baboy at rekord',
  'resetProgressWarningTitle': 'I-reset ang lahat ng progreso?',
  'resetProgressWarningBody':
      'Permanenteng buburahin nito ang bawat baboy, lingguhang larawan, at rekord ng timbang/pagpapakain/kalusugan/gastos — sa device na ito AT sa cloud. Mananatili ang iyong account, numero/email, at mga setting. Hindi na ito maibabalik.',
  'resetProgressTypeConfirmTitle': 'I-type ang RESET para kumpirmahin',
  'resetProgressTypeConfirmBody':
      'Para masiguro na sinasadya mo ito, i-type ang RESET sa ibaba.',
  'resetProgressTypeConfirmHint': 'RESET',
  'resetProgressCountdownTitle': 'Nire-reset sa…',
  'resetProgressCountdownBody':
      'Maaari mo pa itong kanselahin. Buburahin ang progreso kapag umabot sa 0 ang countdown.',
  'resetProgressDone': 'Na-reset na ang lahat ng progreso. Balik sa Araw 1.',
  'resetProgressFailed':
      'May naganap na problema habang nagre-reset. Pakisubukan muli.',
  'cancel': 'Kanselahin',
  'save': 'I-save',
  'saving': 'Sine-save...',
  'fullName': 'Buong Pangalan',
  'municipality': 'Munisipyo / Lungsod',
  'province': 'Probinsya',
  'farmName': 'Pangalan ng Bukid',
  'farmerType': 'Uri ng Magsasaka',
  'email': 'Email',
  'phoneNumber': 'Numero ng Telepono',
  'profileSaved': 'Na-update ang profile.',
  'selectLanguage': 'Pumili ng Wika',
  'selectTheme': 'Pumili ng Tema',
  'light': 'Maliwanag',
  'dark': 'Madilim',
  'system': 'Default ng system',

  // ── Shared / common ──
  'retry': 'Subukan Muli',
  'delete': 'Burahin',
  'edit': 'I-edit',
  'add': 'Idagdag',
  'close': 'Isara',
  'done': 'Tapos na',
  'yes': 'Oo',
  'no': 'Hindi',
  'ok': 'OK',
  'loading': 'Naglo-load...',
  'somethingWentWrong': 'May nagkamali. Pakisubukan muli.',
  'required': 'Kinakailangan',
  'optional': 'Opsyonal',
  'takePhoto': 'Kumuha ng Larawan',
  'chooseFromGallery': 'Pumili mula sa Gallery',
  'maxSizeNotice': 'Max 3 MB — awtomatikong nako-compress ang mga larawan.',

  // ── Dashboard drawer navigation ──
  'navDashboard': 'Dashboard',
  'navDailyTasks': 'Pang-araw-araw na Gawain',
  'navFeedingGuide': 'Gabay sa Pagpapakain',
  'navHealthMonitor': 'Health Monitor',
  'navHealthLogs': 'Talaan ng Kalusugan',
  'navWeightAdg': 'Timbang & ADG',
  'navPigGrowth': 'Paglaki ng Baboy',
  'navExpenseRoi': 'Gastos & ROI',
  'navVetContacts': 'Kontak ng Beterinaryo',
  'navCalendar': '120-Araw na Kalendaryo',
  'navSettings': 'Mga Setting',
  'navMyPigs': 'Aking mga Baboy',
  'navActivityLog': 'Talaan ng Aktibidad',
  'navLogOut': 'Mag-log Out',
  'navSectionMain': 'PANGUNAHIN',
  'navSectionRecords': 'MGA TALAAN',
  'navSectionAccount': 'ACCOUNT',

  // ── Dashboard screen chrome ──
  'dashboardTitle': 'Dashboard',
  'openMenu': 'Buksan ang menu',
  'openProfileTooltip': 'Buksan ang profile at mga setting',
  'switchLanguageTooltip': 'Palitan ang wika ng app',
  'upcomingReminders': 'Mga Paparating na Paalala',
  'healthTrend': 'Uso ng Kalusugan',
  'marketDayArrived': '🐷 Dumating na ang Market Day!',
  'couldNotLoadReminders': 'Hindi ma-load ang mga paalala.',
  'off': 'Naka-off',
  'dashboardLoadError': 'May problema sa pag-load ng iyong Dashboard.',
  'currentDay': 'Kasalukuyang Araw',
  'cycleComplete': 'Kumpleto na ang cycle',
  'daysLeft': 'araw na lang',
  'avgDailyGain': 'Karaniwang Pagtaas Araw-araw',
  'currentWeight': 'Kasalukuyang Timbang',
  'projectedNetProfit': 'Tinatayang Netong Kita',
  'noPigsYet': 'Wala pang baboy',
  'fcr': 'FCR',
  'growthPercent': 'Growth %',
  'adgExcellent': 'Napakahusay',
  'adgOnTrack': 'Nasa Tamang Track',
  'adgBelowTarget': 'Mababa sa Target',
  'adgNeedsAttention': 'Nangangailangan ng Pansin',
  'weeklyWeightRequired': 'Kailangan ng lingguhang timbang',
  'noWeeklyDataYet': 'Wala pang lingguhang datos',
  'thisWeekSuffix': 'kg ngayong linggo',

  // ── Dashboard redesign (2026 premium farm dashboard) ──
  'dashboardHeroSubtitle': 'Narito ang nangyayari sa iyong sakahan ngayon.',
  'daysOnTrack': 'Mga Araw sa Track',
  'tasksTodayStat': 'Mga Gawain Ngayon',
  'avgWeightStat': 'Karaniwang Timbang',
  'herdStatusStat': 'Kalagayan ng Kawan',
  'doneShortSuffix': 'Tapos',
  'leftShortSuffix': 'Natitira',
  'allGoodCaption': 'Maayos ang lahat!',
  'herdCaptionMonitor': 'Patuloy na bantayan',
  'herdCaptionRisk': 'Suriin agad',
  'herdCaptionCritical': 'Kumonsulta sa beterinaryo',
  'noHerdDataYetCaption': 'Wala pang datos',
  'herdOverviewTitle': 'Pangkalahatang-tanaw ng Kawan',
  'totalPigsLabel': 'Kabuuang Baboy',
  'activePigsLabel': 'Aktibong Baboy',
  'finisherLabel': 'Finisher',
  'growingLabel': 'Lumalaki',
  'healthSummaryLabel': 'Buod ng Kalusugan',
  'quickActionsTitle': 'Mabilisang Aksyon',
  'recordWeightAction': 'Itala ang Timbang',
  'healthCheckAction': 'Suriin ang Kalusugan',
  'feedingGuideAction': 'Gabay sa Pagpapakain',
  'expensesAction': 'Gastusin',
  'pigPhotosAction': 'Larawan ng Baboy',
  // ── Dashboard v2 (weather card, restyled summary grid, Health Overview
  // donut, grouped Today's Tasks) ──
  'activeAnimalsCaption': 'Aktibong Hayop',
  'growthProgressStat': 'Paglago',
  'targetWeightSuffix': ' kg na target',
  'humidityLabel': 'Halumigmig',
  'heatAlertLabel': 'Alerto sa Init:',
  'heatAlertModerate': 'Katamtaman',
  'heatAlertHigh': 'Mataas',
  'healthOverviewTitle': 'Pangkalahatang-tanaw ng Kalusugan',
  'overallStatusLabel': 'Pangkalahatang Kalagayan',
  'morningGroupLabel': 'Umaga',
  'eveningGroupLabel': 'Gabi',

  // ── Auth (Welcome / Login / Register) ──
  'appTagline': 'Administration for Swine Finisher',
  'appMotto': '"Mula Day-1 hanggang Market-Day"',
  'createAccount': 'Gumawa ng Account',
  'logIn': 'Mag-log In',
  'forgotPassword': 'Nakalimutan ang password?',
  'rememberMe': 'Tandaan ako',
  'sendCode': 'Ipadala ang Code',
  'welcomeBackTitle': 'Maligayang Pagbabalik',
  'welcomeBackLoginSubtitle':
      'Ipagpatuloy ang pagsubaybay sa iyong mga baboy, iskedyul ng pagpapakain, at mga rekord ng produksyon.',
  'newFarmerTitle': 'Bagong Magsasaka?',
  'newFarmerBody':
      'Gumawa ng ASF account para simulan ang pagsubaybay sa mga baboy ngayon.',
  'continueWithMobileOtp': 'Magpatuloy gamit ang Mobile OTP',
  'backToEmailLogin': 'Bumalik sa Email Login',
  'orDivider': 'O',
  'welcomeFeatureTasks': 'Subaybayan ang Araw-araw na Gawain',
  'welcomeFeatureHealth': 'Subaybayan ang Kalusugan',
  'welcomeFeaturePerformance': 'Pahusayin ang Performance',
  'welcomeSecurityFooter': 'Ligtas at pribado ang iyong datos',
  'mobileNumber': 'Numero ng Mobile',
  'password': 'Password',
  'showPassword': 'Ipakita ang password',
  'hidePassword': 'Itago ang password',
  'previousMonth': 'Nakaraang buwan',
  'nextMonth': 'Susunod na buwan',
  'refreshTooltip': 'I-refresh',
  'filterByDateTooltip': 'Salain ayon sa petsa',
  'clearDateFilterTooltip': 'Alisin ang filter ng petsa',
  'updateProfilePhotoTooltip': 'I-update ang larawan sa profile',
  'confirmPassword': 'Kumpirmahin ang Password',
  'municipalityProvince': 'Munisipyo, Probinsya',
  'enterValidEmail': 'Maglagay ng wastong email',
  'atLeast6Chars': 'Hindi bababa sa 6 na karakter',
  'passwordsDoNotMatch': 'Hindi magkatugma ang password',
  'enter11Digits': 'Maglagay ng eksaktong 11 digit (hal. 09171234567)',
  'mobileStartsWith0': 'Dapat magsimula sa 0 ang numero ng mobile',
  'mobileInvalidPrefix':
      'Maglagay ng wastong numero ng mobile sa Pilipinas (hal. 09171234567)',
  'emailTab': 'Email',
  'mobileOtpTab': 'Mobile OTP',
  'resetPasswordTitle': 'I-reset ang Password',
  'resetPasswordInstructions':
      'Ilagay ang email na ginamit mo sa pagrehistro. Magpapadala kami ng link para i-reset ang iyong password.',
  'sendResetLink': 'Ipadala ang Reset Link',
  'resetLinkSent': 'Naipadala na ang reset link. Tingnan ang iyong email.',
  'enterOtpTitle': 'Ilagay ang Verification Code',
  'enterOtpInstructions':
      'Ilagay ang 6-digit na code na ipinadala sa iyong mobile number.',
  'verifyCode': 'I-verify ang Code',
  'resendCode': 'Ipadala Muli ang Code',
  'resendCodeIn': 'Muling ipapadala ang code sa loob ng',
  'verifyYourNumber': 'I-verify ang Iyong Numero',
  'enterCodeSentTo': 'Ilagay ang 6-digit na code na ipinadala sa',
  'yourPhone': 'iyong telepono',
  'verify': 'I-verify',

  // ── Feature screen titles ──
  'healthHistoryTitle': 'Talaan ng Kalusugan',
  'feedingGuideTitle': 'Gabay sa Pagpapakain',
  'growthTitle': 'Paglaki at Performance',
  'weightAdgTitle': 'Timbang & ADG',
  'expenseRoiTitle': 'Gastos & ROI',
  'exportCsv': 'I-export ang CSV',
  'exportPdf': 'I-export ang PDF',

  // ── Health Monitor form ──
  'editObservation': 'I-edit ang Obserbasyon',
  'healthMonitorTitle': 'Health Monitor',
  'editingLogFrom': 'Ineedit ang talaan mula',
  'dailyObservationLog': 'Pang-araw-araw na talaan ng obserbasyon',
  'viewHealthLogs': 'Tingnan ang Talaan ng Kalusugan',
  'healthMonitorSubtitle': 'Subaybayan ang kalusugan ng iyong mga baboy',
  'todaysOverviewTitle': 'Buod Ngayong Araw',
  'notYetCheckedLabel': 'Hindi Pa Nasusuri',
  'startHealthMonitoringTitle': 'Simulan ang Pagsubaybay sa Kalusugan',
  'howWouldYouLikeToMonitor': 'Paano mo gustong magsuri?',
  'specificPigLabel': 'Tiyak na Baboy',
  'specificPigSubtitle': 'Suriin ang kalusugan ng isang baboy',
  'overallHerdLabel': 'Buong Kawan',
  'overallHerdSubtitle': 'Subaybayan ang maraming baboy',
  'healthCategoriesTitle': 'Mga Kategorya ng Kalusugan',
  'sevenDayTrendTitle': 'Takbo ng Kalusugan sa 7 Araw',
  'lastHealthCheckTitle': 'Huling Pagsusuri ng Kalusugan',
  'healthTipsTitle': 'Mga Tip sa Kalusugan',
  'noPigsAvailableMessage': 'Wala pang baboy. Magdagdag ng baboy para makapagsimula ng pagsusuri ng kalusugan.',
  'noHealthChecksMessage': 'Wala pang naitatalang pagsusuri ng kalusugan.',
  'startFirstHealthCheckMessage': 'Simulan ang iyong unang pagsusuri ng kalusugan.',
  'notEnoughTrendDataMessage': 'Wala pang sapat na datos ng takbo ng kalusugan.',
  'selectPigTitle': 'Pumili ng Baboy',
  'startHealthCheckButton': 'Simulan ang Pagsusuri ng Kalusugan',
  'howManyPigsQuestion': 'Ilang baboy ang gusto mong subaybayan?',
  'pigsToMonitorLabel': 'Mga Baboy na Susubaybayan',
  'selectPigsButton': 'Pumili ng mga Baboy',
  'selectPigsToMonitorTitle': 'Pumili ng mga Baboy na Susubaybayan',
  'pigsSelectedLabel': 'napiling baboy',
  'startHerdHealthCheckButton': 'Simulan ang Pagsusuri ng Kawan',
  'herdHealthSummaryTitle': 'Buod ng Kalusugan ng Kawan',
  'pigsMonitoredLabel': 'mga baboy na sinubaybayan',
  'attentionRequiredTitle': 'Kailangan ng Pansin',
  'attentionRequiredBody': 'May mga baboy na nangangailangan ng agarang atensyon.',
  'reviewCriticalPigsButton': 'Suriin ang mga Kritikal na Baboy',
  'reviewAtRiskPigsButton': 'Suriin ang mga Nanganganib na Baboy',
  'newHealthCheckButton': 'Bagong Pagsusuri ng Kalusugan',
  'unableToLoadHealthMessage': 'Hindi mai-load ang impormasyon ng kalusugan.',
  'noPigsSelectedYet': 'Wala pang napiling baboy',
  'pigOfLabel': 'Baboy',
  'healthMonitorNavLabel': 'Health Monitor',
  'allMonitoredPigsLabel': 'Lahat ng Sinusubaybayang Baboy',
  'unassignedLabel': 'Walang Baboy na Naitalaga',
  'herdExitConfirmTitle': 'Umalis sa pagsusuri ng kawan?',
  'herdExitConfirmBody': 'Mawawala ang progreso ng mga baboy na hindi pa nai-save.',
  'exitHerdCheckButton': 'Umalis',
  'healthTip1':
      'Suriin ang bawat baboy sa parehong oras araw-araw upang mas madaling mapansin ang pagbabago sa ugali.',
  'healthTip2':
      'Ang biglaang pagbaba ng gana sa pagkain ay kadalasang unang senyales ng problema — huwag maghintay pa na itala ito.',
  'healthTip3':
      'Ihiwalay ang baboy na nagpapakita ng malubha o emergency na sintomas habang naghahanda para sa pagbisita ng beterinaryo.',
  'notesOptional': 'Mga Tala (opsyonal)',
  'notesHint': 'Ilarawan ang anumang hindi pangkaraniwang obserbasyon...',
  'assessedByOptional': 'Sinuri ni (opsyonal)',
  'assessedByHint': 'Default sa iyong pangalan kung iiwan blangko',
  'saveObservation': 'I-save ang Obserbasyon sa Kalusugan',
  'selectOne': 'PUMILI NG ISA',
  'multipleSelect': 'MARAMIHANG PAGPILI',
  'noneSelected': 'Wala pang napili',
  'incompleteAssessmentTitle': 'Hindi Kumpleto ang Pagsusuri sa Kalusugan',
  'incompleteAssessmentBody':
      'Pakikumpleto ang lahat ng kinakailangang kategorya bago i-save.',
  'alreadyRecordedTitle': 'Naitala na',
  'alreadyRecordedBody': 'May naitala nang pagsusuri sa kalusugan para sa Araw',
  'editTodaysAssessment': 'I-edit ang Pagsusuri Ngayong Araw',
  'unfinishedAssessmentTitle': 'Hindi Tapos na Pagsusuri',
  'unfinishedAssessmentBody':
      'Ibalik ang iyong hindi tapos na pagsusuri sa kalusugan?',
  'discard': 'Itapon',
  'restore': 'Ibalik',
  'criticalHealthAlert': 'Kritikal na Alerto sa Kalusugan',
  'criticalAlertBody':
      'May isa o higit pang malalang sintomas na natukoy. Mahigpit na inirerekomenda ang agarang atensyon ng beterinaryo.',
  'callVeterinarian': 'Tawagan ang Beterinaryo',
  'viewContactList': 'Tingnan ang Listahan ng Kontak',
  'callNow': 'Tawagan Ngayon',
  'callConfirmPrefix': 'Tawagan',
  'healthSavedSnackbar':
      '✅ Na-save ang obserbasyon sa kalusugan. Kumpleto na ang pang-araw-araw na inspeksyon.',
  'tasksUnlocked': 'Na-unlock na gawain',
  'healthSummary': '📋 Buod ng Kalusugan',
  'behaviorLabel': 'Ugali',
  'appetiteLabel': 'Gana sa Pagkain',
  'physicalLabel': 'Pisikal',
  'wasteLabel': 'Dumi',
  'overallStatus': 'Kabuuang Katayuan',
  'severityCounts': 'Bilang ng Kalubhaan',
  'healthyChip': 'Malusog',
  'monitoringChip': 'Binabantayan',
  'atRiskChip': 'Nanganganib',
  'criticalChip': 'Kritikal',
  'reasonLabel': 'Dahilan',
  'recommendationLabel': 'Rekomendasyon',
  'healthyIndicators': 'Malusog na Palatandaan',
  'needsMonitoring': 'Kailangan ng Pagbabantay',
  'atRiskSection': 'Nanganganib',
  'criticalSection': 'Kritikal',
  'physicalCondition': '🩺 Kalagayang Pisikal',
  'searchHint': 'Maghanap...',
  'noRecordsFound': 'Walang nahanap na talaan.',
  'deleteHealthObsTitle': 'Burahin ang obserbasyon sa kalusugan na ito?',
  'deleteConfirmBody': 'Hindi na maibabalik ang aksyong ito.',
  'delete2': 'Burahin',

  // ── Health History ──
  'logHealth': 'Itala ang Kalusugan',
  'searchNotesHint': 'Maghanap ng mga tala o obserbasyon',
  'allChip': 'Lahat',
  'todayChip': 'Ngayon',
  'thisWeekChip': 'Ngayong Linggo',
  'thisMonthChip': 'Ngayong Buwan',
  'customDate': 'Custom na petsa',
  'clearCustomDateFilter': 'Alisin ang custom na filter ng petsa',
  'noHealthObsYet': 'Wala pang naitalang obserbasyon sa kalusugan.',
  'deleteObsBodyPrefix': 'Aalisin nito ang',
  'deleteObsBodySuffix': 'talaan. Hindi na maibabalik ito.',
  'goBack': 'Bumalik',
  'healthMonitorErrorTitle': 'Error sa Health Monitor',
  'healthMonitorErrorBody':
      'May problema sa pag-load ng iyong mga talaan ng kalusugan.',
  'skippedRecordsNotice':
      'May mga hindi wastong talaan ng kalusugan na na-ignore.',
  'batchLabel': 'Batch',
  'pigLabel': 'Baboy',
  'assessedByLabel': 'Sinuri ni',

  // ── Feeding Guide ──
  'addPigToSeeFeedingPlan':
      'Magdagdag ng baboy sa Pig Management para makita ang iyong feeding plan.',
  'addPigToLogTasks':
      'Magdagdag muna ng baboy sa Pig Management bago mag-log ng pang-araw-araw na gawain.',
  'todaysFeedingScheduleSection': 'Iskedyul ng Pagpapakain Ngayon',
  'morning': 'Umaga',
  'morningTimeHint': '7:30 – 8:00 AM',
  'afternoon': 'Hapon',
  'afternoonTimeHint': 'PM Feeding',
  'todaysFeedingSection': 'Pagpapakain Ngayon',
  'totalFeedTodayLabel': 'Kabuuang Pakain Ngayon',
  'feedingsCompletedLabel': 'Natapos na Pagpapakain',
  'dailyFeedingProgressSection': 'Pag-unlad ng Pagpapakain Ngayon',
  'goalAchievedLabel': 'Naabot ang Target',
  'feedCostCalculatorSection': 'Kalkulator ng Gastos sa Pakain',
  'feedStatisticsSection': 'Estadistika ng Pakain',
  'growthTimelineSection': 'Timeline ng Paglaki',
  'stageGuideSection': 'Gabay sa Stage',
  'feedRecommendationSection': 'Rekomendasyon sa Pakain',
  'feedingTipsSection': 'Mga Tip sa Pagpapakain',
  'todaysSummarySection': 'Buod Ngayon',
  'feedHistorySection': 'Talaan ng Pakain',
  'dayLabel': 'Araw',
  'couldNotLoadFeedingPlan': 'Hindi ma-load ang iyong feeding plan.',
  'editFeedPriceTitle': 'I-edit ang Presyo ng Pakain',
  'feedPriceHint': 'Presyo ng Pakain (₱ kada kg)',
  'feedPriceUpdated': 'Na-update ang presyo ng pakain.',
  'healthAlertTitle': '🚨 Alerto sa Kalusugan',
  'increasedMonitoringTitle':
      '⚠️ Inirerekomenda ang Mas Mahigpit na Pagbabantay',
  'healthAlertCriticalMsg':
      'Kritikal ang pinakabagong pagsusuri sa kalusugan. Tingnan ang Health Monitor bago magpatuloy sa pagpapakain ngayon.',
  'healthAlertRiskMsg':
      'Dapat samahan ng mas malapit na pagmamasid ang pagpapakain ngayon.',
  'currentFeedingPlan': '🐷 KASALUKUYANG PLANO SA PAGPAPAKAIN',
  'productionDayPrefix': 'Araw ng Produksyon',
  'currentWeightLabel': 'Kasalukuyang Timbang',
  'dailyFeedLabel': 'Pang-araw-araw na Pakain',
  'targetWeightLabel': 'Target na Timbang',
  'remainingLabel': 'Natitira',
  'expectedDailyGainLabel': 'Inaasahang Pagtaas Araw-araw',
  'estimatedNextStageLabel': 'Tinatayang Susunod na Stage',
  'daysRemainingSuffix': 'Araw na Natitira',
  'nextStagePrefix': 'Susunod na Stage:',
  'marketReady': 'Handa na sa Market',
  'fedLabel': 'Napakain',
  'notYetFedLabel': 'Hindi Pa Napakain',
  'completionLabel': 'Pagkumpleto',
  'dailyFeedingCompleteBanner': '🎉 Kumpleto na ang Pagpapakain Ngayon',
  'completedLabel': 'Nakumpleto',
  'pendingLabel': 'Nakabinbin',
  'feedPricePerKgLabel': 'Presyo ng Pakain (kada kg)',
  'todaysFeedLabel': 'Pakain Ngayon',
  'todaysCostLabel': 'Gastos Ngayon',
  'thirtyDayEstLabel': 'Tantiya sa 30-Araw',
  'thisWeekLabel': 'Ngayong Linggo',
  'estThisMonthLabel': 'Tantiya Ngayong Buwan',
  'doneCaption': 'Tapos na',
  'currentCaption': 'Kasalukuyan',
  'nextCaption': 'Susunod',
  'upcomingCaption': 'Paparating',
  'reachedCaption': 'Naabot na',
  'finalGoalCaption': 'Huling Layunin',
  'stageColHeader': 'Stage',
  'weightColHeader': 'Timbang',
  'feedPerDayColHeader': 'Pakain/Araw',
  'statusColHeader': 'Katayuan',
  'passedStatus': 'Nakalipas',
  'feedTypeEarly': 'Grower/Finisher feed, 16–18% crude protein',
  'feedTypeMid': 'Finisher feed, 14–16% crude protein',
  'feedTypeLate': 'Finisher feed, 13–15% crude protein',
  'feedTypeLabel': 'Uri ng Pakain',
  'waterLabel': 'Tubig',
  'waterAdLibitum':
      'Malinis na tubig na available sa lahat ng oras (ad libitum)',
  'todaysRecommendation': 'Rekomendasyon Ngayon',
  'recoHealthyBullet': 'Ipagpatuloy ang normal na iskedyul ng pagpapakain.',
  'recoMonitorBullet1': 'Obserbahang mabuti ang pag-inom ng pakain.',
  'recoMonitorBullet2':
      'Kung hindi natapos ng baboy ang ration ngayon, itala muli ang gana sa pagkain bukas.',
  'recoRiskBullet1':
      'Nagpakita ang baboy ng mga senyales na nangangailangan ng mas malapit na pagmamasid.',
  'recoRiskBullet2':
      'Panatilihin ang inirekomendang dami ng pakain maliban kung may ibang payo ang beterinaryo.',
  'recoRiskBullet3':
      'Bantayan ang gana sa pagkain at hydration sa bawat pagpapakain.',
  'recoCriticalBullet1': 'May natukoy na kritikal na kondisyon.',
  'recoCriticalBullet2':
      'Kumonsulta agad sa beterinaryo bago baguhin ang programa ng pagpapakain.',
  'recoCriticalBullet3': 'Ipagpatuloy ang pagbibigay ng malinis na tubig.',
  'recoCriticalBullet4': 'Itala ang lahat ng obserbasyon.',
  'feedAllowanceLabel': 'Allowance ng Pakain',
  'waterUnlimited': 'Walang limitasyong malinis na tubig',
  'waterEnsureConstant': 'Tiyaking may patuloy na access.',
  'feedTip1':
      'Magpakain sa parehong oras araw-araw para manatiling kalmado ang mga baboy at mabawasan ang stress.',
  'feedTip2':
      'Palaging maglagay ng pakain sa malinis at tuyong sisidlan para maiwasan ang pagkasira at pag-aaksaya.',
  'feedTip3':
      'Bantayan ang natitirang pakain — maaaring senyales ito ng nabawasang gana na dapat suriin sa Health Monitor.',
  'feedTip4':
      'Unti-unting ayusin ang dami ng pakain kapag lumilipat sa ibang growth stage.',
  'weightLabel': 'Timbang',
  'feedLabel': 'Pakain',
  'costLabel': 'Gastos',
  'nextFeedingLabel': 'Susunod na Pagpapakain',
  'statusLabel': 'Katayuan',
  'morningFeeding': 'Pagpapakain sa Umaga',
  'afternoonFeeding': 'Pagpapakain sa Hapon',
  'noneBothDone': 'Wala — pareho nang tapos',
  'completeStatus': 'Kumpleto ✓',
  'inProgressStatus': 'Isinasagawa',
  'notStartedStatus': 'Hindi Pa Nagsisimula',

  // ── Weight & ADG ──
  'somethingWentWrongLoadingGrowth':
      'May problema sa pag-load ng datos ng Paglaki.',
  'syncedWithMobileApp': 'Naka-sync sa mobile app',
  'thisWeeksAdg': 'ADG NGAYONG LINGGO',
  'poorTier': 'Mahina',
  'healthyTier': 'Malusog',
  'noDataYet': 'Wala pang datos',
  'targetRangeLabel': 'Target Range:',
  'feedConversionRatioTitle': 'FEED CONVERSION RATIO (FCR)',
  'goodTier': 'Mabuti',
  'needsImprovementTier': 'Kailangan ng Pagpapabuti',
  'thisWeeksFcr': 'FCR Ngayong Linggo',
  'thisWeeksFcrTrend': 'USO NG FCR NGAYONG LINGGO',
  'lowerFcrBetterNotice':
      'Mas mababang halaga ay nangangahulugan ng mas magandang feed efficiency.',
  'weekPrefix': 'Linggo',
  'recordNewWeightTitle': 'Itala ang Bagong Timbang',
  'recordForWeekLabel': 'Itatala para sa',
  'addNotesOptional': '+ Magdagdag ng tala (opsyonal)',
  'enterValidWeightKg': 'Maglagay ng wastong timbang sa kg.',
  'replaceThisWeeksWeighInTitle': 'Palitan ang timbang ngayong linggo?',
  'weighInExistsPrefix': 'May umiiral nang timbang para sa Linggo',
  'replaceWithSuffix': 'Palitan ito ng',
  'weeklyPhotoUnlocksSuffix': 'na larawan ay magiging available sa Araw',
  'replaceButton': 'Palitan',
  'weighInHistoryTitle': 'TALAAN NG PAGTITIMBANG',
  'noWeightRecordsYet': 'Wala pang talaan ng timbang.',
  'baselineLabel': 'Baseline',
  'fcrHistoryTitle': 'TALAAN NG FCR',
  'feedConsumedPrefix': 'Nagamit na Pakain:',
  'deleteWeighInTitle': 'Burahin ang timbang na ito?',
  'deleteWeighInBodyPrefix': 'Aalisin nito ang talaan ng Linggo',
  'deleteWeighInBodyMiddle': 'entry (',
  'deleteWeighInBodySuffix': 'kg). Hindi na maibabalik ito.',
  'editWeighInTitle': 'I-edit ang Timbang',
  'weightKgLabel': 'Timbang (kg)',
  'trackHerdsGrowthSubtitle':
      'Subaybayan ang paglaki at timbang ng iyong kawan.',
  'weeklyGainLabel': 'Lingguhang Dagdag',
  'averageWeightLabel': 'Karaniwang Timbang',
  'lastWeighInLabel': 'Huling Pagtitimbang',
  'progressToTargetLabel': 'Pag-unlad Patungo sa Target',
  'onTrackLabel': 'Nasa Tamang Landas',
  'weightProgressSectionTitle': 'Pag-unlad ng Timbang',
  'notEnoughDataYetTitle': 'Kulang pa ang datos',
  'notEnoughDataYetFcrBody':
      'Magtala ng karagdagang impormasyon sa pagpapakain at timbang para makita ang trend.',
  'todayLabel': 'Ngayon',

  // ── Growth Overview ──
  'growthProgressTitle': 'Pag-unlad ng Paglaki',
  'growthPctRequiredNotice':
      'Kailangan ng lingguhang timbang para makalkula ang growth %.',
  'progressTowardMarketWeight': 'Pag-unlad patungo sa timbang para sa market',
  'percentOfWayToMarket': 'ng daan patungo sa timbang para sa market',
  'couldNotLoadGrowthData': 'Hindi ma-load ang datos ng Paglaki.',
  'adgTrendTitle': 'Uso ng ADG',
  'fcrTrendTitle': 'Uso ng FCR',
  'notEnoughWeeklyWeighIns': 'Hindi sapat ang lingguhang pagtitimbang.',
  'currentWeekLabelShort': 'Kasalukuyang Linggo',
  'currentDayLabelShort': 'Kasalukuyang Araw',
  'recordWeeklyWeightLabel': 'Itala ang Lingguhang Timbang',
  'noWeeklyWeighInsYetTitle': 'Wala pang lingguhang pagtitimbang.',
  'noWeeklyWeighInsYetBody':
      'Itala ang iyong unang lingguhang timbang para simulan ang pagsubaybay sa paglaki ng iyong baboy.',
  'goToWeightRecordsLabel': 'Pumunta sa Mga Talaan ng Timbang',
  'weeklyGrowthTimelineTitle': 'Lingguhang Timeline ng Paglaki',
  'weekCompleteLabel': 'tapos na',
  'weekCurrentLabel': 'kasalukuyang linggo',

  // ── Growth Overview redesign ──
  'growthPerformanceSubtitle':
      'Subaybayan ang paglaki, performance, at pag-unlad ng iyong mga baboy.',
  'growthOverviewLabel': 'BUOD NG PAGLAKI',
  'growthStatusStarting': 'Bagong simula pa lang',
  'growthStatusSteady': 'Regular na lumalaki',
  'growthStatusAlmostThere': 'Malapit na',
  'growthStatusReady': 'Handa na para sa merkado',
  'vsLastRecordLabel': 'kumpara sa huling talaan',
  'vsPreviousPeriodLabel': 'kumpara sa nakaraang linggo',
  'actualWeightLegend': 'Aktwal na Timbang',
  'notEnoughGrowthDataBody':
      'Magtala ng karagdagang lingguhang pagtitimbang para makita ang tsart ng paglaki.',
  'averageDailyGainSectionTitle': 'KARANIWANG ARAW-ARAW NA DAGDAG',
  'kgFeedPerKgGainLabel': 'kg pakain / kg dagdag',
  'thisWeeksPerformanceTitle': 'PERFORMANCE NGAYONG LINGGO',
  'weightGainLabel': 'Dagdag na Timbang',
  'performanceTrendLabel': 'Uso ng Performance',
  'productionStageTitle': 'YUGTO NG PRODUKSYON',
  'estimatedTransitionLabel': 'Tinatayang paglipat',
  'growthMilestonesTitle': 'MGA MILESTONE NG PAGLAKI',
  'startingWeightMilestoneLabel': 'Simulang Timbang',
  'currentStageMilestoneLabel': 'Kasalukuyang Yugto',
  'upcomingLabel': 'Paparating',
  'marketReadyLabel': 'Handa na sa Merkado',
  'viewAllHistoryLabel': 'Tingnan lahat ng kasaysayan',
  'recordWeightActionTitle': 'Itala ang Timbang',
  'recordWeightActionSubtitle':
      'Magdagdag ng bagong timbang at i-update ang datos ng paglaki',
  'adgLabel': 'ADG',
  'fcrLabel': 'FCR',
  'growthAnalyticsSectionTitle': 'Pagsusuri ng Paglaki',
  'trendImprovingLabel': 'Bumubuti',
  'trendDecliningLabel': 'Bumababa',
  'trendStableLabel': 'Matatag',
  'fromLastWeekSuffix': 'mula noong nakaraang linggo',

  // ── Expense & ROI ──
  'liveCostTracking': 'Live na pagsubaybay ng gastos',
  'noExpensesRecordedYet': 'Wala pang naitalang gastos.',
  'expenseBreakdownSection': 'BREAKDOWN NG GASTOS',
  'recentEntriesSection': 'MGA KAMAKAILANG ENTRY',
  'somethingWentWrongLoadingExpenses': 'May problema sa pag-load ng Gastos.',
  'expenseUpdatedSnackbar': 'Na-update ang gastos.',
  'expenseAddedSnackbar': 'Naidagdag ang gastos.',
  'deleteExpenseTitle': 'Burahin ang gastos na ito?',
  'deleteExpenseBodyPrefix': 'Aalisin nito ang',
  'deleteExpenseBodySuffix': '. Hindi na maibabalik ito.',
  'expenseDeletedSnackbar': 'Nabura ang gastos.',
  'totalSpentLabel': 'KABUUANG GINASTOS',
  'moreOptionsTitle': 'Higit Pang Pagpipilian',
  'financialSummarySection': 'BUOD NG PINANSYAL',
  'projectedRevenueLabel': 'Tinatayang Kita',
  'totalExpensesLabel': 'Kabuuang Gastos',
  'netProfitLabel': 'Netong Kita',
  'roiPercentLabel': 'ROI %',
  'noExpensesYetTitle': 'Wala pang gastos',
  'tapAddFirstExpense':
      'Pindutin ang + na buton para itala ang iyong unang gastos.',
  'addExpenseButton': 'Magdagdag ng Gastos',
  'editExpenseTitle': 'I-edit ang Gastos',
  'descriptionLabel': 'Deskripsyon',
  'descriptionHint': 'hal. Finisher Feed (50 kg sack)',
  'amountPesoLabel': 'Halaga (₱)',
  'dateUpperLabel': 'PETSA',
  'additionalRemarksHint': 'Karagdagang mga tala...',
  'saveChanges': 'I-save ang mga Pagbabago',
  'saveExpense': 'I-save ang Gastos',
  'amountMustBeGreaterThanZero': 'Ang halaga ay dapat higit sa 0.',

  // ── Expense & ROI redesign v2 (green hero / financial stats / donut /
  // ROI Analytics) ──
  'expenseOverviewEyebrow': 'BUOD NG GASTOS',
  'thisProductionCycleLabel': 'Sa produksyon ngayong cycle',
  'financialStatisticsSection': 'MGA ISTATISTIKANG PINANSYAL',
  'avgDailyCostLabel': 'Karaniwang Gastos Araw-araw',
  'costSuffixLabel': 'Gastos',
  'notEnoughExpenseDataYet': 'Hindi pa sapat ang datos ng gastos',
  'notEnoughExpenseDataBody':
      'Magdagdag ng ilang gastos para makita ang breakdown ayon sa kategorya.',
  'roiAnalyticsTitle': 'ROI Analytics',
  'viewRoiAnalyticsLabel': 'Tingnan ang ROI Analytics',
  'profitabilityOverviewSection': 'BUOD NG KITA',
  'costVsRevenueTrendSection': 'TREND NG GASTOS VS KITA',
  'totalRoiLabel': 'Kabuuang ROI',
  'categorySectionLabel': 'Kategorya',
  'addExpenseScreenSubtitle': 'Magtala ng bagong gastos sa cycle na ito',
  'editExpenseScreenSubtitle': 'I-update ang detalye ng gastos na ito',
  'revenueLabel': 'Kita',
  'liveCostTrackingSubtitle':
      'Live na pagsubaybay ng gastos para sa mas matalinong desisyon sa bukid.',
  'totalLabel': 'Kabuuan',

  'categoryFeed': 'Pakain',
  'categoryMedicine': 'Gamot',
  'categoryVaccines': 'Bakuna',
  'categoryVitamins': 'Bitamina',
  'categoryTransportation': 'Transportasyon',
  'categoryLabor': 'Lakas-paggawa',
  'categoryUtilities': 'Utilities',
  'categoryEquipment': 'Kagamitan',
  'categoryOther': 'Iba pa',

  // ── Pig Calendar ──
  'calendarSuffix': 'Kalendaryo',
  'pigFallback': 'Baboy',
  'growthTimelineSectionUpper': 'TIMELINE NG PAGLAKI',
  'noWeeklyPhotosYet': 'Wala pang naitalang lingguhang larawan.',
  'couldNotLoadCalendar': 'Hindi ma-load ang kalendaryo.',
  'hasPhotoLegend': 'May Larawan',
  'noPhotoLegend': 'Walang Larawan',
  'todayLegend': 'Ngayon',
  'noImageUploaded': 'Walang na-upload na larawan',
  'uploadedPrefix': 'Na-upload:',

  // ── Add/Edit Pig ──
  'editPigTitle': 'I-edit ang Baboy',
  'addPigTitle': 'Magdagdag ng Baboy',
  'pigInformationSection': 'IMPORMASYON NG BABOY',
  'pigIdLabel': 'Pig ID',
  'pigNameLabel': 'Pangalan ng Baboy',
  'breedLabel': 'Lahi',
  'breedHint': 'hal. Landrace Cross',
  'genderLabel': 'Kasarian',
  'maleLabel': 'Lalaki',
  'femaleLabel': 'Babae',
  'scheduleSection': 'ISKEDYUL',
  'arrivalDateLabel': 'Petsa ng Pagdating',
  'birthDateLabel': 'Petsa ng Kapanganakan',
  'productionSection': 'PRODUKSYON',
  'initialWeightKgLabel': 'Paunang Timbang (kg)',
  'editStartingWeightHelper':
      'Gamitin ang "Edit Starting Weight" sa Growth History para baguhin ito.',
  'enterValidWeight': 'Maglagay ng wastong timbang',
  'penNumberLabel': 'Numero ng Kulungan',
  'penNumberHint': 'hal. Pen 4',
  'photoUploadSection': 'PAG-UPLOAD NG LARAWAN',
  'mmddyyyyPlaceholder': 'mm/dd/yyyy',
  'saveChangesButton': 'I-save ang mga Pagbabago',
  'savePigButton': 'I-save ang Baboy',

  // Pig Growth Dashboard (pig_list_screen.dart)
  'pigGrowthTitle': 'Paglaki ng Baboy',
  'weeklyPhotoTrackingSubtitle':
      'Lingguhang pagsubaybay ng larawan para sa bawat baboy',
  'registeredPigsSection': 'MGA NAKAREHISTROONG BABOY',
  'couldNotLoadPigs': 'Hindi ma-load ang iyong mga baboy.',
  'deleteThisPigTitle': 'Burahin ang baboy na ito?',
  'deletePigBodyPrefix': 'Aalisin nito si',
  'deletePigBodySuffix':
      'at ang kanyang lingguhang mga larawan. Hindi na ito maibabalik.',
  'weeksRecordedStat': 'MGA NAITALANG LINGGO',
  'latestUploadStat': 'PINAKABAGONG PAG-UPLOAD',
  'completionStat': 'PAGKAKUMPLETO',
  'growthPhotosStat': 'MGA LARAWAN NG PAGLAKI',
  'addPigButton': 'Magdagdag ng Baboy',
  'searchPigHint': 'Maghanap sa pamamagitan ng Pangalan o ID ng Baboy',
  'filterAllPigs': 'Lahat ng Baboy',
  'filterActive': 'Aktibo',
  'filterCompletedGrowth': 'Tapos na ang Paglaki',
  'filterMale': 'Lalaki',
  'filterFemale': 'Babae',
  'sortByLabel': 'Ayusin ayon sa',
  'sortName': 'Pangalan',
  'sortAge': 'Edad',
  'sortLatestUpload': 'Pinakabagong Pag-upload',
  'sortWeight': 'Timbang',
  'noPigRecordsTitle': 'Wala Pang Talaan ng Baboy',
  'noPigRecordsBody':
      'Wala ka pang naidagdag na baboy. I-tap ang Magdagdag ng Baboy sa itaas para gawin ang una mong baboy.',
  'unknownBreed': 'Hindi kilalang lahi',
  'ageMetricLabel': 'EDAD',
  'weightMetricLabel': 'TIMBANG',
  'lastUploadMetricLabel': 'HULING PAG-UPLOAD',
  'weeksMetricLabel': 'LINGGO',
  'daysUnit': 'araw',
  'wksUnit': 'ling.',
  'growthProgressLabel': 'Progreso ng Paglaki',
  'weeksCompletedSuffix': 'Linggong Nakumpleto',
  'viewGrowthButton': 'Tingnan ang Paglaki →',
  'statusActive': 'Aktibo',
  'statusInProgress': 'Kasalukuyang Isinasagawa',
  'statusCompleted': 'Tapos Na',
  'statusNoPhotosYet': 'Wala Pang Larawan',

  // Growth History (pig_detail_screen.dart)
  'growthHistoryTitle': 'Kasaysayan ng Paglaki',
  'calendarViewTooltip': 'Tanawin ng Kalendaryo',
  'editPigTooltip': 'I-edit ang Baboy',
  'pigNotFoundMessage': 'Hindi nahanap ang baboy.',
  'couldNotLoadWeightRecords': 'Hindi ma-load ang mga talaan ng timbang.',
  'couldNotLoadThisPig': 'Hindi ma-load ang baboy na ito.',
  'addNoteTooltip': 'Magdagdag ng Tala',
  'takePhotoBeforeNoteMessage':
      'Kumuha ng larawan para sa linggong ito bago magdagdag ng tala.',
  'noteForWeekPrefix': 'Tala para sa Linggo',
  'addGrowthNoteHint': 'Magdagdag ng tala sa paglaki...',
  'uploadingPhotoMessage': 'Ina-upload ang larawan…',
  'imageExceeds3MbMessage':
      'Lumagpas sa 3 MB ang larawan. Pumili ng ibang larawan.',
  'startingWeightPrefix': 'Paunang Timbang:',
  'growthChartSection': 'TSART NG PAGLAKI',
  'recordTwoWeightsNotice':
      'Mag-record ng hindi bababa sa dalawang timbang para makita ang trend.',
  'firstWeightLegend': 'Unang Timbang',
  'latestWeightLegend': 'Pinakabagong Timbang',
  'weightTimelineSection': 'TIMELINE NG TIMBANG',
  'sinceLastWeighInSuffix': 'mula sa huling pagtimbang',
  'weeklyProgressPhotosSection': 'LINGGUHANG LARAWAN NG PROGRESO',
  'noGrowthPhotosYet': 'Wala pang na-upload na larawan ng paglaki.',
  'startTrackingPigNotice':
      'Simulan ang pagsubaybay sa baboy na ito sa pag-upload ng kauna-unahang lingguhang larawan.',
  'uploadPhotoButton': 'Mag-upload ng Larawan',
  'growthComparisonSection': 'PAGHAHAMBING NG PAGLAKI',
  'uploadAnotherWeekNotice':
      'Mag-upload ng larawan ng ibang linggo\npara ihambing ang paglaki.',
  'weekALabel': 'Linggo A',
  'weekBLabel': 'Linggo B',
  'selectTwoWeeksNotice':
      'Pumili ng dalawang linggo na may larawan para ihambing.',
  'noImageAvailableMessage': 'Walang available na larawan.',
  'notesSection': 'MGA TALA',
  'noNotesAddedYet': 'Wala pang naidagdag na tala.',

  // ── Pig Growth redesign (pig_list_screen.dart / pig_detail_screen.dart) ──
  'trackPigsGrowthSubtitle':
      'Subaybayan ang paglaki at lingguhang pag-unlad ng iyong mga baboy.',
  'weeksRecordedCaption': 'Naitalang Linggo',
  'latestUpdateCaption': 'Huling Update',
  'completionCaption': 'Pagkumpleto',
  'growthPhotosCaption': 'Larawan ng Paglaki',
  'statusLabelCaption': 'Katayuan',
  'weeksRemainingSuffix': 'linggo na natitira',
  'herdGrowthSectionTitle': 'Paglaki ng Kawan',
  'herdGrowthDisclaimer':
      'Ang timbang, ADG, at FCR ay itinatala isang beses bawat batch ng produksyon at ibinabahagi sa lahat ng baboy.',
  'remainingSuffix': 'natitira',
  'weeklyProgressSectionTitle': 'Lingguhang Progreso',
  'latestPhotoSectionTitle': 'Pinakabagong Larawan',
  'viewAllLabel': 'Tingnan Lahat',
  'informationSectionTitle': 'Impormasyon',
  'dateOfBirthLabel': 'Petsa ng Kapanganakan',
  'penAreaLabel': 'Kulungan / Lugar',
  'notesFieldLabel': 'Mga Tala',
  'noNotesRecorded': 'Walang naitalang tala',
  'actionsSectionTitle': 'Mga Aksyon',
  'addPhotoActionLabel': 'Magdagdag ng Larawan',
  'editPigActionLabel': 'I-edit ang Baboy',
  'deletePigActionLabel': 'Burahin ang Baboy',
  'unableToLoadGrowthData': 'Hindi ma-load ang datos ng paglaki.',
  'tryAgainButton': 'Subukan Muli',
  'noGrowthRecordsYetTitle': 'Wala pang talaan ng paglaki',
  'noGrowthRecordsYetBody':
      'Itala ang unang timbang para simulan ang pagsubaybay sa pag-unlad ng baboy na ito.',
  'noPhotosUploadedYetTitle': 'Wala pang na-upload na larawan',
  'noPhotosUploadedYetBody':
      'Magdagdag ng lingguhang larawan para subaybayan ang biswal na pag-unlad.',
  'startTrackingHerdBody':
      'Simulan ang pagsubaybay sa iyong kawan sa pamamagitan ng pagdaragdag ng iyong unang baboy.',

  // ── Production-readiness translation sweep (round 2) ──
  'otaUpdateAvailable': 'May Bagong Update',
  'otaLater': 'Mamaya Na',
  'otaUpdateNow': 'I-update Ngayon',
  'otaDefaultNotes': 'Mga pagpapabuti at ayos sa bug.',
  'activityLogTitle': 'Talaan ng Aktibidad',
  'searchDescriptionHint': 'Maghanap ng paglalarawan...',
  'noActivityFound': 'Walang nahanap na aktibidad.',
  'couldNotLoadActivityLog': 'Hindi ma-load ang talaan ng aktibidad.',
  'allFilter': 'Lahat',
  'notYetSyncedTooltip': 'Hindi pa naka-sync sa cloud',
  'aboutDescription':
      'Isang mobile application para sa pamamahala ng bukid ng baboy, para sa pagsubaybay at paggabay '
          'sa pagpapalaki ng swine finisher sa buong 120-araw na siklo ng produksyon.',
  'versionLabel': 'Bersyon',
  'developerLabel': 'Developer',
  'institutionLabel': 'Institusyon',
  'campusLabel': 'Kampus',
  'couldNotLoadImage': 'Hindi ma-load ang larawang iyon. Subukan ang iba.',
  'updateProfilePhotoTitle': 'I-update ang Larawan sa Profile',
  'maxSizeCompressed':
      'Pinakamataas na 3 MB — awtomatikong nako-compress ang mga larawan.',
  'chooseGallery': 'Pumili mula sa Gallery',
  'farmerTypeBackyard': 'Backyard na Nagpapalaki',
  'farmerTypeCommercial': 'Komersyal na Nagpapalaki',
  'farmerTypeSemiCommercial': 'Semi-Komersyal',
  'farmerTypeHobbyist': 'Hobbyist',
  'fullOverviewTitle': 'Buong 120-Araw na Pagsusuri',
  'ofLabel': 'ng',
  'daysCompletedSuffix': 'araw na natapos',
  'completedLegend': 'Tapos na',
  'upcomingLegend': 'Darating',
  'dailyActivitiesTitle': 'Pang-araw-araw na Gawain',
  'completeAllTasksSuffix': 'Kumpletuhin ang lahat ng gawain para sumulong',
  'doneSuffix': 'Tapos na',
  'somethingWentWrongTasks':
      'May nangyaring mali sa pag-load ng iyong mga gawain.',
  'morningRoutine': 'GAWAIN SA UMAGA',
  'eveningRoutine': 'GAWAIN SA GABI',
  'taskLockedTitle': '🔒 Naka-lock ang Gawain',
  'taskLockedBody':
      'Kailangan ng pagsusuri sa Health Monitor bago makumpleto ang gawaing ito.\n\n'
          'Kumpletuhin muna ang Health Monitor para ma-unlock ang gawaing ito.',
  'goToHealthMonitor': 'Pumunta sa Health Monitor',
  'lockTask10Message':
      'Kumpletuhin ang Vitality Inspection, Respiratory Check, at Temp & Ventilation bago itala ang mga talaan ngayong araw.',
  'vetContactsTitle': 'Mga Kontak ng Beterinaryo',
  'keepContactsBanner':
      'Itago rin dito ang iba pang emergency contact para isang tap lang ang layo.',
  'yourVeterinarian': 'Iyong Beterinaryo',
  'savedContactFallback': 'Naka-save na kontak',
  'noVetSavedYet':
      'Wala pang naka-save na beterinaryo. Magdagdag para direktang matawagan ng Critical Health Alert.',
  'callLabel': 'Tumawag',
  'editLabel': 'I-edit',
  'addContactLabel': 'Magdagdag ng Kontak',
  'veterinarianContactTitle': 'Kontak ng Beterinaryo',
  'nameOptionalLabel': 'Pangalan (opsyonal)',
  'municipalAgOfficeTitle': 'Munisipal / Tanggapan ng Agrikultura ng Lungsod',
  'municipalAgOfficeDesc':
      'Pag-uulat ng pagsiklab ng sakit (kabilang ang ASF) at access sa mga lokal na programa ng suporta sa hayupan.',
  'provincialVetOfficeTitle': 'Tanggapan ng Beterinaryo ng Probinsya',
  'provincialVetOfficeDesc':
      'Sangguniang punto para sa hinihinalang pagsiklab ng sakit o kapag kailangan ng suporta ang iyong lokal na beterinaryo.',
  'feedSupplyStoreTitle': 'Tindahan ng Feed at Suplay',
  'feedSupplyStoreDesc':
      'Para sa feed, suplemento, at pangunahing gamit na beterinaryo.',
  'vetSectionVeterinarians': 'Mga Beterinaryo',
  'vetSectionAgTechnicians': 'Mga Teknisyan sa Agrikultura',
  'vetSectionEmergencyHotlines': 'Mga Emergency Hotline',
  'vetBadgeVet': 'Beterinaryo',
  'vetBadgeAnimalHealthOfficer': 'Opisyal ng Kalusugan ng Hayop',
  'vetBadgeAgTech': 'Teknisyan sa Agrikultura',
  'vetBadgeEmergency': 'Emergency Hotline',
  'callNowLabel': 'Tumawag Ngayon',
  'numberNotListedLabel': 'Walang nakalistang numero',
  'goodMorning': 'Magandang Umaga',
  'goodAfternoon': 'Magandang Hapon',
  'goodEvening': 'Magandang Gabi',
  'cycleCompleteLabel': 'Tapos na ang siklo ng produksyon! 🎉',
  'calendarPillLabel': 'Kalendaryo',
  'logTodayLabel': 'Itala Ngayon',
  'completeTasksFirstSnackbar': '❌ Kumpletuhin muna ang lahat ng gawain!',
  'incompleteTasksDialogBody':
      'May mga gawain ka pa na hindi pa tapos ngayong araw. Pumunta sa Mga Gawain para tapusin ang mga ito?',
  'goToTasks': 'Pumunta sa Mga Gawain',
  'completeExclaim': 'Tapos na! 🎉',
  'proceedToDayPrefix': 'Magpatuloy sa Araw',
  'farmerFallback': 'Magsasaka',
  'retryLoadingNameLabel': 'Pindutin para subukan ulit ang pangalan',
  'noHealthObservationsYet': 'Wala pang obserbasyon sa kalusugan',
  'logTodayHealthCheckSubtitle':
      'Itala ang pagsusuri ng Ugali/Gana sa Pagkain/Pisikal/Dumi ngayong araw.',
  'healthNotLoggedYetTitle': 'Kalusugan Ngayong Araw · Hindi pa naitatala',
  'lastRecordedPrefix': 'Huling naitala:',
  'onDayLabel': 'sa Araw',
  'logTodayCheckToStayOnTrack':
      'Itala ang pagsusuri ngayong araw para mapanatili ang takbo.',
  'noneRecorded': 'Walang naitala',
  'todaysHealthLabel': 'Kalusugan Ngayong Araw',
  'vetRecommendedSuffix': 'Inirerekomenda ang Beterinaryo',
  'lastAssessmentLabel': 'Huling Pagsusuri',
  'todayAtLabel': 'Ngayong araw',
  'tipOfTheDay': 'Payo ng Araw',
  'tipOfDayText':
      'Siguraduhing laging available ang sariwang tubig. Umiinom ang mga baboy ng 2–3× na mas marami kaysa sa kanilang kinakain araw-araw.',
  'todaysTasksTitle': 'Mga Gawain Ngayong Araw',
  'progressLabel': 'Pag-unlad',
  'completedTasksLabel': 'MGA NATAPOS NA GAWAIN',
  'pendingTasksLabel': 'MGA NAKABINBIN NA GAWAIN',
  'noTasksCompletedYet': 'Wala pang natatapos na gawain',
  'allDoneLabel': 'Tapos na lahat! 🎉',
  'viewAllTasksLabel': 'Tingnan Lahat ng Gawain →',
};

const List<String> _monthNamesEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const List<String> _monthNamesFil = [
  'Enero',
  'Pebrero',
  'Marso',
  'Abril',
  'Mayo',
  'Hunyo',
  'Hulyo',
  'Agosto',
  'Setyembre',
  'Oktubre',
  'Nobyembre',
  'Disyembre',
];
const List<String> _weekdayLabelsEn = [
  'SUN',
  'MON',
  'TUE',
  'WED',
  'THU',
  'FRI',
  'SAT'
];
const List<String> _weekdayLabelsFil = [
  'LIN',
  'LUN',
  'MAR',
  'MIY',
  'HUW',
  'BIY',
  'SAB'
];
const List<String> _monthAbbrevEn = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];
const List<String> _monthAbbrevFil = [
  'Ene',
  'Peb',
  'Mar',
  'Abr',
  'May',
  'Hun',
  'Hul',
  'Ago',
  'Set',
  'Okt',
  'Nob',
  'Dis'
];

/// Full month names (index 0 = January), localized.
List<String> monthNames(AppLanguage lang) =>
    lang == AppLanguage.fil ? _monthNamesFil : _monthNamesEn;

/// 3-letter month abbreviations (index 0 = January), localized.
List<String> monthAbbrev(AppLanguage lang) =>
    lang == AppLanguage.fil ? _monthAbbrevFil : _monthAbbrevEn;

/// 3-letter weekday abbreviations, Sunday-first (index 0 = Sunday), localized.
List<String> weekdayLabels(AppLanguage lang) =>
    lang == AppLanguage.fil ? _weekdayLabelsFil : _weekdayLabelsEn;

String tr(AppLanguage lang, String key) {
  final map = lang == AppLanguage.fil ? _fil : _en;
  return map[key] ?? _en[key] ?? key;
}

// ══════════════════════════════════════════════════════════════════════
// Health option display labels — Filipino translations for the
// individual symptom/observation options in health_calculations.dart
// (kBehaviorOptions/kAppetiteOptions/kPhysicalOptions/kWasteOptions).
//
// Deliberately kept SEPARATE from those option catalogs and from _en/_fil
// above: HealthOption.label stays English/canonical because it's read
// directly by the scoring engine's unit tests, CSV/PDF export, and
// Dashboard trend tooltips (see the doc comment on kBehaviorOptions'
// block) — retranslating that field in place would touch the one module
// with the most existing test coverage for no logic benefit. This is
// purely a display-layer lookup: [healthOptionLabel]/[healthOptionSubtitle]
// return the Filipino text ONLY for on-screen rendering (health_form_screen
// .dart's option cards + Health Summary, health_history_screen.dart's log
// cards); every read of the underlying HealthOption.label/.key elsewhere
// is completely untouched.
//
// Keyed per-category (not a single flat map) because the same `key`
// string is reused across categories with different meanings — e.g.
// 'normal' means "Normal" behavior, "Eating Normally" appetite, and
// "Normal" waste consistency, each needing its own translation.
const Map<String, String> _healthBehaviorFil = {
  'normal': 'Normal',
  'less_active': 'Kaunting Kilos',
  'lethargic': 'Panghihina',
  'isolated': 'Bukod sa Grupo',
  'unable_stand': 'Hindi Makatayo',
};
const Map<String, String> _healthBehaviorSubtitleFil = {
  'normal': 'Maliwanag at Alerto ang Mata, Aktibong Kilos',
};

const Map<String, String> _healthAppetiteFil = {
  'normal': 'Normal na Kumakain',
  'eating_less': 'Kaunting Kumakain',
  'no_appetite': 'Walang Gana Kumain',
  'refusing': 'Ayaw Kumain o Uminom',
};

const Map<String, String> _healthPhysicalFil = {
  'pinkish': 'Kulay-Rosas na Balat',
  'bright_eyes': 'Maliwanag na Mata',
  'bruise_free': 'Walang Pasa',
  'normal_nose': 'Normal na Ilong',
  'normal_breathing': 'Normal na Paghinga',
  'normal_walking': 'Normal na Paglakad',
  'watery_eyes': 'May Kulangot sa Mata',
  'sneezing': 'Pagbahing',
  'mild_nasal': 'Bahagyang Sipon',
  'minor_bruises': 'Maliliit na Pasa',
  'mild_lameness': 'Bahagyang Paghihirap Maglakad',
  'coughing': 'Pag-ubo',
  'labored_breathing': 'Mahirap na Paghinga',
  'fever': 'Lagnat',
  'wounds': 'Sugat',
  'limping': 'Paika-ikang Paglakad',
  'swollen_joints': 'Namamagang Kasukasuan',
  'severe_lameness': 'Malalang Paghihirap Maglakad',
  'severe_swelling': 'Malalang Pamamaga ng Katawan',
  'severe_labored_breathing': 'Matinding Hirap sa Paghinga',
  'heavy_bleeding': 'Matinding Pagdurugo',
  'unable_walk': 'Hindi Makalakad',
  'high_fever': 'Matinding Lagnat',
  'collapse': 'Bumagsak',
};
const Map<String, String> _healthPhysicalSubtitleFil = {
  'pinkish': 'Normal na kulay',
  'bruise_free': 'Walang sugat',
};

const Map<String, String> _healthWasteFil = {
  'normal': 'Normal',
  'soft_stool': 'Bahagyang Malambot na Dumi',
  'loose': 'Maluwag/Matubig na Dumi',
  'bloody_diarrhea': 'Duguang Pagtatae',
  'black_stool': 'Itim na Dumi',
};
const Map<String, String> _healthWasteSubtitleFil = {
  'normal': 'Matigas na Dumi',
};

/// Which health-option catalog [category] refers to — pass one of
/// 'behavior' / 'appetite' / 'physical' / 'waste', matching
/// health_form_screen.dart's four sections.
String healthOptionLabel(
    AppLanguage lang, String category, String key, String fallbackLabel) {
  if (lang != AppLanguage.fil) return fallbackLabel;
  final map = switch (category) {
    'behavior' => _healthBehaviorFil,
    'appetite' => _healthAppetiteFil,
    'physical' => _healthPhysicalFil,
    'waste' => _healthWasteFil,
    _ => null,
  };
  return map?[key] ?? fallbackLabel;
}

/// Companion to [healthOptionLabel] for the small number of options that
/// also show a subtitle line (e.g. "Pinkish Skin" / "Normal color").
/// Returns [fallbackSubtitle] (including empty string) when no Filipino
/// override exists for [key].
String healthOptionSubtitle(
    AppLanguage lang, String category, String key, String fallbackSubtitle) {
  if (lang != AppLanguage.fil || fallbackSubtitle.isEmpty)
    return fallbackSubtitle;
  final map = switch (category) {
    'behavior' => _healthBehaviorSubtitleFil,
    'physical' => _healthPhysicalSubtitleFil,
    'waste' => _healthWasteSubtitleFil,
    _ => null,
  };
  return map?[key] ?? fallbackSubtitle;
}

/// Translated Overall Status badge text (Healthy / Needs Monitoring / At
/// Risk / Critical) — reuses the EXISTING healthyChip/needsMonitoring/
/// atRiskSection/criticalSection keys (already translated for the
/// Severity Counts chips and Physical Condition section headers) rather
/// than adding duplicate new dictionary entries, so the same status
/// concept never has two different Filipino wordings on the same screen.
///
/// kHealthStatusMeta[status].label itself stays English/canonical — it's
/// read directly by AuthRepository activity-log descriptions and CSV/PDF
/// export (health_export.dart), both of which are meant to stay in one
/// consistent language regardless of the UI's current display language.
/// This helper is strictly for on-screen badges/chips/filters.
String healthStatusLabel(AppLanguage lang, HealthStatus status) {
  final key = switch (status) {
    HealthStatus.healthy => 'healthyChip',
    HealthStatus.monitor => 'needsMonitoring',
    HealthStatus.risk => 'atRiskSection',
    HealthStatus.critical => 'criticalSection',
  };
  return tr(lang, key);
}

/// Verification helper (requested alongside the health-option translation
/// dictionaries above): walks every option in kBehaviorOptions/
/// kAppetiteOptions/kPhysicalOptions/kWasteOptions and returns
/// 'category.key' for any option that has no entry in the matching
/// Filipino lookup map — i.e. any option that would silently render in
/// English when the app is switched to Filipino. Returns an empty list
/// when coverage is complete. Exists so a future new HealthOption (a new
/// symptom added to health_calculations.dart) can never quietly ship
/// without its translation — both the test suite and, if ever needed, a
/// debug-time assertion can call this directly instead of re-deriving the
/// same key list by hand.
List<String> healthTranslationCoverageGaps() {
  final gaps = <String>[];
  void check(
      String category, List<HealthOption> options, Map<String, String> filMap) {
    for (final o in options) {
      if (!filMap.containsKey(o.key)) gaps.add('$category.${o.key}');
    }
  }

  check('behavior', kBehaviorOptions, _healthBehaviorFil);
  check('appetite', kAppetiteOptions, _healthAppetiteFil);
  check('physical', kPhysicalOptions, _healthPhysicalFil);
  check('waste', kWasteOptions, _healthWasteFil);
  return gaps;
}

/// Ported verbatim from the legacy app's Farmer Type dropdown
/// (index.html:992-997, the `#sf-type` <select> in the Settings > Farmer
/// Profile edit card).
const List<String> kFarmerTypeOptions = [
  'Backyard Raiser',
  'Commercial Raiser',
  'Semi-Commercial',
  'Hobbyist',
];

// ══════════════════════════════════════════════════════════════════════
// Notification Settings display labels — Filipino translations for the 9
// ReminderTypeDef entries in reminder_types.dart (kReminderTypes).
//
// Same reasoning as the health-option lookups above: ReminderTypeDef.title/
// .description stay English/canonical because local_notification_service
// .dart schedules the OS notification's own title/body directly from those
// fields (zonedSchedule(def.notifId, def.title, def.description, ...)) —
// once a reminder is scheduled, that payload is fixed for whenever it
// eventually fires, so retranslating the canonical fields wouldn't change
// what already-scheduled notifications say anyway. This is strictly a
// display-layer lookup for notification_settings_screen.dart's on-screen
// card titles/subtitles, mirroring [healthOptionLabel]/[healthOptionSubtitle].
const Map<String, String> _reminderTitleFil = {
  'feeding': 'Pagpapakain sa Araw-araw',
  'health': 'Pagsusuri sa Kalusugan',
  'weighin': 'Lingguhang Timbangan',
  'photo': 'Lingguhang Larawan',
  'vaccination': 'Bakuna',
  'medication': 'Gamot',
  'marketDay': 'Araw ng Palengke',
  'productionDay': 'Paalala sa Araw ng Produksyon',
  'backup': 'Paalala sa Backup',
};

const Map<String, String> _reminderDescriptionFil = {
  'feeding':
      'Ipinapaalala sa iyo na pakainin ang iyong mga baboy sa parehong oras araw-araw.',
  'health':
      'Ipinapaalala sa iyo na itala ang obserbasyon ng Health Monitor ngayong araw.',
  'weighin':
      'Ipinapaalala sa iyo na itala ang opisyal na timbang ng baboy ngayong linggo.',
  'photo':
      'Ipinapaalala sa iyo na kumuha ng larawan ng progreso ngayong linggo para sa bawat baboy.',
  'vaccination':
      'Ipinapaalala sa iyo na tingnan kung may bakunang dapat gawin.',
  'medication': 'Ipinapaalala sa iyo na bigyan ng nakatakdang gamot.',
  'marketDay':
      'Nagbibigay-alerto habang papalapit ang katapusan ng 120 araw na siklo ng produksyon.',
  'productionDay':
      'Ipinapaalala sa iyo na kumpletuhin ang mga gawain ngayong araw at isulong ang araw.',
  'backup':
      'Ipinapaalala sa iyo na mag-export ng CSV/PDF na backup ng iyong mga tala.',
};

/// Display-layer title for [key] (a ReminderTypeDef.key) — returns the
/// Filipino translation when [lang] is Filipino and one exists, otherwise
/// [fallback] (normally the caller's own def.title).
String reminderTitle(AppLanguage lang, String key, String fallback) {
  if (lang != AppLanguage.fil) return fallback;
  return _reminderTitleFil[key] ?? fallback;
}

/// Companion to [reminderTitle] for the description shown under the
/// switch in Settings.
String reminderDescription(AppLanguage lang, String key, String fallback) {
  if (lang != AppLanguage.fil) return fallback;
  return _reminderDescriptionFil[key] ?? fallback;
}

/// Verification helper mirroring [healthTranslationCoverageGaps]: returns
/// 'title.<key>' / 'description.<key>' for any reminder type in
/// [kReminderTypes] missing a Filipino entry, so a future new reminder type
/// can't quietly ship without translation. Empty list = full coverage.
List<String> reminderTranslationCoverageGaps() {
  final gaps = <String>[];
  for (final def in kReminderTypes) {
    if (!_reminderTitleFil.containsKey(def.key)) gaps.add('title.${def.key}');
    if (!_reminderDescriptionFil.containsKey(def.key))
      gaps.add('description.${def.key}');
  }
  return gaps;
}

// ══════════════════════════════════════════════════════════════════════
// Daily Task display labels — Filipino translations for the 10
// DailyTaskDef entries in daily_task.dart (kDailyTaskDefs), keyed by
// DailyTaskDef.id. Same reasoning as reminderTitle/reminderDescription
// above: the canonical title/subtitle stay English because
// taskLockMessage() and other domain logic reference these tasks by id,
// not by their display text — this is purely a display-layer lookup for
// tasks_screen.dart and today_tasks_card.dart.
// ══════════════════════════════════════════════════════════════════════
const Map<String, String> _dailyTaskTitleFil = {
  '1': '1. Biosecurity at Kapaligiran',
  '2': '2. Pagsusuri sa Vitality',
  '3': '3. Pagpapakain sa Umaga',
  '4': '4. Pagsusuri sa Sistema ng Tubig',
  '5': '5. Paglilinis at Pagsusuri ng Kulungan',
  '6': '6. Pagsusuri sa Paghinga',
  '7': '7. Pagsusuri sa Dumi',
  '8': '8. Temperatura at Bentilasyon',
  '9': '9. Pagpapakain sa Hapon at Tuyong Paglilinis',
  '10': '10. Pagtatala ng Araw-araw na Log',
};

const Map<String, String> _dailyTaskSubtitleFil = {
  '1': 'Linisin sa loob/labas. Siguraduhing handa ang footbath at sanitizer.',
  '2': 'Tingnan kung aktibo ang mga hayop at hindi manghina bago pakainin.',
  '3': 'Pakainin ang tamang dami sa malinis na sisidlan. Oras: 7:30–8:00 AM.',
  '4': 'Siguraduhing malinis ang tubig at maayos ang daloy sa mga inuman.',
  '5': 'Linisin ang kulungan. Suriin kung may hindi kumakain o mahinang gana.',
  '6': 'Makinig sa ubo o senyales ng sipon/pagbahing.',
  '7': 'Tingnan ang kondisyon ng dumi (pagkapal at kulay).',
  '8':
      'Subaybayan ang 26–27°C at siguraduhing maayos ang sirkulasyon ng hangin.',
  '9':
      'Pakainin ang tamang dami. Tuyong linisin ang kulungan (iwasan ang tubig).',
  '10':
      'Itala ang kapaligiran at kalusugan. Makipag-ugnayan sa beterinaryo kung may isyu.',
};

/// Display-layer title for daily task [id] — mirrors [reminderTitle].
String dailyTaskTitle(AppLanguage lang, String id, String fallback) {
  if (lang != AppLanguage.fil) return fallback;
  return _dailyTaskTitleFil[id] ?? fallback;
}

/// Display-layer subtitle for daily task [id] — mirrors [reminderDescription].
String dailyTaskSubtitle(AppLanguage lang, String id, String fallback) {
  if (lang != AppLanguage.fil) return fallback;
  return _dailyTaskSubtitleFil[id] ?? fallback;
}

// ══════════════════════════════════════════════════════════════════════
// Farmer Type display labels — kFarmerTypeOptions stays English/canonical
// (it's the literal value stored in Supabase's profiles.farmer_type
// column and compared with `==` against the dropdown's selected value),
// so this is a display-layer-only lookup for profile_edit_screen.dart's
// dropdown and dashboard_drawer.dart's footer role text.
// ══════════════════════════════════════════════════════════════════════
const Map<String, String> _farmerTypeKeyByValue = {
  'Backyard Raiser': 'farmerTypeBackyard',
  'Commercial Raiser': 'farmerTypeCommercial',
  'Semi-Commercial': 'farmerTypeSemiCommercial',
  'Hobbyist': 'farmerTypeHobbyist',
};

String farmerTypeLabel(AppLanguage lang, String value) {
  final key = _farmerTypeKeyByValue[value];
  if (key == null) return value;
  return tr(lang, key);
}
