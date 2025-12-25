import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

/// Service for managing user session in SharedPreferences
class PreferencesService {
  static PreferencesService? _instance;
  static SharedPreferences? _prefs;

  PreferencesService._();

  /// Initialize and get singleton instance
  static Future<PreferencesService> getInstance() async {
    _instance ??= PreferencesService._();
    _prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  /// Check if user is logged in
  bool get isLoggedIn => _prefs?.getBool(AppConstants.keyIsLoggedIn) ?? false;

  /// Get stored user ID
  String? get uid => _prefs?.getString(AppConstants.keyUid);

  /// Get stored user full name
  String? get fullName => _prefs?.getString(AppConstants.keyFullName);

  /// Save user login session
  Future<void> saveLoginSession({
    required String uid,
    required String fullName,
  }) async {
    await _prefs?.setString(AppConstants.keyUid, uid);
    await _prefs?.setString(AppConstants.keyFullName, fullName);
    await _prefs?.setBool(AppConstants.keyIsLoggedIn, true);
  }

  /// Clear user session (logout)
  Future<void> clearSession() async {
    await _prefs?.remove(AppConstants.keyUid);
    await _prefs?.remove(AppConstants.keyFullName);
    await _prefs?.setBool(AppConstants.keyIsLoggedIn, false);
  }
}
