import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/company_auth_screen.dart';
import '../../features/auth/presentation/screens/email_verification_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/courses/presentation/screens/course_detail_screen.dart';
import '../../features/courses/presentation/screens/courses_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/internships/presentation/screens/internship_detail_screen.dart';
import '../../features/internships/presentation/screens/internships_screen.dart';
import '../../features/jobs/presentation/screens/job_detail_screen.dart';
import '../../features/jobs/presentation/screens/jobs_screen.dart';
import '../../features/leaderboard/presentation/screens/leaderboard_screen.dart';
import '../../features/points/presentation/screens/points_system_screen.dart';
import '../../features/student_dashboard/presentation/screens/student_dashboard_screen.dart';
import '../../shared/widgets/app_navbar.dart';
import '../../shared/widgets/empty_state.dart';
import 'route_guards.dart';
import 'routes.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authStream = ref.watch(authViewStateProvider.stream);

  // ✅ IMPORTANT (Web): use the real browser URL, not defaultRouteName "/"
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
    refreshListenable: GoRouterRefreshStream(authStream),

    redirect: (context, state) {
      final location = state.uri.path;

      final authAsync = ref.read(authViewStateProvider);
      if (authAsync.isLoading) return null;

      final auth = authAsync.value;
      if (auth == null) return null;

      // ✅ Always allow reset-password (deep-link recovery flow)
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
        Routes.companyRegister,
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
        builder: (context, _) =>
            const PlaceholderScreen(title: 'Admin Login', showAppBar: true),
      ),
      GoRoute(
        path: Routes.adminSetup,
        builder: (context, _) =>
            const PlaceholderScreen(title: 'Admin Setup', showAppBar: true),
      ),

      // -------------
      // Admin shell
      // -------------
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: Routes.adminDashboard,
            builder: (context, _) => const PlaceholderView(title: 'Admin Dashboard'),
          ),
          GoRoute(
            path: Routes.adminCompanies,
            builder: (context, _) => const PlaceholderView(title: 'Admin Companies'),
          ),
          GoRoute(
            path: Routes.adminUsers,
            builder: (context, _) => const PlaceholderView(title: 'Admin Users'),
          ),
          GoRoute(
            path: Routes.adminJobs,
            builder: (context, _) => const PlaceholderView(title: 'Admin Jobs'),
          ),
          GoRoute(
            path: Routes.adminSubscriptions,
            builder: (context, _) =>
                const PlaceholderView(title: 'Admin Subscriptions'),
          ),
          GoRoute(
            path: Routes.adminReports,
            builder: (context, _) => const PlaceholderView(title: 'Admin Reports'),
          ),
          GoRoute(
            path: Routes.adminSettings,
            builder: (context, _) => const PlaceholderView(title: 'Admin Settings'),
          ),
          GoRoute(
            path: Routes.adminLogs,
            builder: (context, _) => const PlaceholderView(title: 'Admin Logs'),
          ),
          GoRoute(
            path: Routes.adminProfile,
            builder: (context, _) => const PlaceholderView(title: 'Admin Profile'),
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
            builder: (context, state) => LoginScreen(
              from: state.uri.queryParameters['from'],
            ),
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
            builder: (context, _) =>
                const CompanyAuthScreen(initialIsLogin: false),
          ),

           GoRoute(
            path: Routes.dashboard,
            builder: (context, state) => const StudentDashboardScreen(),
          ),

          // Footer pages (public)
          GoRoute(
            path: Routes.howItWorks,
            builder: (context, _) =>
                const PlaceholderView(title: 'How It Works'),
          ),
          GoRoute(
            path: Routes.about,
            builder: (context, _) => const PlaceholderView(title: 'About'),
          ),
          GoRoute(
            path: Routes.contact,
            builder: (context, _) => const PlaceholderView(title: 'Contact'),
          ),
          GoRoute(
            path: Routes.privacy,
            builder: (context, _) =>
                const PlaceholderView(title: 'Privacy Policy'),
          ),
          GoRoute(
            path: Routes.terms,
            builder: (context, _) =>
                const PlaceholderView(title: 'Terms of Service'),
          ),
          GoRoute(
            path: Routes.pointsSystem,
            builder: (context, _) => const PointsSystemScreen(),
          ),
          GoRoute(
            path: Routes.profile,
            builder: (context, _) => const PlaceholderView(title: 'Profile'),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (context, _) => const PlaceholderView(title: 'Settings'),
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
            path: Routes.jobDetail,
            builder: (_, state) => JobDetailScreen(jobId: state.pathParameters['id']!),          ),
          GoRoute(
            path: Routes.internships,
            builder: (_, __) => const InternshipsScreen(),
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
            builder: (context, _) =>
                const PlaceholderView(title: 'Applications'),
          ),
          GoRoute(
            path: Routes.favorites,
            builder: (context, _) => const PlaceholderView(title: 'Favorites'),
          ),
          GoRoute(
            path: Routes.notifications,
            builder: (context, _) =>
                const PlaceholderView(title: 'Notifications'),
          ),
          GoRoute(
            path: Routes.leaderboard,
            builder: (context, _) => const LeaderboardScreen(),
          ),
          GoRoute(
            path: Routes.debug,
            builder: (context, _) =>
                const PlaceholderView(title: 'Database Debug'),
          ),

          // Company protected
          GoRoute(
            path: Routes.companyDashboard,
            builder: (context, _) =>
                const PlaceholderView(title: 'Company Dashboard'),
          ),
          GoRoute(
            path: Routes.companyJobs,
            builder: (context, _) =>
                const PlaceholderView(title: 'Company Jobs'),
          ),
          GoRoute(
            path: Routes.companyJobsCreate,
            builder: (context, _) => const PlaceholderView(title: 'Create Job'),
          ),
          GoRoute(
            path: Routes.companyJobsEdit,
            builder: (_, s) => PlaceholderView(
              title: 'Edit Job',
              subtitle: 'id=${s.pathParameters['id']}',
            ),
          ),
          GoRoute(
            path: Routes.companyJobApplications,
            builder: (_, s) => PlaceholderView(
              title: 'Job Applications',
              subtitle: 'id=${s.pathParameters['id']}',
            ),
          ),
          GoRoute(
            path: Routes.companyInternships,
            builder: (context, _) =>
                const PlaceholderView(title: 'Internship Management'),
          ),
          GoRoute(
            path: Routes.companyInternshipsCreate,
            builder: (context, _) =>
                const PlaceholderView(title: 'Create Internship'),
          ),
          GoRoute(
            path: Routes.companyInternshipsEdit,
            builder: (_, s) => PlaceholderView(
              title: 'Edit Internship',
              subtitle: 'id=${s.pathParameters['id']}',
            ),
          ),
          GoRoute(
            path: Routes.companyInternshipApplications,
            builder: (_, s) => PlaceholderView(
              title: 'Internship Applications',
              subtitle: 'id=${s.pathParameters['id']}',
            ),
          ),
          GoRoute(
            path: Routes.companyProfile,
            builder: (context, _) =>
                const PlaceholderView(title: 'Company Profile'),
          ),
          GoRoute(
            path: Routes.companyReports,
            builder: (context, _) => const PlaceholderView(title: 'Reports'),
          ),
          GoRoute(
            path: Routes.companyApplications,
            builder: (context, _) =>
                const PlaceholderView(title: 'Company Applications'),
          ),
          GoRoute(
            path: Routes.companyPricing,
            builder: (context, _) => const PlaceholderView(title: 'Pricing'),
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

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Main Shell (React-like Navbar + Footer)
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ No AppBar (we reproduce React navbar)
      body: Column(
        children: [
          const AppNavbar(), // sticky-like top
          Expanded(child: child),
          const _Footer(),
        ],
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
      appBar: AppBar(title: const Text('Admin')),
      body: child,
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          '© ${DateTime.now().year} Öğrenci Intelligence',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
