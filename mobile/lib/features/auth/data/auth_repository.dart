import 'package:stayspot/core/api_client.dart';
import 'package:stayspot/shared/models/user_model.dart';

class AuthRepository {
  final ApiClient _api = ApiClient();

  Future<AuthResponse> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final response = await _api.dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
    });
    return AuthResponse.fromJson(response.data);
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return AuthResponse.fromJson(response.data);
  }

  Future<String> refreshToken(String refreshToken) async {
    final response = await _api.dio.post('/auth/refresh', data: {
      'refreshToken': refreshToken,
    });
    return response.data['accessToken'] as String;
  }

  Future<UserModel> getMe() async {
    final response = await _api.dio.get('/auth/me');
    return UserModel.fromJson(response.data['user']);
  }
}

class AuthResponse {
  final UserModel user;
  final String accessToken;
  final String refreshToken;

  const AuthResponse({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: UserModel.fromJson(json['user']),
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );
  }
}
