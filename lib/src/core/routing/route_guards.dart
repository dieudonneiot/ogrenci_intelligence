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
    Routes.debug,
  ];

  // Mirrors adminPaths (including subroutes)
  static const List<String> _adminRoots = [
    Routes.adminDashboard,
    Routes.adminCompanies,
    Routes.adminUsers,
    Routes.adminJobs,
    Routes.adminSubscriptions,
    Routes.adminReports,
    Routes.adminSettings,
    Routes.adminLogs,
    Routes.adminProfile,
  ];

  static bool isStudentPath(String location) {
    return _studentRoots.any(
      (root) => location == root || location.startsWith('$root/'),
    );
  }

  static bool isCompanyPath(String location) => location.startsWith('/company/');

  static bool isAdminPath(String location) {
    return _adminRoots.any(
      (root) => location == root || location.startsWith('$root/'),
    );
  }

  static bool isPublicPath(String location) {
    const publicExact = <String>{
      Routes.home,
      Routes.login,
      Routes.register,
      Routes.forgotPassword,
      Routes.emailVerification,
      Routes.resetPassword, // ✅ important for deep link reset flow

      Routes.companyAuth,

      Routes.adminLogin,
      Routes.adminSetup,

      Routes.howItWorks,
      Routes.about,
      Routes.contact,
      Routes.privacy,
      Routes.terms,

      // In your React app, this route is NOT protected
      Routes.pointsSystem,
    };
    return publicExact.contains(location);
  }

  /// Role-based redirects (mirrors GlobalRouteControl + ProtectedRoute behavior)
  static String? redirectForRole({
    required UserType userType,
    required String location,
  }) {
    // Company account trying to access student routes
    if (userType == UserType.company && isStudentPath(location)) {
      return Routes.companyDashboard;
    }

    // Student trying to access company routes
    if (userType == UserType.student && isCompanyPath(location)) {
      return Routes.dashboard;
    }

    // Non-admin trying to access admin routes (except setup/login)
    if (userType != UserType.admin &&
        isAdminPath(location) &&
        location != Routes.adminSetup &&
        location != Routes.adminLogin) {
      return userType == UserType.company
          ? Routes.companyDashboard
          : Routes.dashboard;
    }

    return null;
  }
}
