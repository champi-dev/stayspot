import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stayspot/core/constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(_AuthInterceptor(dio));

    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  void setAuthToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearAuthToken() {
    dio.options.headers.remove('Authorization');
  }
}

class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  bool _isRefreshing = false;

  _AuthInterceptor(this._dio);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // Don't retry auth endpoints themselves
    final path = err.requestOptions.path;
    if (path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/refresh')) {
      return handler.next(err);
    }

    // Don't retry if no auth header was sent (public endpoint)
    if (err.requestOptions.headers['Authorization'] == null) {
      return handler.next(err);
    }

    // Prevent concurrent refreshes
    if (_isRefreshing) {
      return handler.next(err);
    }

    _isRefreshing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');

      if (refreshToken == null) {
        _isRefreshing = false;
        return handler.next(err);
      }

      // Call refresh endpoint with a fresh Dio instance (no interceptors)
      final refreshDio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
      final response = await refreshDio.post('/auth/refresh', data: {
        'refreshToken': refreshToken,
      });

      final newAccessToken = response.data['accessToken'] as String;

      // Save new token
      await prefs.setString('access_token', newAccessToken);

      // Update default header
      _dio.options.headers['Authorization'] = 'Bearer $newAccessToken';

      // Retry the original request
      final opts = err.requestOptions;
      opts.headers['Authorization'] = 'Bearer $newAccessToken';
      final retryResponse = await _dio.fetch(opts);

      _isRefreshing = false;
      return handler.resolve(retryResponse);
    } on DioException {
      // Refresh failed — clear tokens, user needs to re-login
      _isRefreshing = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      _dio.options.headers.remove('Authorization');
      return handler.next(err);
    }
  }
}
