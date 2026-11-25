import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipeapp_frontend/api/AuthInterceptor.dart';
import 'package:recipeapp_frontend/api/TokenStore.dart';

const _auth = 'http://auth.local';
const _api = 'http://api.local';

/// Antwortet auf alles mit dem, was [respond] liefert.
class StubAdapter implements HttpClientAdapter {
  FutureOr<ResponseBody> Function(RequestOptions options) respond;
  final List<RequestOptions> requests = [];

  StubAdapter(this.respond);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    await Future<void>.delayed(Duration.zero);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(int status, Object body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// Sicherer Speicher, dessen Lesezugriffe scheitern (Keystore/Keychain gerade
/// nicht verfügbar).
///
/// Über noSuchMethod statt überschriebener Methoden, damit der Test nicht an
/// der genauen Signatur einer bestimmten flutter_secure_storage-Version hängt.
class UnreadableStorage implements FlutterSecureStorage {
  int reads = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #read) {
      reads++;
      return Future<String?>.error(
        PlatformException(code: 'Exception', message: 'Keystore unavailable'),
      );
    }
    if (invocation.memberName == #delete || invocation.memberName == #write) {
      fail('Bei einem Lesefehler darf nichts gelöscht oder geschrieben werden');
    }
    return super.noSuchMethod(invocation);
  }
}

class Setup {
  final TokenStore tokens;
  final Dio dio;
  final StubAdapter api;
  final StubAdapter refresh;
  var expired = 0;

  Setup._(this.tokens, this.dio, this.api, this.refresh) {
    tokens.onSessionExpired.listen((_) => expired++);
  }

  /// [validToken]: nur damit lässt die API durch, sonst 401.
  factory Setup({
    FlutterSecureStorage? storage,
    required String validToken,
    required FutureOr<ResponseBody> Function(RequestOptions) onRefresh,
  }) {
    final tokens = TokenStore(storage ?? const FlutterSecureStorage());
    final api = StubAdapter((options) {
      if (options.headers['Authorization'] == 'Bearer $validToken') {
        return json(200, {'ok': true});
      }
      return json(401, {'message': 'unauthorized'});
    });
    final refresh = StubAdapter(onRefresh);
    final dio = Dio()..httpClientAdapter = api;
    final refreshDio = Dio()..httpClientAdapter = refresh;
    dio.interceptors.add(AuthInterceptor(
      dio: dio,
      refreshDio: refreshDio,
      tokenStore: tokens,
      authBaseUrl: _auth,
    ));
    return Setup._(tokens, dio, api, refresh);
  }

  Future<int?> get() async {
    try {
      return (await dio.get('$_api/recipes')).statusCode;
    } on DioException catch (e) {
      return e.response?.statusCode ?? -1;
    }
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'old-access',
      'refresh_token': 'old-refresh',
    });
  });

  test('abgelaufener Access Token wird erneuert, der Request wiederholt',
      () async {
    final s = Setup(
      validToken: 'new-access',
      onRefresh: (options) {
        expect((options.data as Map)['refreshToken'], 'old-refresh');
        return json(200,
            {'access_token': 'new-access', 'refresh_token': 'new-refresh'});
      },
    );

    expect(await s.get(), 200);
    expect(await s.tokens.readAccessToken(), 'new-access');
    expect(await s.tokens.readRefreshToken(), 'new-refresh');
    expect(s.expired, 0);
  });

  group('Session bleibt bestehen, wenn der Refresh nur vorübergehend scheitert',
      () {
    Future<void> expectSessionKept(
        FutureOr<ResponseBody> Function(RequestOptions) onRefresh) async {
      final s = Setup(validToken: 'new-access', onRefresh: onRefresh);

      expect(await s.get(), 401);

      expect(s.expired, 0, reason: 'kein Logout');
      expect(await s.tokens.readRefreshToken(), 'old-refresh',
          reason: 'Tokens müssen erhalten bleiben');
      expect(await s.tokens.readAccessToken(), 'old-access');
    }

    // Genau das hat der user-management-Service bisher geschickt, wenn er
    // Keycloak nicht erreichen konnte - und die App hat daraufhin ausgeloggt.
    test('bisheriger Server: 400 invalid_grant, weil Keycloak nicht erreichbar war',
        () => expectSessionKept((_) => json(400, {
              'error': 'invalid_grant',
              'error_description': 'Connection refused: keycloak/172.18.0.5:8080',
            })));

    test('bisheriger Server: 400 invalid_grant, weil Keycloak 503 geliefert hat',
        () => expectSessionKept((_) => json(400, {
              'error': 'invalid_grant',
              'error_description': 'Refresh failed: 503',
            })));

    test('bisheriger Server: Keycloak lehnt den CLIENT ab (falsches Secret)',
        () => expectSessionKept((_) => json(400, {
              'error': 'invalid_grant',
              'error_description': 'Refresh failed: 401',
            })));

    test('neuer Server: 503 temporarily_unavailable',
        () => expectSessionKept((_) => json(503, {
              'error': 'temporarily_unavailable',
              'error_description': 'Refresh failed: auth server unreachable',
              'session_expired': false,
            })));

    test('neuer Server: 400 wegen fehlerhafter Anfrage',
        () => expectSessionKept((_) => json(400, {
              'error': 'invalid_request',
              'error_description': 'refreshToken is missing',
              'session_expired': false,
            })));

    test('kein Netz', () => expectSessionKept(
        (_) => throw const SocketException('Network is unreachable')));

    test('Gateway-Fehlerseite statt JSON', () => expectSessionKept(
        (_) => ResponseBody.fromString('<html>502 Bad Gateway</html>', 502)));

    test('400 ohne verwertbaren Inhalt', () => expectSessionKept(
        (_) => ResponseBody.fromString('Bad Request', 400)));
  });

  group('Session endet, wenn der Refresh Token wirklich abgelehnt wurde', () {
    Future<void> expectSessionEnded(Object body) async {
      final s = Setup(validToken: 'new-access', onRefresh: (_) => json(400, body));

      expect(await s.get(), 401);
      await pumpEventQueue();

      expect(s.expired, 1);
      expect(await s.tokens.readRefreshToken(), isNull);
      expect(await s.tokens.readAccessToken(), isNull);
    }

    test('bisheriger Server: Keycloak antwortet 400',
        () => expectSessionEnded({
              'error': 'invalid_grant',
              'error_description': 'Refresh failed: 400',
            }));

    test('neuer Server: session_expired = true',
        () => expectSessionEnded({
              'error': 'invalid_grant',
              'error_description': 'Refresh failed: 400',
              'session_expired': true,
            }));
  });

  test('Token-Speicher nicht lesbar: kein Logout, nichts wird gelöscht',
      () async {
    final storage = UnreadableStorage();
    final s = Setup(
      storage: storage,
      validToken: 'new-access',
      onRefresh: (_) => fail('ohne Token darf kein Refresh rausgehen'),
    );

    expect(await s.get(), 401);
    expect(s.expired, 0);
    expect(storage.reads, greaterThan(1), reason: 'mehrfach versucht');
    expect(await s.tokens.hasSession(), isTrue,
        reason: 'ein Lesefehler ist kein Beweis für "nicht angemeldet"');
  });

  test('zehn parallele 401 lösen genau einen Refresh aus', () async {
    final s = Setup(
      validToken: 'new-access',
      onRefresh: (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return json(200,
            {'access_token': 'new-access', 'refresh_token': 'new-refresh'});
      },
    );

    final results = await Future.wait([for (var i = 0; i < 10; i++) s.get()]);

    expect(results, everyElement(200));
    expect(s.refresh.requests, hasLength(1));
  });

  test('ein verspäteter 401 nach bereits erfolgtem Refresh löst keinen zweiten aus',
      () async {
    final s = Setup(
      validToken: 'new-access',
      onRefresh: (_) => json(200,
          {'access_token': 'new-access', 'refresh_token': 'new-refresh'}),
    );
    // Der zweite Request ging noch mit dem alten Token raus; seine Antwort
    // kommt aber erst, nachdem der erste den Token schon erneuert hat.
    final gate = Completer<void>();
    final original = s.api.respond;
    var first = true;
    s.api.respond = (options) async {
      if (options.headers['Authorization'] == 'Bearer old-access' && !first) {
        await gate.future;
      }
      first = false;
      return original(options);
    };

    final a = s.get();
    final b = s.get();
    expect(await a, 200);
    gate.complete();
    expect(await b, 200);

    expect(s.refresh.requests, hasLength(1));
  });

  test('der Ablauf einer alten Session löscht keinen frischen Login', () async {
    final answer = Completer<ResponseBody>();
    final s = Setup(validToken: 'x', onRefresh: (_) => answer.future);

    // Ein alter Request läuft in den Refresh ...
    final stale = s.get();
    await pumpEventQueue();
    expect(s.refresh.requests, hasLength(1));

    // ... inzwischen meldet sich der Nutzer neu an ...
    await s.tokens.clear();
    await s.tokens.save(accessToken: 'login-access', refreshToken: 'login-refresh');

    // ... und erst jetzt lehnt der Server den ALTEN Refresh Token ab.
    answer.complete(json(400, {
      'error': 'invalid_grant',
      'error_description': 'Refresh failed: 400',
      'session_expired': true,
    }));
    await stale;
    await pumpEventQueue();

    expect(s.expired, 0);
    expect(await s.tokens.readRefreshToken(), 'login-refresh');
    expect(await s.tokens.readAccessToken(), 'login-access');
  });

  test('ein Refresh, der nach dem Abmelden zurückkommt, meldet nicht wieder an',
      () async {
    final answer = Completer<ResponseBody>();
    final s = Setup(validToken: 'new-access', onRefresh: (_) => answer.future);

    final pending = s.get();
    await pumpEventQueue();
    await s.tokens.clear(); // Nutzer meldet sich ab

    answer.complete(json(200,
        {'access_token': 'new-access', 'refresh_token': 'new-refresh'}));
    await pending;

    expect(await s.tokens.readRefreshToken(), isNull);
    expect(await s.tokens.hasSession(), isFalse);
  });

  test('öffentliche Endpunkte bekommen keinen (evtl. abgelaufenen) Token mit',
      () async {
    final s = Setup(validToken: 'new-access', onRefresh: (_) => fail('kein Refresh'));
    s.api.respond = (options) => json(200, {});

    for (final path in ['login', 'refresh', 'register', 'forgot-password', 'logout']) {
      await s.dio.post('$_auth/users/$path', data: {});
    }

    expect(s.api.requests.map((r) => r.headers['Authorization']),
        everyElement(isNull));
  });

  test('isRefreshTokenRejected', () {
    bool rejected(int status, Object? body) =>
        AuthInterceptor.isRefreshTokenRejected(status, body);

    expect(rejected(400, {'session_expired': true}), isTrue);
    expect(rejected(400, {'session_expired': false, 'error': 'invalid_grant',
      'error_description': 'Refresh failed: 400'}), isFalse);
    expect(rejected(400, {'error': 'invalid_grant',
      'error_description': 'Refresh failed: 400'}), isTrue);
    expect(rejected(400, {'error': 'invalid_grant',
      'error_description': 'Refresh failed: 500'}), isFalse);
    expect(rejected(400, {'error': 'invalid_grant'}), isFalse);
    expect(rejected(500, {'session_expired': true}), isFalse);
    expect(rejected(503, {'error': 'invalid_grant',
      'error_description': 'Refresh failed: 400'}), isFalse);
    expect(rejected(400, 'Bad Request'), isFalse);
    expect(rejected(400, null), isFalse);
  });
}
