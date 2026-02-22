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
        email: json['username']
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': email
      };
}
