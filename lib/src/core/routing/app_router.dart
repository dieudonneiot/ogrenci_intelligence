import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/email_verification_screen.dart';
import '../../features/auth/presentation/screens/company_auth_screen.dart';
import '../../shared/widgets/empty_state.dart';
import 'route_guards.dart';
import 'routes.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authStream = ref.watch(authViewStateProvider.stream);

  return GoRouter(
    initialLocation: Routes.home,
    refreshListenable: GoRouterRefreshStream(authStream),

    redirect: (context, state) {
      final location = state.uri.path;

      final authAsync = ref.read(authViewStateProvider);
      if (authAsync.isLoading) return null;

      final auth = authAsync.value;
      if (auth == null) return null;

      // ✅ Always allow reset-password (recovery deep-link flow)
      if (location == Routes.resetPassword) return null;

      final isAuthorized = auth.isAuthenticated;

      // 1) Not authorized: only public routes allowed
      if (!isAuthorized) {
        return RouteGuards.isPublicPath(location) ? null : Routes.login;
      }

      // 2) Authorized: keep signed-in users out of auth pages
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

      // 3) Authorized: role-based protection for protected areas
      final roleRedirect = RouteGuards.redirectForRole(
        userType: auth.userType,
        location: location,
      );
      if (roleRedirect != null) return roleRedirect;

      // 4) Optional: redirect "/" for admin/company only (students can see home)
      if (location == Routes.home) {
        if (auth.userType == UserType.admin) return Routes.adminDashboard;
        if (auth.userType == UserType.company) return Routes.companyDashboard;
      }

      return null;
    },

    routes: [
      // Admin auth routes (standalone)
      GoRoute(
        path: Routes.adminLogin,
        builder: (_, __) =>
            const PlaceholderScreen(title: 'Admin Login', showAppBar: true),
      ),
      GoRoute(
        path: Routes.adminSetup,
        builder: (_, __) =>
            const PlaceholderScreen(title: 'Admin Setup', showAppBar: true),
      ),

      // Admin area shell
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: Routes.adminDashboard,
            builder: (_, __) => const PlaceholderView(title: 'Admin Dashboard'),
          ),
          GoRoute(
            path: Routes.adminCompanies,
            builder: (_, __) => const PlaceholderView(title: 'Admin Companies'),
          ),
          GoRoute(
            path: Routes.adminUsers,
            builder: (_, __) => const PlaceholderView(title: 'Admin Users'),
          ),
          GoRoute(
            path: Routes.adminJobs,
            builder: (_, __) => const PlaceholderView(title: 'Admin Jobs'),
          ),
          GoRoute(
            path: Routes.adminSubscriptions,
            builder: (_, __) =>
                const PlaceholderView(title: 'Admin Subscriptions'),
          ),
          GoRoute(
            path: Routes.adminReports,
            builder: (_, __) => const PlaceholderView(title: 'Admin Reports'),
          ),
          GoRoute(
            path: Routes.adminSettings,
            builder: (_, __) => const PlaceholderView(title: 'Admin Settings'),
          ),
          GoRoute(
            path: Routes.adminLogs,
            builder: (_, __) => const PlaceholderView(title: 'Admin Logs'),
          ),
          GoRoute(
            path: Routes.adminProfile,
            builder: (_, __) => const PlaceholderView(title: 'Admin Profile'),
          ),
        ],
      ),

      // Main shell (public + student + company)
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: Routes.home,
            builder: (_, __) => const PlaceholderView(title: 'Home'),
          ),

          // Real auth screens
          GoRoute(
            path: Routes.login,
            builder: (context, state) => LoginScreen(
              from: state.uri.queryParameters['from'],
            ),
          ),
          GoRoute(
            path: Routes.register,
            builder: (_, __) => const RegisterScreen(),
          ),
          GoRoute(
            path: Routes.forgotPassword,
            builder: (_, __) => const ForgotPasswordScreen(),
          ),
          GoRoute(
            path: Routes.emailVerification,
            builder: (context, state) => EmailVerificationScreen(
              emailHint: state.uri.queryParameters['email'],
            ),
          ),
          GoRoute(
            path: Routes.resetPassword,
            builder: (_, __) => const ResetPasswordScreen(),
          ),
          GoRoute(
            path: Routes.companyAuth,
            builder: (_, __) => const CompanyAuthScreen(),
          ),
          GoRoute(
            path: Routes.companyRegister,
            builder: (_, __) => const CompanyAuthScreen(initialIsLogin: false),
          ),
          // Footer pages (public)
          GoRoute(
            path: Routes.howItWorks,
            builder: (_, __) => const PlaceholderView(title: 'How It Works'),
          ),
          GoRoute(
            path: Routes.about,
            builder: (_, __) => const PlaceholderView(title: 'About'),
          ),
          GoRoute(
            path: Routes.contact,
            builder: (_, __) => const PlaceholderView(title: 'Contact'),
          ),
          GoRoute(
            path: Routes.privacy,
            builder: (_, __) => const PlaceholderView(title: 'Privacy Policy'),
          ),
          GoRoute(
            path: Routes.terms,
            builder: (_, __) => const PlaceholderView(title: 'Terms of Service'),
          ),
          GoRoute(
            path: Routes.pointsSystem,
            builder: (_, __) => const PlaceholderView(title: 'Points System'),
          ),

          // Student protected
          GoRoute(
            path: Routes.dashboard,
            builder: (_, __) => const PlaceholderView(title: 'Dashboard'),
          ),
          GoRoute(
            path: Routes.profile,
            builder: (_, __) => const PlaceholderView(title: 'Profile'),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (_, __) => const PlaceholderView(title: 'Settings'),
          ),
          GoRoute(
            path: Routes.courses,
            builder: (_, __) => const PlaceholderView(title: 'Courses'),
          ),
          GoRoute(
            path: Routes.courseDetail,
            builder: (_, s) => PlaceholderView(
              title: 'Course Detail',
              subtitle: 'id=${s.pathParameters['id']}',
            ),
          ),
          GoRoute(
            path: Routes.jobs,
            builder: (_, __) => const PlaceholderView(title: 'Jobs'),
          ),
          GoRoute(
            path: Routes.jobDetail,
            builder: (_, s) => PlaceholderView(
              title: 'Job Detail',
              subtitle: 'id=${s.pathParameters['id']}',
            ),
          ),
          GoRoute(
            path: Routes.internships,
            builder: (_, __) => const PlaceholderView(title: 'Internships'),
          ),
          GoRoute(
            path: Routes.internshipDetail,
            builder: (_, s) => PlaceholderView(
              title: 'Internship Detail',
              subtitle: 'id=${s.pathParameters['id']}',
            ),
          ),
          GoRoute(
            path: Routes.applications,
            builder: (_, __) => const PlaceholderView(title: 'Applications'),
          ),
          GoRoute(
            path: Routes.favorites,
            builder: (_, __) => const PlaceholderView(title: 'Favorites'),
          ),
          GoRoute(
            path: Routes.notifications,
            builder: (_, __) => const PlaceholderView(title: 'Notifications'),
          ),
          GoRoute(
            path: Routes.leaderboard,
            builder: (_, __) => const PlaceholderView(title: 'Leaderboard'),
          ),
          GoRoute(
            path: Routes.debug,
            builder: (_, __) => const PlaceholderView(title: 'Database Debug'),
          ),

          // Company protected
          GoRoute(
            path: Routes.companyDashboard,
            builder: (_, __) => const PlaceholderView(title: 'Company Dashboard'),
          ),
          GoRoute(
            path: Routes.companyRegister,
            builder: (_, __) => const PlaceholderView(title: 'Register Company'),
          ),
          GoRoute(
            path: Routes.companyJobs,
            builder: (_, __) => const PlaceholderView(title: 'Company Jobs'),
          ),
          GoRoute(
            path: Routes.companyJobsCreate,
            builder: (_, __) => const PlaceholderView(title: 'Create Job'),
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
            builder: (_, __) =>
                const PlaceholderView(title: 'Internship Management'),
          ),
          GoRoute(
            path: Routes.companyInternshipsCreate,
            builder: (_, __) => const PlaceholderView(title: 'Create Internship'),
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
            builder: (_, __) => const PlaceholderView(title: 'Company Profile'),
          ),
          GoRoute(
            path: Routes.companyReports,
            builder: (_, __) => const PlaceholderView(title: 'Reports'),
          ),
          GoRoute(
            path: Routes.companyApplications,
            builder: (_, __) =>
                const PlaceholderView(title: 'Company Applications'),
          ),
          GoRoute(
            path: Routes.companyPricing,
            builder: (_, __) => const PlaceholderView(title: 'Pricing'),
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
