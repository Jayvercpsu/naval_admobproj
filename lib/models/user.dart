class User {
  // These hold the user's basic info
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String gender;
  final String image;
  final int age;
  final String contactNo;
  final String loginType;

  // These are used for API sessions
  final String? accessToken;
  final String? refreshToken;

  // --- Firebase additions (Lab Activity 5) ---
  // Tracks which backend authenticated this session: 'dummyjson' or 'firebase'.
  final String authProvider;
  // Firebase Auth's UID, needed for re-authentication (update/delete/password).
  final String? firebaseUid;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.image,
    this.age = 0,
    this.contactNo = '',
    this.loginType = 'User',
    this.accessToken,
    this.refreshToken,
    this.authProvider = 'dummyjson',
    this.firebaseUid,
  });

  // Handy shortcut for displaying names
  String get fullName => '$firstName $lastName'.trim();

  // Handy shortcut for checking the provider
  bool get isFirebase => authProvider == 'firebase';

  // Turn API data into a User object
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : int.tryParse('${json['id'] ?? 0}') ?? 0,
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      age: json['age'] is num
          ? (json['age'] as num).toInt()
          : int.tryParse('${json['age'] ?? 0}') ?? 0,
      contactNo: json['contactNo']?.toString() ??
          json['phone']?.toString() ??
          '',
      loginType: json['loginType']?.toString() ?? 'User',
      accessToken: json['accessToken']?.toString() ??
          json['token']?.toString(),
      refreshToken: json['refreshToken']?.toString(),
      authProvider:
          json['authProvider']?.toString() ?? 'dummyjson',
      firebaseUid: json['firebaseUid']?.toString(),
    );
  }

  // Save the whole user as local JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'gender': gender,
      'image': image,
      'age': age,
      'contactNo': contactNo,
      'loginType': loginType,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'authProvider': authProvider,
      'firebaseUid': firebaseUid,
    };
  }

  // Make another copy with updated fields
  User copyWith({
    int? id,
    String? username,
    String? email,
    String? firstName,
    String? lastName,
    String? gender,
    String? image,
    int? age,
    String? contactNo,
    String? loginType,
    String? accessToken,
    String? refreshToken,
    String? authProvider,
    String? firebaseUid,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
      image: image ?? this.image,
      age: age ?? this.age,
      contactNo: contactNo ?? this.contactNo,
      loginType: loginType ?? this.loginType,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      authProvider: authProvider ?? this.authProvider,
      firebaseUid: firebaseUid ?? this.firebaseUid,
    );
  }
}
