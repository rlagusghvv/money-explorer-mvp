import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.email,
    required this.token,
  });

  final String userId;
  final String email;
  final String token;
}

class AuthSyncService {
  AuthSyncService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  Uri _uri(String path) {
    if (_baseUrl.trim().isEmpty) return Uri.parse(path);
    return Uri.parse('$_baseUrl$path');
  }

  Future<AuthSession> signup({
    required String email,
    required String password,
  }) {
    return _auth('/auth/signup', email: email, password: password);
  }

  Future<AuthSession> login({required String email, required String password}) {
    return _auth('/auth/login', email: email, password: password);
  }

  Future<AuthSession> _auth(
    String path, {
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      _uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'password': password,
      }),
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(decoded['error'] ?? 'AUTH_FAILED');
    }

    final user = decoded['user'] as Map<String, dynamic>;
    return AuthSession(
      userId: user['id'] as String,
      email: user['email'] as String,
      token: decoded['token'] as String,
    );
  }

  Future<Map<String, dynamic>?> loadProgress({required String token}) async {
    final response = await _client.get(
      _uri('/progress'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 401) throw Exception('UNAUTHORIZED');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(decoded['error'] ?? 'LOAD_FAILED');
    }
    final progress = decoded['progress'];
    if (progress is Map<String, dynamic>) return progress;
    return null;
  }

  Future<void> saveProgress({
    required String token,
    required Map<String, dynamic> progress,
  }) async {
    final response = await _client.put(
      _uri('/progress'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'progress': progress}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(decoded['error'] ?? 'SAVE_FAILED');
    }
  }
}
