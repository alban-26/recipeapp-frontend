import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:recipeapp_frontend/api/BaseApiClient.dart';

class StorageRepository extends BaseApiClient {
  StorageRepository({
    required super.dio,
    required super.secureStorage,
    required super.baseUrl,
  });

  // Der Authorization-Header kommt jetzt vom AuthInterceptor.
  // Vorher wurde hier der Key 'auth_token' gelesen, den es nirgendwo gibt -
  // es ging also woertlich "Bearer null" raus.
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
      };

  Future<int> uploadImage(
    Uint8List bytes,
    String filename,
    String url,
  ) async {
    try {
      final formData = FormData.fromMap({
        'id': filename,
        'image': MultipartFile.fromBytes(
          bytes,
          filename: '$filename.png',
          contentType: MediaType('image', 'png'),
        ),
      });

      final response = await dio.post(
        super.baseUrl + url,
        data: formData,
        options: Options(
          headers: _headers,
          contentType: 'multipart/form-data',
          responseType: ResponseType.plain,
        ),
      );

      return response.statusCode ?? 500;
    } catch (e) {
      if (e is DioException) {
        print('Dio error: ${e.message}');
        print('Response data: ${e.response?.data}');
        print('Status code: ${e.response?.statusCode}');
      }
      rethrow;
    }
  }

  Future<Uint8List?> loadImage(String url) async {
    try {
      final response = await dio.get(
        url,
        options: Options(
          headers: _headers,
          responseType: ResponseType.bytes,
        ),
      );
      return response.data as Uint8List;
    } on DioException catch (e) {
      // 404 = kein Bild hinterlegt, das ist normal und kein Fehler.
      if (e.response?.statusCode == 404) return null;
      print('[StorageRepository] Bild konnte nicht geladen werden '
          '(HTTP ${e.response?.statusCode}): $url');
      return null;
    } catch (e) {
      print('[StorageRepository] Bild konnte nicht geladen werden: $e');
      return null;
    }
  }
}
