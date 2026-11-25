import 'dart:convert';

class User {
  final String id;
  final String email;

  User(
      {required this.id,
      required this.email});

  User copyWith(
      {String? id, String? email, String? firstName, String? lastName}) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email
    );
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        email: json['username'] ?? ''
      );

  /// Liest den Nutzer direkt aus dem Access Token (JWT). /users/me liefert
  /// genau diese beiden Angaben aus demselben Token - so steht fest, wer
  /// angemeldet ist, auch wenn der Server gerade nicht erreichbar ist.
  ///
  /// Der Token wird hier nur gelesen, nicht geprueft; das macht weiterhin der
  /// Server bei jedem Request.
  static User? fromAccessToken(String? token) {
    if (token == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map) return null;
      final id = payload['sub'];
      if (id is! String || id.isEmpty) return null;
      final email = payload['email'] ?? payload['preferred_username'];
      return User(id: id, email: email is String ? email : '');
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': email
      };
}
