import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Reine Basisklasse. Enthaelt KEINE Auth-Logik mehr.
///
/// Vorher registrierte jeder Konstruktor einen eigenen Interceptor auf der
/// gemeinsamen Dio-Instanz -> sieben identische Interceptor, sieben
/// Refresh-Versuche pro 401, und der Refresh ging an die baseUrl der
/// zufaellig zuerst registrierten Subklasse.
///
/// [secureStorage] bleibt in der Signatur, damit die sechs Subklassen
/// unveraendert bleiben koennen.
abstract class BaseApiClient {
  final Dio dio;
  final FlutterSecureStorage secureStorage;
  final String baseUrl;

  BaseApiClient({
    required this.dio,
    required this.secureStorage,
    required this.baseUrl,
  });
}
