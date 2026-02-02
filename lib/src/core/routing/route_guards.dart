import '../../features/auth/domain/auth_models.dart';
import 'routes.dart';

class RouteGuards {
  // Mirrors React's studentOnlyPaths (including detail pages)
  static const List<String> _studentRoots = [
    Routes.courses,
    Routes.jobs,
    Routes.internships,
    Routes.applications,
    Routes.favorites,
    Routes.notifications,
    Routes.leaderboard,
    Routes.profile,
    Routes.dashboard,
    Routes.settings,
    Routes.chat,
    Routes.debug,
  ];

  static bool isStudentPath(String location) {
    return _studentRoots.any(
      (root) => location == root || location.startsWith('$root/'),
    );
  }

  /// Treat everything under /company as company area.
  static bool isCompanyPath(String location) =>
      location == '/company' || location.startsWith('/company/');

  /// Treat everything under /admin as admin area (safer than enumerating).
  static bool isAdminPath(String location) =>
      location == '/admin' || location.startsWith('/admin/');

  static bool isPublicPath(String location) {
    const publicExact = <String>{
      Routes.home,
      Routes.login,
      Routes.register,
      Routes.forgotPassword,
      Routes.emailVerification,
      Routes.resetPassword, // ✅ deep link recovery must be public

      // Company auth (public)
      Routes.companyAuth,

      // Admin auth (public)
      Routes.adminLogin,
      Routes.adminSetup,

      // Footer pages (public)
      Routes.howItWorks,
      Routes.about,
      Routes.contact,
      Routes.privacy,
      Routes.terms,

      // React: public
      Routes.pointsSystem,
    };

    return publicExact.contains(location);
  }

  /// Role-based redirects (mirrors GlobalRouteControl + ProtectedRoute behavior)
  static String? redirectForRole({
    required UserType userType,
    required String location,
  }) {
    // Never role-redirect public pages (router handles auth pages separately)
    if (isPublicPath(location)) return null;

    // Admin can access ONLY admin area (recommended)
    if (userType == UserType.admin) {
      if (!isAdminPath(location)) return Routes.adminDashboard;
      return null;
    }

    // Company can access company area, not student/admin
    if (userType == UserType.company) {
      if (isAdminPath(location)) return Routes.companyDashboard;
      if (isStudentPath(location)) return Routes.companyDashboard;
      return null;
    }

    // Student can access student area, not company/admin
    if (userType == UserType.student) {
      if (isAdminPath(location)) return Routes.dashboard;
      if (isCompanyPath(location)) return Routes.dashboard;
      return null;
    }

    // Guest handling is done by router "not authorized" block
    return null;
  }
}
