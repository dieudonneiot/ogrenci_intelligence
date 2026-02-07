import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/screens/admin_companies_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/admin_jobs_screen.dart';
import '../../features/admin/presentation/screens/admin_login_screen.dart';
import '../../features/admin/presentation/screens/admin_logs_screen.dart';
import '../../features/admin/presentation/screens/admin_profile_screen.dart';
import '../../features/admin/presentation/screens/admin_reports_screen.dart';
import '../../features/admin/presentation/screens/admin_settings_screen.dart';
import '../../features/admin/presentation/screens/admin_setup_screen.dart';
import '../../features/admin/presentation/screens/admin_subscriptions_screen.dart';
import '../../features/admin/presentation/screens/admin_users_screen.dart';
import '../../features/admin/presentation/widgets/admin_layout.dart';
import '../../features/applications/presentation/screens/applications_screen.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/company_auth_screen.dart';
import '../../features/auth/presentation/screens/email_verification_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/case_analysis/presentation/screens/case_analysis_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/company/presentation/screens/company_applications_screen.dart';
import '../../features/company/presentation/screens/company_dashboard_screen.dart';
import '../../features/company/presentation/screens/company_excuse_requests_screen.dart';
import '../../features/company/presentation/screens/company_internship_applications_screen.dart';
import '../../features/company/presentation/screens/company_internship_form_screen.dart';
import '../../features/company/presentation/screens/company_internships_screen.dart';
import '../../features/company/presentation/screens/company_job_applications_screen.dart';
import '../../features/company/presentation/screens/company_job_form_screen.dart';
import '../../features/company/presentation/screens/company_jobs_screen.dart';
import '../../features/company/presentation/screens/company_pricing_screen.dart';
import '../../features/company/presentation/screens/company_profile_screen.dart';
import '../../features/company/presentation/screens/company_reports_screen.dart';
import '../../features/company/presentation/screens/company_talent_mining_screen.dart';
import '../../features/company/presentation/screens/register_company_screen.dart';
import '../../features/company/presentation/widgets/company_status_check.dart';
import '../../features/courses/presentation/screens/course_detail_screen.dart';
import '../../features/courses/presentation/screens/courses_screen.dart';
import '../../features/development/presentation/screens/development_screen.dart';
import '../../features/evidence/presentation/screens/company_evidence_screen.dart';
import '../../features/evidence/presentation/screens/evidence_screen.dart';
import '../../features/excuse/presentation/screens/excuse_request_screen.dart';
import '../../features/favorites/presentation/screens/favorites_screen.dart';
import '../../features/focus_check/presentation/screens/focus_check_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/internships/presentation/screens/internship_detail_screen.dart';
import '../../features/internships/presentation/screens/internships_screen.dart';
import '../../features/jobs/presentation/screens/job_detail_screen.dart';
import '../../features/jobs/presentation/screens/jobs_screen.dart';
import '../../features/leaderboard/presentation/screens/leaderboard_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/points/presentation/screens/points_system_screen.dart';
import '../../features/static_pages/presentation/screens/about_screen.dart';
import '../../features/static_pages/presentation/screens/contact_screen.dart';
import '../../features/static_pages/presentation/screens/how_it_works_screen.dart';
import '../../features/static_pages/presentation/screens/privacy_policy_screen.dart';
import '../../features/static_pages/presentation/screens/terms_of_service_screen.dart';
import '../../features/student_dashboard/presentation/screens/student_dashboard_screen.dart';
import '../../features/user/presentation/screens/database_debug_screen.dart';
import '../../features/user/presentation/screens/user_profile_screen.dart';
import '../../features/user/presentation/screens/user_settings_screen.dart';
import '../../shared/widgets/app_navbar.dart';
import '../../shared/widgets/empty_state.dart';
import 'route_guards.dart';
import 'routes.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = GoRouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  // IMPORTANT (Web): use the real browser URL, not defaultRouteName "/"
  final String initialLocation = () {
    if (kIsWeb) {
      final base = Uri.base;

      // Keep full path + query (React-like behavior)
      var loc = base.path;
      if (loc.isEmpty) loc = Routes.home;
      if (!loc.startsWith('/')) loc = '/$loc';

      if (base.hasQuery) loc = '$loc?${base.query}';
      return loc;
    }

    // Mobile/desktop: platform initial route name is fine
    final initial = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    return initial.isEmpty ? Routes.home : initial;
  }();

  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refreshNotifier,

    redirect: (context, state) {
      final location = state.uri.path;

      final authAsync = ref.read(authViewStateProvider);
      if (authAsync.isLoading) return null;

      final auth = authAsync.value;
      if (auth == null) return null;

      // Always allow reset-password (deep-link recovery flow)
      if (location == Routes.resetPassword) return null;

      final isAuthorized = auth.isAuthenticated;

      // 1) Not authorized: allow only public routes
      if (!isAuthorized) {
        if (RouteGuards.isPublicPath(location)) return null;

        // Preserve "from" like React (login then come back)
        final from = Uri.encodeComponent(state.uri.toString());
        return '${Routes.login}?from=$from';
      }

      // 2) Authorized: role-based protection (protected areas)
      final roleRedirect = RouteGuards.redirectForRole(
        userType: auth.userType,
        location: location,
      );
      if (roleRedirect != null) return roleRedirect;

      // 3) Keep authenticated users out of auth pages
      const authPages = <String>{
        Routes.login,
        Routes.register,
        Routes.forgotPassword,
        Routes.emailVerification,
        Routes.companyAuth,
        Routes.adminLogin,
        Routes.adminSetup,
      };

      if (authPages.contains(location)) {
        if (auth.userType == UserType.admin) return Routes.adminDashboard;
        if (auth.userType == UserType.company) return Routes.companyDashboard;
        return Routes.dashboard;
      }

      // 4) Optional: redirect "/" for admin/company (students can see home)
      if (location == Routes.home) {
        if (auth.userType == UserType.admin) return Routes.adminDashboard;
        if (auth.userType == UserType.company) return Routes.companyDashboard;
      }

      return null;
    },

    routes: [
      // -----------------------------
      // Admin auth routes (standalone)
      // -----------------------------
      GoRoute(
        path: Routes.adminLogin,
        builder: (context, _) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: Routes.adminSetup,
        builder: (context, _) => const AdminSetupScreen(),
      ),

      // -------------
      // Admin shell
      // -------------
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: Routes.adminDashboard,
            builder: (context, _) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: Routes.adminChat,
            builder: (context, _) => const ChatScreen(),
          ),
          GoRoute(
            path: Routes.adminCompanies,
            builder: (context, _) => const AdminCompaniesScreen(),
          ),
          GoRoute(
            path: Routes.adminUsers,
            builder: (context, _) => const AdminUsersScreen(),
          ),
          GoRoute(
            path: Routes.adminJobs,
            builder: (context, _) => const AdminJobsScreen(),
          ),
          GoRoute(
            path: Routes.adminSubscriptions,
            builder: (context, _) => const AdminSubscriptionsScreen(),
          ),
          GoRoute(
            path: Routes.adminReports,
            builder: (context, _) => const AdminReportsScreen(),
          ),
          GoRoute(
            path: Routes.adminSettings,
            builder: (context, _) => const AdminSettingsScreen(),
          ),
          GoRoute(
            path: Routes.adminLogs,
            builder: (context, _) => const AdminLogsScreen(),
          ),
          GoRoute(
            path: Routes.adminProfile,
            builder: (context, _) => const AdminProfileScreen(),
          ),
        ],
      ),

      // -----------------------------
      // Main shell (public + student + company)
      // -----------------------------
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          // Public
          GoRoute(
            path: Routes.home,
            builder: (context, _) => const HomeScreen(),
          ),

          // Auth screens
          GoRoute(
            path: Routes.login,
            builder: (context, state) =>
                LoginScreen(from: state.uri.queryParameters['from']),
          ),
          GoRoute(
            path: Routes.register,
            builder: (context, _) => const RegisterScreen(),
          ),
          GoRoute(
            path: Routes.forgotPassword,
            builder: (context, _) => const ForgotPasswordScreen(),
          ),
          GoRoute(
            path: Routes.emailVerification,
            builder: (context, state) => EmailVerificationScreen(
              emailHint: state.uri.queryParameters['email'],
            ),
          ),
          GoRoute(
            path: Routes.resetPassword,
            builder: (context, _) => const ResetPasswordScreen(),
          ),

          // Company auth
          GoRoute(
            path: Routes.companyAuth,
            builder: (context, _) => const CompanyAuthScreen(),
          ),
          GoRoute(
            path: Routes.companyRegister,
            builder: (context, _) => const RegisterCompanyScreen(),
          ),

          GoRoute(
            path: Routes.dashboard,
            builder: (context, state) => const StudentDashboardScreen(),
          ),
          GoRoute(
            path: Routes.chat,
            builder: (context, _) => const ChatScreen(),
          ),
          GoRoute(
            path: Routes.development,
            builder: (context, _) => const DevelopmentScreen(),
          ),
          GoRoute(
            path: Routes.caseAnalysis,
            builder: (context, _) => const CaseAnalysisScreen(),
          ),
          GoRoute(
            path: Routes.focusCheck,
            builder: (context, state) =>
                FocusCheckScreen(focusCheckId: state.uri.queryParameters['id']),
          ),
          GoRoute(
            path: Routes.evidence,
            builder: (context, _) => const EvidenceScreen(),
          ),

          // Footer pages (public)
          GoRoute(
            path: Routes.howItWorks,
            builder: (context, _) => const HowItWorksScreen(),
          ),
          GoRoute(
            path: Routes.about,
            builder: (context, _) => const AboutScreen(),
          ),
          GoRoute(
            path: Routes.contact,
            builder: (context, _) => const ContactScreen(),
          ),
          GoRoute(
            path: Routes.privacy,
            builder: (context, _) => const PrivacyPolicyScreen(),
          ),
          GoRoute(
            path: Routes.terms,
            builder: (context, _) => const TermsOfServiceScreen(),
          ),
          GoRoute(
            path: Routes.pointsSystem,
            builder: (context, _) => const PointsSystemScreen(),
          ),
          GoRoute(
            path: Routes.profile,
            builder: (context, _) => const UserProfileScreen(),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (context, _) => const UserSettingsScreen(),
          ),
          GoRoute(
            path: Routes.excuseRequest,
            builder: (context, _) => const ExcuseRequestScreen(),
          ),
          GoRoute(
            path: Routes.courses,
            builder: (context, _) => const CoursesScreen(),
          ),
          GoRoute(
            path: Routes.courseDetail,
            builder: (_, state) {
              final id = state.pathParameters['id']!;
              return CourseDetailScreen(courseId: id);
            },
          ),
          GoRoute(
            path: Routes.jobs,
            builder: (context, _) => const JobsScreen(),
          ),
          GoRoute(
            path: Routes.jobDetail, // '/jobs/:id'
            builder: (_, state) =>
                JobDetailScreen(jobId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: Routes.internships,
            builder: (context, _) => const InternshipsScreen(),
          ),
          GoRoute(
            path: Routes.internshipDetail, // /internships/:id
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return InternshipDetailScreen(internshipId: id);
            },
          ),
          GoRoute(
            path: Routes.applications,
            builder: (context, state) => const ApplicationsScreen(),
          ),
          GoRoute(
            path: Routes.favorites,
            builder: (context, _) => const FavoritesScreen(),
          ),
          GoRoute(
            path: Routes.notifications,
            builder: (context, _) => const NotificationsScreen(),
          ),
          GoRoute(
            path: Routes.leaderboard,
            builder: (context, _) => const LeaderboardScreen(),
          ),
          GoRoute(
            path: Routes.debug,
            builder: (context, _) => const DatabaseDebugScreen(),
          ),

          // Company protected
          GoRoute(
            path: Routes.companyDashboard,
            builder: (context, _) => const CompanyDashboardScreen(),
          ),
          GoRoute(
            path: Routes.companyJobs,
            builder: (context, _) => const CompanyJobsScreen(),
          ),
          GoRoute(
            path: Routes.companyJobsCreate,
            builder: (context, _) =>
                const CompanyStatusCheck(child: CompanyJobFormScreen()),
          ),
          GoRoute(
            path: Routes.companyJobsEdit,
            builder: (_, s) => CompanyStatusCheck(
              child: CompanyJobFormScreen(jobId: s.pathParameters['id']),
            ),
          ),
          GoRoute(
            path: Routes.companyJobApplications,
            builder: (_, s) =>
                CompanyJobApplicationsScreen(jobId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: Routes.companyInternships,
            builder: (context, _) => const CompanyInternshipsScreen(),
          ),
          GoRoute(
            path: Routes.companyInternshipsCreate,
            builder: (context, _) =>
                const CompanyStatusCheck(child: CompanyInternshipFormScreen()),
          ),
          GoRoute(
            path: Routes.companyInternshipsEdit,
            builder: (_, s) => CompanyStatusCheck(
              child: CompanyInternshipFormScreen(
                internshipId: s.pathParameters['id'],
              ),
            ),
          ),
          GoRoute(
            path: Routes.companyInternshipApplications,
            builder: (_, s) => CompanyInternshipApplicationsScreen(
              internshipId: s.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: Routes.companyProfile,
            builder: (context, _) => const CompanyProfileScreen(),
          ),
          GoRoute(
            path: Routes.companyReports,
            builder: (context, _) => const CompanyReportsScreen(),
          ),
          GoRoute(
            path: Routes.companyApplications,
            builder: (context, _) => const CompanyApplicationsScreen(),
          ),
          GoRoute(
            path: Routes.companyEvidence,
            builder: (context, _) => const CompanyEvidenceScreen(),
          ),
          GoRoute(
            path: Routes.companyPricing,
            builder: (context, _) => const CompanyPricingScreen(),
          ),
          GoRoute(
            path: Routes.companyTalent,
            builder: (context, _) => const CompanyTalentMiningScreen(),
          ),
          GoRoute(
            path: Routes.companyExcuses,
            builder: (context, _) => const CompanyExcuseRequestsScreen(),
          ),
          GoRoute(
            path: Routes.companyChat,
            builder: (context, _) => const ChatScreen(),
          ),
        ],
      ),
    ],

    errorBuilder: (_, state) => PlaceholderScreen(
      title: '404',
      subtitle: state.error?.toString(),
      showAppBar: true,
    ),
  );
});

class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(this._ref) {
    _sub = _ref.listen<AsyncValue<AuthViewState>>(
      authViewStateProvider,
      (_, unused) => notifyListeners(),
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AsyncValue<AuthViewState>> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

/// Main Shell (React-like Navbar)
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authViewStateProvider).valueOrNull;
    final isStudent =
        auth?.isAuthenticated == true && auth?.userType == UserType.student;

    return Scaffold(
      // No AppBar (we reproduce React navbar)
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                const AppNavbar(), // sticky-like top
                Expanded(child: child),
              ],
            ),
          ),
          if (isStudent)
            Positioned(
              right: 18,
              bottom: 18,
              child: _ChatFab(onTap: () => context.go(Routes.chat)),
            ),
        ],
      ),
    );
  }
}

class _ChatFab extends StatefulWidget {
  const _ChatFab({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ChatFab> createState() => _ChatFabState();
}

class _ChatFabState extends State<_ChatFab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _hover ? 1.05 : 1.0,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withAlpha(40),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Admin Shell (temporary)
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AdminLayout(child: child),
    );
  }
}
