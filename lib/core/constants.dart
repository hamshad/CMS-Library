/// API and app-wide constants
class AppConstants {
  AppConstants._();

  // API Configuration
  static const String baseUrl = 'https://cms.gurumishrihmc.edu.in';
  // static const String baseUrl = 'http://192.168.1.11:8025';

  // Endpoints
  static const String loginEndpoint = '/api/User/Login';
  static const String bookIssuedEndpoint = '/api/Library/BookIssued';
  static const String bookReturnedEndpoint = '/api/Library/BookReturned';

  // SharedPreferences Keys
  static const String keyUid = 'user_uid';
  static const String keyFullName = 'user_full_name';
  static const String keyIsLoggedIn = 'is_logged_in';

  // Animation Durations
  static const Duration splashDuration = Duration(milliseconds: 2500);
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration pageTransitionDuration = Duration(milliseconds: 400);
}
