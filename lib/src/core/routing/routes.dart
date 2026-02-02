class Routes {
  // Public
  static const home = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const emailVerification = '/email-verification';
  static const resetPassword = '/reset-password';

  static const companyAuth = '/company/auth';

  static const adminLogin = '/admin/login';
  static const adminSetup = '/admin/setup';

  // Student (protected)
  static const dashboard = '/dashboard';
  static const profile = '/profile';
  static const settings = '/settings';
  static const courses = '/courses';
  static const courseDetail = '/courses/:id';
  static const jobs = '/jobs';
  static const jobDetail = '/jobs/:id';
  static const internships = '/internships';
  static const internshipDetail = '/internships/:id';
  static const applications = '/applications';
  static const favorites = '/favorites';
  static const notifications = '/notifications';
  static const leaderboard = '/leaderboard';
  static const pointsSystem = '/points-system';
  static const chat = '/chat';
  static const debug = '/debug';

  // Footer pages (public)
  static const howItWorks = '/how-it-works';
  static const about = '/about';
  static const contact = '/contact';
  static const privacy = '/privacy-policy';
  static const terms = '/terms-of-service';

  // Company (protected)
  static const companyDashboard = '/company/dashboard';
  static const companyRegister = '/company/register';
  static const companyJobs = '/company/jobs';
  static const companyJobsCreate = '/company/jobs/create';
  static const companyJobsEdit = '/company/jobs/:id/edit';
  static const companyJobApplications = '/company/jobs/:id/applications';

  static const companyInternships = '/company/internships';
  static const companyInternshipsCreate = '/company/internships/create';
  static const companyInternshipsEdit = '/company/internships/:id/edit';
  static const companyInternshipApplications = '/company/internships/:id/applications';

  static const companyProfile = '/company/profile';
  static const companyReports = '/company/reports';
  static const companyApplications = '/company/applications';
  static const companyPricing = '/company/pricing';

  // Admin (protected)
  static const adminDashboard = '/admin/dashboard';
  static const adminCompanies = '/admin/companies';
  static const adminUsers = '/admin/users';
  static const adminJobs = '/admin/jobs';
  static const adminSubscriptions = '/admin/subscriptions';
  static const adminReports = '/admin/reports';
  static const adminSettings = '/admin/settings';
  static const adminLogs = '/admin/logs';
  static const adminProfile = '/admin/profile';
}
