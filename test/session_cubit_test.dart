import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipeapp_frontend/api/AuthClient.dart';
import 'package:recipeapp_frontend/api/AuthInterceptor.dart';
import 'package:recipeapp_frontend/api/TokenStore.dart';
import 'package:recipeapp_frontend/auth/AuthRepository.dart';
import 'package:recipeapp_frontend/offline/LocalStore.dart';
import 'package:recipeapp_frontend/offline/OfflineData.dart';
import 'package:recipeapp_frontend/offline/SyncQueue.dart';
import 'package:recipeapp_frontend/session/SessionCubit.dart';
import 'package:recipeapp_frontend/session/SessionState.dart';
import 'package:recipeapp_frontend/user/User.dart';
import 'package:recipeapp_frontend/user/UserRepository.dart';

const _auth = 'http://auth.local';

/// Access Token, wie Keycloak ihn ausstellt (Signatur ist für die App egal).
String jwt(String sub, String email) {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'RS256'})}.${part({'sub': sub, 'email': email})}.sig';
}

ResponseBody jsonBody(int status, Object body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// Nachgestellter user-management-Service.
class AuthServer implements HttpClientAdapter {
  bool offline = false;
  int meStatus = 200;
  String sub = 'anna-id';
  String email = 'anna@example.org';
  final List<String> log = [];
  final List<Object?> bodies = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    await Future<void>.delayed(Duration.zero);
    if (offline) throw const SocketException('Network is unreachable');
    final request = '${options.method} ${options.uri.path}';
    log.add(request);
    bodies.add(options.data);

    switch (request) {
      case 'GET /users/me':
        if (meStatus != 200) return jsonBody(meStatus, {'message': 'x'});
        return jsonBody(200, {'id': sub, 'username': email});
      case 'POST /users/login':
        return jsonBody(200, {
          'access_token': jwt(sub, email),
          'refresh_token': 'refresh-$sub',
        });
      case 'POST /users/logout':
        return ResponseBody.fromString('Logout successful', 200);
      case 'POST /users/refresh':
        return jsonBody(503, {'error': 'temporarily_unavailable'});
    }
    return jsonBody(404, {'message': 'not found'});
  }

  @override
  void close({bool force = false}) {}
}

class App {
  final AuthServer server;
  final LocalStore store;
  late TokenStore tokens;
  late SyncQueue queue;
  late OfflineData data;
  late AuthRepository authRepo;
  late SessionCubit session;
  var resets = 0;

  App({AuthServer? server, LocalStore? store})
      : server = server ?? AuthServer(),
        store = store ?? MemoryLocalStore();

  /// Startet die App (wie main.dart) und wartet, bis der Start durch ist.
  Future<void> start() async {
    const secure = FlutterSecureStorage();
    tokens = TokenStore(secure);
    final dio = Dio()..httpClientAdapter = server;
    dio.interceptors.add(AuthInterceptor(
      dio: dio,
      refreshDio: Dio()..httpClientAdapter = server,
      tokenStore: tokens,
      authBaseUrl: _auth,
    ));
    queue = SyncQueue(store: store);
    await queue.load();
    data = OfflineData(store: store, queue: queue)..onReset(() => resets++);
    authRepo = AuthRepository(
      authClient: AuthClient(dio: dio, secureStorage: secure, baseUrl: _auth),
      tokenStore: tokens,
    );
    session = SessionCubit(
      authRepo: authRepo,
      userRepository: UserRepository(
        apiClient:
            UserApiClient(dio: dio, secureStorage: secure, baseUrl: _auth),
      ),
      tokenStore: tokens,
      offlineData: data,
    );
    await settle();
  }

  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await pumpEventQueue();
    }
  }
}

void main() {
  void loggedInAs(String sub, String email) {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': jwt(sub, email),
      'refresh_token': 'refresh-$sub',
    });
  }

  group('App-Start', () {
    test('ohne Verbindung bleibt man angemeldet', () async {
      loggedInAs('anna-id', 'anna@example.org');
      final app = App()..server.offline = true;

      await app.start();

      final state = app.session.state;
      expect(state, isA<Authenticated>(),
          reason: 'früher landete man hier auf dem Login-Screen');
      expect((state as Authenticated).user.id, 'anna-id');
      expect(state.user.email, 'anna@example.org');
      expect(await app.tokens.hasSession(), isTrue);
    });

    test('auch wenn der Server gerade Fehler liefert', () async {
      loggedInAs('anna-id', 'anna@example.org');
      final app = App()..server.meStatus = 500;

      await app.start();

      expect(app.session.state, isA<Authenticated>());
    });

    test('ohne gespeicherte Tokens geht es zum Login', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final app = App();

      await app.start();

      expect(app.session.state, isA<Unauthenticated>());
      expect(app.server.log, isEmpty);
    });

    test('online wird der Nutzer im Hintergrund abgeglichen', () async {
      loggedInAs('anna-id', 'alt@example.org');
      final app = App()..server.email = 'neu@example.org';

      await app.start();

      expect(app.server.log, contains('GET /users/me'));
      expect((app.session.state as Authenticated).user.email, 'neu@example.org');
    });
  });

  group('Login', () {
    test('klappt auch, wenn /users/me direkt danach nicht antwortet', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final app = App();
      await app.start();
      expect(app.session.state, isA<Unauthenticated>());

      await app.authRepo.login('anna@example.org', 'geheim');
      app.server.meStatus = 500;
      app.session.showSession();
      await app.settle();

      expect(app.session.state, isA<Authenticated>(),
          reason: 'der Nutzer steht im Token, dafür braucht es den Server nicht');
      expect((app.session.state as Authenticated).user.id, 'anna-id');
    });
  });

  group('Sitzungsende', () {
    test('lehnt der Server den Refresh Token ab, geht es zum Login - '
        'die lokalen Daten bleiben für die nächste Anmeldung', () async {
      loggedInAs('anna-id', 'anna@example.org');
      final app = App();
      await app.start();
      await app.store.writeJson('shopping_lists', [
        {'id': 1, 'title': 'Annas Liste', 'shoppingItems': [], 'createdAt': '2026-01-01'}
      ]);

      final resetsBefore = app.resets;

      await app.tokens.expire('Server lehnte Refresh Token ab');
      await app.settle();

      expect(app.session.state, isA<Unauthenticated>());
      expect(await app.store.readJson('shopping_lists'), isNotNull);
      expect(app.resets, resetsBefore);
    });

    test('Abmelden löscht Tokens und lokale Daten und meldet beim Server ab',
        () async {
      loggedInAs('anna-id', 'anna@example.org');
      final app = App();
      await app.start();
      await app.store.writeJson('shopping_lists', [
        {'id': 1, 'title': 'Annas Liste', 'shoppingItems': [], 'createdAt': '2026-01-01'}
      ]);

      final resetsBefore = app.resets;

      app.session.logout();
      await app.settle();

      expect(app.session.state, isA<Unauthenticated>());
      expect(await app.tokens.hasSession(), isFalse);
      expect(await app.store.readJson('shopping_lists'), isNull);
      expect(app.resets, greaterThan(resetsBefore));
      final logout = app.server.log.indexOf('POST /users/logout');
      expect(logout, isNonNegative);
      expect(app.server.bodies[logout], {'refreshToken': 'refresh-anna-id'});
    });

    test('Abmelden klappt auch ohne Verbindung', () async {
      loggedInAs('anna-id', 'anna@example.org');
      final app = App();
      await app.start();
      app.server.offline = true;

      app.session.logout();
      await app.settle();

      expect(app.session.state, isA<Unauthenticated>());
      expect(await app.tokens.hasSession(), isFalse);
    });
  });

  group('Wem gehören die lokalen Daten?', () {
    Future<LocalStore> storeWithAnnasData() async {
      loggedInAs('anna-id', 'anna@example.org');
      final first = App();
      await first.start();
      await first.store.writeJson('shopping_lists', [
        {'id': 1, 'title': 'Annas Liste', 'shoppingItems': [], 'createdAt': '2026-01-01'}
      ]);
      return first.store;
    }

    test('dieselbe Person nach einem Neustart: alles noch da', () async {
      final store = await storeWithAnnasData();

      final again = App(store: store);
      await again.start();

      expect(again.session.state, isA<Authenticated>());
      expect(await store.readJson('shopping_lists'), isNotNull);
      expect(again.data.isReady, isTrue);
      expect(again.resets, 0);
    });

    test('jemand anderes ist angemeldet: fremde Daten werden verworfen, '
        'bevor irgendetwas davon gezeigt oder gesendet wird', () async {
      final store = await storeWithAnnasData();

      loggedInAs('ben-id', 'ben@example.org');
      final other = App(store: store, server: AuthServer()..offline = true);
      await other.start();

      expect((other.session.state as Authenticated).user.id, 'ben-id');
      expect(await store.readJson('shopping_lists'), isNull);
      expect(other.resets, 1);
    });
  });

  group('User.fromAccessToken', () {
    test('liest sub und email', () {
      final user = User.fromAccessToken(jwt('abc', 'a@b.de'))!;
      expect(user.id, 'abc');
      expect(user.email, 'a@b.de');
    });

    test('fällt auf preferred_username zurück', () {
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'sub': 'abc', 'preferred_username': 'anna'})))
          .replaceAll('=', '');
      expect(User.fromAccessToken('h.$payload.s')!.email, 'anna');
    });

    test('Unlesbares ist null, kein Absturz', () {
      expect(User.fromAccessToken(null), isNull);
      expect(User.fromAccessToken(''), isNull);
      expect(User.fromAccessToken('kein-jwt'), isNull);
      expect(User.fromAccessToken('a.b.c'), isNull);
      expect(User.fromAccessToken('a.${base64Url.encode(utf8.encode('{}'))}.c'), isNull);
    });
  });
}
