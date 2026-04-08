import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stayspot/core/api_client.dart';
import 'package:stayspot/features/auth/data/auth_local_storage.dart';
import 'package:stayspot/features/auth/data/auth_repository.dart';
import 'package:stayspot/shared/models/user_model.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final AuthLocalStorage _storage;
  final ApiClient _apiClient;

  AuthNotifier(this._repository, this._storage, this._apiClient)
      : super(const AuthState());

  Future<void> initialize() async {
    final hasTokens = await _storage.hasTokens();
    if (!hasTokens) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    final accessToken = await _storage.getAccessToken();
    if (accessToken != null) {
      _apiClient.setAuthToken(accessToken);
    }

    try {
      final user = await _repository.getMe();
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Try refresh
        final refreshToken = await _storage.getRefreshToken();
        if (refreshToken != null) {
          try {
            final newAccessToken = await _repository.refreshToken(refreshToken);
            _apiClient.setAuthToken(newAccessToken);
            await _storage.saveTokens(
              accessToken: newAccessToken,
              refreshToken: refreshToken,
            );
            final user = await _repository.getMe();
            state = state.copyWith(status: AuthStatus.authenticated, user: user);
            return;
          } catch (_) {}
        }
      }
      await _storage.clearTokens();
      _apiClient.clearAuthToken();
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);

    try {
      final response = await _repository.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      _apiClient.setAuthToken(response.accessToken);
      await _storage.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: response.user,
      );
    } on DioException catch (e) {
      final message = e.response?.data?['message'] as String? ?? 'Registration failed';
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: message,
      );
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);

    try {
      final response = await _repository.login(
        email: email,
        password: password,
      );
      _apiClient.setAuthToken(response.accessToken);
      await _storage.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: response.user,
      );
    } on DioException catch (e) {
      final message = e.response?.data?['message'] as String? ?? 'Login failed';
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: message,
      );
    }
  }

  Future<void> logout() async {
    await _storage.clearTokens();
    _apiClient.clearAuthToken();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    AuthRepository(),
    AuthLocalStorage(),
    ApiClient(),
  );
});
