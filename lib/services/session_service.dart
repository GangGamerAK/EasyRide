import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SessionService {
  static const String _userIdKey = 'user_id';
  static const String _userDataKey = 'user_data';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _lastLoginTimeKey = 'last_login_time';

  // Save user session
  static Future<void> saveSession({
    required String userId,
    required Map<String, dynamic> userData,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_userDataKey, jsonEncode(userData));
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setInt(_lastLoginTimeKey, DateTime.now().millisecondsSinceEpoch);
  }

  // Get current user ID
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  // Get current user data
  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString(_userDataKey);
    if (userDataString != null) {
      try {
        return jsonDecode(userDataString) as Map<String, dynamic>;
      } catch (e) {
        print('Error parsing user data: $e');
        return null;
      }
    }
    return null;
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  // Get last login time
  static Future<DateTime?> getLastLoginTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastLoginTimeKey);
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  // Clear session (logout)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_userDataKey);
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_lastLoginTimeKey);
  }

  // Check if session is still valid (optional: add expiration logic)
  static Future<bool> isSessionValid() async {
    final loggedIn = await isLoggedIn();
    if (!loggedIn) return false;

    // Optional: Add session expiration logic
    // For example, expire after 30 days
    final lastLogin = await getLastLoginTime();
    if (lastLogin != null) {
      final daysSinceLogin = DateTime.now().difference(lastLogin).inDays;
      if (daysSinceLogin > 30) {
        await clearSession();
        return false;
      }
    }

    return true;
  }

  // Refresh session (update last login time)
  static Future<void> refreshSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastLoginTimeKey, DateTime.now().millisecondsSinceEpoch);
  }
} 