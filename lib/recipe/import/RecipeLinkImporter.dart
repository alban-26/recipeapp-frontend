import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../domain/Recipe.dart';
import 'RecipeWebParser.dart';

/// Fehler beim Import mit einer Meldung fuer den Nutzer.
class RecipeImportException implements Exception {
  final String message;

  const RecipeImportException(this.message);

  static const noLink = RecipeImportException('Im geteilten Text ist kein Link.');
  static const unreachable =
      RecipeImportException('Die Seite konnte nicht geladen werden. Bist du online?');
  static const notAWebPage = RecipeImportException('Der Link führt nicht zu einer Webseite.');
  static const tooLarge = RecipeImportException('Die Seite ist zu umfangreich für den Import.');
  static const noRecipe = RecipeImportException(
      'Auf dieser Seite wurden keine Rezeptdaten gefunden. '
      'Tipp: Bildschirmfoto machen und „Rezept scannen“ verwenden.');

  static RecipeImportException refused(int status) =>
      RecipeImportException('Die Seite hat den Abruf abgelehnt (Fehler $status).');

  @override
  String toString() => message;
}

/// Eine geladene Seite. [url] ist die Adresse nach allen Weiterleitungen.
class FetchedPage {
  final Uri url;
  final String html;

  const FetchedPage({required this.url, required this.html});
}

/// Laedt Webseiten und Bilder fuer den Import.
abstract class WebPageFetcher {
  Future<FetchedPage> fetchPage(Uri url);

  /// Bilddaten oder null, wenn unter der Adresse kein Bild liegt.
  Future<Uint8List?> fetchImage(Uri url);
}

/// Laedt fremde Seiten mit einem EIGENEN Client: ohne Login-Token und ohne die
/// Erreichbarkeits-Anzeige des eigenen Servers.
class DioWebPageFetcher implements WebPageFetcher {
  static const _maxPageBytes = 5 * 1024 * 1024;
  static const _maxImageBytes = 10 * 1024 * 1024;

  final Dio _dio;

  DioWebPageFetcher({Dio? dio}) : _dio = dio ?? Dio(defaultOptions());

  static BaseOptions defaultOptions() => BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        followRedirects: true,
        maxRedirects: 5,
        responseType: ResponseType.stream,
        headers: const {
          // Manche Seiten liefern einfachen Programmen keine oder eine
          // andere Seite aus; deshalb die Kennung eines mobilen Browsers.
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36 LoveYourMeal/1.0',
          'Accept': 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'de-CH,de;q=0.9,en;q=0.7',
        },
      );

  @override
  Future<FetchedPage> fetchPage(Uri url) async {
    final Response<ResponseBody> response;
    try {
      response = await _dio.getUri<ResponseBody>(url);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != null && status >= 400) throw RecipeImportException.refused(status);
      throw RecipeImportException.unreachable;
    }

    final contentType = response.headers.value(Headers.contentTypeHeader) ?? '';
    if (contentType.isNotEmpty &&
        !contentType.contains('html') &&
        !contentType.contains('xml') &&
        !contentType.contains('text/plain')) {
      await response.data?.stream.drain<void>().catchError((_) {});
      throw RecipeImportException.notAWebPage;
    }

    final bytes = await _readLimited(response.data!, _maxPageBytes);
    if (bytes == null) throw RecipeImportException.tooLarge;

    return FetchedPage(url: response.realUri, html: decodeHtml(bytes, contentType));
  }

  @override
  Future<Uint8List?> fetchImage(Uri url) async {
    try {
      final response = await _dio.getUri<ResponseBody>(
        url,
        options: Options(headers: const {'Accept': 'image/*'}),
      );
      final contentType = response.headers.value(Headers.contentTypeHeader) ?? '';
      if (!contentType.startsWith('image/')) {
        await response.data?.stream.drain<void>().catchError((_) {});
        return null;
      }
      final bytes = await _readLimited(response.data!, _maxImageBytes);
      return bytes == null ? null : Uint8List.fromList(bytes);
    } on DioException {
      return null;
    }
  }

  /// Liest hoechstens [max] Bytes; mehr ergibt null.
  static Future<List<int>?> _readLimited(ResponseBody body, int max) async {
    final buffer = BytesBuilder(copy: false);
    final completer = Completer<List<int>?>();
    late StreamSubscription<Uint8List> subscription;
    subscription = body.stream.listen(
      (chunk) {
        buffer.add(chunk);
        if (buffer.length > max) {
          subscription.cancel();
          if (!completer.isCompleted) completer.complete(null);
        }
      },
      onError: (Object error, StackTrace stack) {
        if (!completer.isCompleted) completer.completeError(RecipeImportException.unreachable);
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete(buffer.takeBytes());
      },
      cancelOnError: true,
    );
    return completer.future;
  }

  /// UTF-8, ausser Server oder Seite nennen ausdruecklich Latin-1/Windows-1252.
  static String decodeHtml(List<int> bytes, String contentType) {
    String? charset = RegExp(r'charset\s*=\s*"?([\w-]+)', caseSensitive: false)
        .firstMatch(contentType)
        ?.group(1);
    if (charset == null) {
      final head = latin1.decode(bytes.length > 4096 ? bytes.sublist(0, 4096) : bytes);
      charset = RegExp(r'''<meta[^>]+charset\s*=\s*["']?([\w-]+)''', caseSensitive: false)
          .firstMatch(head)
          ?.group(1);
    }
    switch (charset?.toLowerCase()) {
      case 'iso-8859-1':
      case 'iso-8859-15':
      case 'latin1':
      case 'windows-1252':
      case 'cp1252':
        return latin1.decode(bytes, allowInvalid: true);
      default:
        return utf8.decode(bytes, allowMalformed: true);
    }
  }
}

/// Ergebnis eines Imports, bereit fuer das Formular.
class RecipeImportResult {
  final Recipe recipe;
  final Uint8List? image;
  final Uri source;

  const RecipeImportResult({required this.recipe, required this.source, this.image});
}

/// Holt ein Rezept von einer Webseite.
class RecipeLinkImporter {
  final WebPageFetcher fetcher;

  RecipeLinkImporter({WebPageFetcher? fetcher}) : fetcher = fetcher ?? DioWebPageFetcher();

  /// [sharedText] darf der reine Link sein oder ein Text, der ihn enthaelt.
  Future<RecipeImportResult> import(String sharedText) async {
    final url = RecipeWebParser.extractFirstUrl(sharedText);
    if (url == null) throw RecipeImportException.noLink;

    final FetchedPage page;
    try {
      page = await fetcher.fetchPage(url);
    } on RecipeImportException {
      rethrow;
    } catch (_) {
      throw RecipeImportException.unreachable;
    }

    final draft = RecipeWebParser.parse(page.html, page.url);
    if (draft == null ||
        (draft.recipe.recipeIngredients.isEmpty && draft.recipe.cookingInstructions.isEmpty)) {
      throw RecipeImportException.noRecipe;
    }

    Uint8List? image;
    final imageUrl = draft.imageUrl;
    if (imageUrl != null) {
      try {
        image = await fetcher.fetchImage(imageUrl);
      } catch (_) {
        image = null; // Ohne Bild ist das Rezept trotzdem brauchbar.
      }
    }

    return RecipeImportResult(recipe: draft.recipe, source: page.url, image: image);
  }
}
