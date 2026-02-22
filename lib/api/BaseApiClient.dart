import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class BaseApiClient {
  final Dio dio;
  final FlutterSecureStorage secureStorage;
  final String baseUrl;

  BaseApiClient({
    required this.dio,
    required this.secureStorage,
    required this.baseUrl,
  }) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: _addAuthorizationHeader,
      onError: _handleError,
    ));
  }

  Future<void> _addAuthorizationHeader(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await secureStorage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  Future<void> _handleError(
      DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      try {
        await _refreshToken();
        final newAccessToken = await secureStorage.read(key: 'access_token');
        if (newAccessToken == null) {

          throw DioException(
            requestOptions: err.requestOptions,
            error: 'Authentication failed',
          );
        }

        final response = await dio.fetch(err.requestOptions);
        handler.resolve(response);
      } catch (e) {

        await secureStorage.delete(key: 'access_token');
        await secureStorage.delete(key: 'refresh_token');
        handler.next(err);
      }
    } else {
      handler.next(err);
    }
  }

  Future<void> _refreshToken() async {
    await secureStorage.delete(key: 'access_token');
    final refreshToken = await secureStorage.read(key: 'refresh_token');
    if (refreshToken == null) return;

    try {
      final response = await dio.post(
        '$baseUrl/users/refresh',
        data: {'refreshToken': refreshToken},
      );

      await secureStorage.write(
        key: 'access_token',
        value: response.data['access_token'],
      );
      await secureStorage.write(
        key: 'refresh_token',
        value: response.data['refresh_token'],
      );
    } catch (e) {

      await secureStorage.deleteAll();
      rethrow;
    }
  }
}
