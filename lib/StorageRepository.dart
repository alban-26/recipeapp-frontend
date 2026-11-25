import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:recipeapp_frontend/api/BaseApiClient.dart';

import 'offline/LocalStore.dart';

class StorageRepository extends BaseApiClient {
  /// Lokale Kopien der Bilder, damit sie auch ohne Verbindung da sind.
  /// Ohne Cache verhaelt sich alles wie bisher.
  final LocalStore? imageCache;

  StorageRepository({
    required super.dio,
    required super.secureStorage,
    required super.baseUrl,
    this.imageCache,
  });

  static String _cacheKey(String url) => 'img_$url';

  /// Liegt das Bild schon lokal vor?
  Future<bool> hasCachedImage(String url) async =>
      await imageCache?.hasBytes(_cacheKey(url)) ?? false;

  /// Lokale Kopie verwerfen (Rezept geloescht).
  Future<void> forgetCachedImage(String url) async =>
      imageCache?.remove(_cacheKey(url));

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

      // Das hochgeladene Bild ist ab jetzt das aktuelle - auch offline.
      await imageCache?.writeBytes(_cacheKey(super.baseUrl + url), bytes);

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

  /// Laedt ein Bild. Online immer frisch vom Server (und merkt es sich),
  /// ohne Verbindung die zuletzt gespeicherte Kopie.
  ///
  /// Mit [cacheOnly] wird das Netz gar nicht erst versucht - fuer Listen, die
  /// ohnehin schon offline aufgebaut werden.
  Future<Uint8List?> loadImage(String url, {bool cacheOnly = false}) async {
    final key = _cacheKey(url);
    if (cacheOnly) return imageCache?.readBytes(key);

    try {
      final response = await dio.get(
        url,
        options: Options(
          headers: _headers,
          responseType: ResponseType.bytes,
        ),
      );
      final bytes = response.data as Uint8List;
      await imageCache?.writeBytes(key, bytes);
      return bytes;
    } on DioException catch (e) {
      // 404 = kein Bild hinterlegt, das ist normal und kein Fehler.
      if (e.response?.statusCode == 404) {
        await imageCache?.remove(key);
        return null;
      }
      print('[StorageRepository] Bild konnte nicht geladen werden '
          '(HTTP ${e.response?.statusCode}): $url');
      return imageCache?.readBytes(key);
    } catch (e) {
      print('[StorageRepository] Bild konnte nicht geladen werden: $e');
      return imageCache?.readBytes(key);
    }
  }
}
