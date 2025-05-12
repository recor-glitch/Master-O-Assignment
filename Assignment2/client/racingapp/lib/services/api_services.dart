import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Change this URL based on your environment
  // For Android emulator:
  static const String baseUrl = 'http://10.0.2.2:3000/api';
  // For iOS simulator:
  // static const String baseUrl = 'http://localhost:3000/api';
  // For physical device on same network as your computer:
  // static const String baseUrl = 'http://YOUR_COMPUTER_IP:3000/api';

  // Game Session API calls

  // Record a new game session
  static Future<Map<String, dynamic>> saveGameSession({
    required int? id,
    required String playerName,
    required int score,
    required int timePlayed,
    Map<String, dynamic>? deviceInfo,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/game-sessions'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id': id,
          'playerName': playerName,
          'score': score,
          'timePlayed': timePlayed,
          'deviceInfo': deviceInfo ??
              {
                'platform': 'Flutter',
                'screenWidth': 0,
                'screenHeight': 0,
              },
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to save game session: ${response.statusCode}');
      }
    } catch (e) {
      print('Network error details: $e');
      throw Exception('Network error: $e');
    }
  }

  // Record a game action
  static Future<void> saveGameAction({
    required int sessionId,
    required String actionType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/game-actions'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sessionId': sessionId,
          'actionType': actionType,
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to save game action: ${response.statusCode}');
      }
    } catch (e) {
      // Log error but don't crash the game
      print('Error saving game action: $e');
    }
  }

  // Get all game sessions
  static Future<List<dynamic>> getGameSessions() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/game-sessions'));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
            'Failed to fetch game sessions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get game statistics
  static Future<Map<String, dynamic>> getStatistics() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/statistics'));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch statistics: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Generate custom report
  static Future<String> generateReport({
    required List<String> metrics,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reports/csv'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'metrics': metrics,
          'dateRange': {
            'start': startDate?.toIso8601String(),
            'end': endDate?.toIso8601String(),
          },
        }),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success']) {
          return 'http://10.0.2.2:3000${result['downloadUrl']}';
        } else {
          throw Exception('Failed to generate report: ${result['error']}');
        }
      } else {
        throw Exception('Failed to generate report: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
