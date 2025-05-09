import 'dart:convert';

class UserData {
  String username;
  bool isDarkMode;
  DateTime lastUpdated;

  UserData({
    required this.username,
    required this.isDarkMode,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  // Convert to JSON string
  String toJson() {
    return jsonEncode({
      'username': username,
      'isDarkMode': isDarkMode,
      'lastUpdated': lastUpdated.toIso8601String(),
    });
  }

  // Create from JSON string
  factory UserData.fromJson(String jsonString) {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    return UserData(
      username: data['username'] ?? 'Guest',
      isDarkMode: data['isDarkMode'] ?? false,
      lastUpdated: data['lastUpdated'] != null
          ? DateTime.parse(data['lastUpdated'])
          : DateTime.now(),
    );
  }

  // Create from SharedPreferences
  factory UserData.fromPrefs(Map<String, dynamic> prefs) {
    return UserData(
      username: prefs['username'] ?? 'Guest',
      isDarkMode: prefs['darkMode'] ?? false,
    );
  }

  // Clone with new values
  UserData copyWith({
    String? username,
    bool? isDarkMode,
  }) {
    return UserData(
      username: username ?? this.username,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      lastUpdated: DateTime.now(),
    );
  }
}
