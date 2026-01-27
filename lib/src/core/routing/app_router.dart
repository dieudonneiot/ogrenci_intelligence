import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../shared/widgets/empty_state.dart';
import '../supabase/supabase_service.dart';
import 'route_guards.dart';
import 'routes.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.home,
    refreshListenable: GoRouterRefreshStream(
      SupabaseService.client.auth.onAuthStateChange,
    ),
    redirect: (context, state) {
      final location = state.matchedLocation;

      // Read latest auth view state (computed from admins + company_users + default student)
      final authAsync = ref.read(authViewStateProvider);

      // While auth is still resolving, don't redirect.
      if (authAsync.isLoading) return null;

      final auth = authAsync.value;
      if (auth == null) return null;

      final isAuthorized = auth.isAuthenticated;

      // 1) Not authorized: allow only public routes
      if (!isAuthorized) {
        return RouteGuards.isPublicPath(location) ? null : Routes.login;
      }

      // 2) Authorized: role-based route protection (mirrors React GlobalRouteControl)
      final roleRedirect = RouteGuards.redirectForRole(
        userType: auth.userType,
        location: location,
      );
      if (roleRedirect != null) return roleRedirect;

      // 3) Keep authenticated users out of auth pages (but allow reset-password)
      const authPages = <String>{
        Routes.login,
        Routes.register,
        Routes.forgotPassword,
        Routes.emailVerification,
        Routes.companyAuth,
        Routes.adminLogin,
      };
      if (authPages.contains(location)) {
        if (auth.userType == UserType.admin) return Routes.adminDashboard;
        if (auth.userType == UserType.company) return Routes.companyDashboard;
        return Routes.dashboard;
      }

      // 4) Optional: redirect "/" depending on role (matches your React behavior)
      if (location == Routes.home) {
        if (auth.userType == UserType.admin) return Routes.adminDashboard;
        if (auth.userType == UserType.company) return Routes.companyDashboard;
        return null; // students can see home (marketing) in React
      }

      return null;
    },
    routes: [
      // Admin auth routes (no main shell)
      GoRoute(
        path: Routes.adminLogin,
        builder: (_, __) => const PlaceholderScreen(title: 'Admin Login'),
      ),
      GoRoute(
        path: Routes.adminSetup,
        builder: (_, __) => const PlaceholderScreen(title: 'Admin Setup'),
      ),

      // Admin area shell (later replace with real AdminLayout)
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: Routes.adminDashboard,
            builder: (_, __) => const PlaceholderScreen(title: 'Admin Dashboard'),
          ),
          GoRoute(
            path: Routes.adminCompanies,
            builder: (_, __) => const PlaceholderScreen(title: 'Admin Companies'),
          ),
          GoRoute(
            path: Routes.adminUsers,
            builder: (_, __) => const PlaceholderScreen(title: 'Admin Users'),
          ),
          GoRoute(
            path: Routes.adminJobs,
            builder: (_, __) => const PlaceholderScreen(title: 'Admin Jobs'),
          ),
          GoRoute(
            path: Routes.adminSubscriptions,
            builder: (_, __) =>
                const PlaceholderScreen(title: 'Admin Subscriptions'),
          ),
          GoRoute(
            path: Routes.adminReports,
            builder: (_, __) => const PlaceholderScreen(title: 'Admin Reports'),
          ),
          GoRoute(
            path: Routes.adminSettings,
            builder: (_, __) => const PlaceholderScreen(title: 'Admin Settings'),
          ),
          GoRoute(
            path: Routes.adminLogs,
            builder: (_, __) => const PlaceholderScreen(title: 'Admin Logs'),
          ),
          GoRoute(
            path: Routes.adminProfile,
            builder: (_, __) => const PlaceholderScreen(title: 'Admin Profile'),
          ),
        ],
      ),

      // Main shell (public + student + company)
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          // Public
          GoRoute(
            path: Routes.home,
            builder: (_, __) => const PlaceholderScreen(title: 'Home'),
          ),
          GoRoute(
            path: Routes.login,
            builder: (_, __) => const PlaceholderScreen(title: 'Login'),
          ),
          GoRoute(
            path: Routes.register,
            builder: (_, __) => const PlaceholderScreen(title: 'Register'),
          ),
          GoRoute(
            path: Routes.forgotPassword,
            builder: (_, __) => const PlaceholderScreen(title: 'Forgot Password'),
          ),
          GoRoute(
            path: Routes.emailVerification,
            builder: (_, __) =>
                const PlaceholderScreen(title: 'Email Verification'),
          ),
          GoRoute(
            path: Routes.resetPassword,
            builder: (_, __) => const ResetPasswordScreen(),
          ),
          GoRoute(
            path: Routes.companyAuth,
            builder: (_, __) => const PlaceholderScreen(title: 'Company Auth'),
          ),

          // Footer pages (public)
          GoRoute(
            path: Routes.howItWorks,
            builder: (_, __) => const PlaceholderScreen(title: 'How It Works'),
          ),
          GoRoute(
            path: Routes.about,
            builder: (_, __) => const PlaceholderScreen(title: 'About'),
          ),
          GoRoute(
            path: Routes.contact,
            builder: (_, __) => const PlaceholderScreen(title: 'Contact'),
          ),
          GoRoute(
            path: Routes.privacy,
            builder: (_, __) => const PlaceholderScreen(title: 'Privacy Policy'),
          ),
          GoRoute(
            path: Routes.terms,
            builder: (_, __) => const PlaceholderScreen(title: 'Terms of Service'),
          ),
          GoRoute(
            path: Routes.pointsSystem,
            builder: (_, __) => const PlaceholderScreen(title: 'Points System'),
          ),

          // Student protected
          GoRoute(
            path: Routes.dashboard,
            builder: (_, __) => const PlaceholderScreen(title: 'Dashboard'),
          ),
          GoRoute(
            path: Routes.profile,
            builder: (_, __) => const PlaceholderScreen(title: 'Profile'),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (_, __) => const PlaceholderScreen(title: 'Settings'),
          ),
          GoRoute(
            path: Routes.courses,
            builder: (_, __) => const PlaceholderScreen(title: 'Courses'),
          ),
          GoRoute(
            path: Routes.courseDetail,
            builder: (_, s) => PlaceholderScreen(
              title: 'Course Detail',
              subtitle: 'id=${s.pathParameters['id']}',
            ),
          ),
          GoRoute(
            path: Routes.jobs,
            builder: (_, __) => const PlaceholderScreen(title: 'Jobs'),
          ),
          GoRoute(
            path: Routes.jobDetail,
            builder: (_, s) => PlaceholderScreen(
              title: 'Job Detail',
              subtitle: 'id=${s.pathParameters['id']}',
            ),
          ),
          GoRoute(
            path: Routes.internships,
            builder: (_, __) => const PlaceholderScreen(title: 'Internships'),
          ),
          GoRoute(
            path: Routes.internshipDetail,
            builder: (_, s) => PlaceholderScreen(
              title: 'Internship Detail',
              subtitle: 'id=${s.pathParameters['id']}',
            ),
          ),
          GoRoute(
            path: Routes.applications,
            builder: (_, __) => const PlaceholderScreen(title: 'Applications'),
          ),
          GoRoute(
            path: Routes.favorites,
            builder: (_, __) => const PlaceholderScreen(title: 'Favorites'),
          ),
          GoRoute(
            path: Routes.notifications,
            builder: (_, __) => const PlaceholderScreen(title: 'Notifications'),
          ),
          GoRoute(
            path: Routes.leaderboard,
            builder: (_, __) => const PlaceholderScreen(title: 'Leaderboard'),
          ),
          GoRoute(
            path: Routes.debug,
            builder: (_, __) => const PlaceholderScreen(title: 'Database Debug'),
          ),

          // Company protected
          GoRoute(
            path: Routes.companyDashboard,
            builder: (_, __) =>
                const PlaceholderScreen(title: 'Company Dashboard'),
          ),
          GoRoute(
            path: Routes.companyRegister,
            builder: (_, __) =>
                const PlaceholderScreen(title: 'Register Company'),
          ),
          GoRoute(
            path: Routes.companyJobs,
            builder: (_, __) => const PlaceholderScreen(title: 'Company Jobs'),
          ),
          GoRoute(
            path: Routes.companyJobsCreate,
            builder: (_, __) => const PlaceholderScreen(title: 'Create Job'),
          ),
          GoRoute(
            path: Routes.companyJobsEdit,
            builder: (_, s) => PlaceholderScreen(
              title: 'Edit Job',
              subtitle: 'id=${s.pathParameters['id']}',
            ),
          ),
          GoRoute(
            path: Routes.companyJobApplications,
            builder: (_, s) => PlaceholderScreen(
              title: 'Job Applications',
              subtitle: 'id=${s.pathParameters['id']}',
            ),
          ),
          GoRoute(
            path: Routes.companyInternships,
            builder: (_, __) =>
                const PlaceholderScreen(title: 'Internship Management'),
          ),
          GoRoute(
            path: Routes.companyInternshipsCreate,
            builder: (_, __) =>
                const PlaceholderScreen(title: 'Create Internship'),
          ),
          GoRoute(
            path: Routes.companyInternshipsEdit,
            builder: (_, s) => PlaceholderScreen(
              title: 'Edit Internship',
              subtitle: 'id=${s.pathParameters['id']}',
            ),
          ),
          GoRoute(
            path: Routes.companyInternshipApplications,
            builder: (_, s) => PlaceholderScreen(
              title: 'Internship Applications',
              subtitle: 'id=${s.pathParameters['id']}',
            ),
          ),
          GoRoute(
            path: Routes.companyProfile,
            builder: (_, __) =>
                const PlaceholderScreen(title: 'Company Profile'),
          ),
          GoRoute(
            path: Routes.companyReports,
            builder: (_, __) => const PlaceholderScreen(title: 'Reports'),
          ),
          GoRoute(
            path: Routes.companyApplications,
            builder: (_, __) =>
                const PlaceholderScreen(title: 'Company Applications'),
          ),
          GoRoute(
            path: Routes.companyPricing,
            builder: (_, __) => const PlaceholderScreen(title: 'Pricing'),
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => PlaceholderScreen(
      title: '404',
      subtitle: state.error?.toString(),
    ),
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    stream.listen((_) => notifyListeners());
  }
}

/// Main Shell (temporary)
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Öğrenci Intelligence')),
      body: Column(
        children: [
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
