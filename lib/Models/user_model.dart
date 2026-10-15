import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? address;
  final String? gender;
  final String? role;
  final String? profileImage;
  final double? currentBalance;
  final int? age; // Added age field
  final Timestamp? dob; // Added dob field
  final DateTime? createdAt;
  final Timestamp? updatedAt;

  UserModel({
    required this.uid,
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.address,
    this.gender,
    this.role,
    this.profileImage,
    this.currentBalance,
    this.age,
    this.dob,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic>? map) {
    if (map == null) return UserModel(uid: uid);
    final dobTs = _asTimestamp(map['dob']);
    return UserModel(
      uid: uid,
      firstName: _str(map['firstName']),
      lastName: _str(map['lastName']),
      email: _str(map['email']),
      phone: _str(map['phone']),
      address: _str(map['address']),
      gender: _str(map['gender']),
      role: _str(map['role']),
      profileImage: _str(
        map['photoURL'] ?? map['photoUrl'] ?? map['profileImage'],
      ),
      currentBalance: map['currentBalance'] is num
          ? (map['currentBalance'] as num).toDouble()
          : null,
      age: dobTs != null
          ? _ageFromTimestamp(dobTs)
          : (map['age'] is num ? (map['age'] as num).toInt() : null),
      dob: dobTs,
      createdAt: _asTimestamp(map['createdAt'])?.toDate(),
      updatedAt: _asTimestamp(map['updatedAt']),
    );
  }

  /// Reads a String field, coercing a non-null non-String (a legacy/foreign
  /// launch wrote, e.g. a numeric phone) instead of throwing on an implicit
  /// dynamic→String cast.
  static String? _str(dynamic value) =>
      value == null ? null : (value is String ? value : value.toString());

  /// Accepts a Firestore [Timestamp], a [DateTime], or an ISO string and
  /// returns a [Timestamp], else null.
  static Timestamp? _asTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return Timestamp.fromDate(parsed);
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'uid': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (firstName != null) map['firstName'] = firstName;
    if (lastName != null) map['lastName'] = lastName;
    if (email != null) map['email'] = email;
    if (phone != null) map['phone'] = phone;
    if (address != null) map['address'] = address;
    if (gender != null) map['gender'] = gender;
    if (role != null) map['role'] = role;
    if (profileImage != null) map['photoURL'] = profileImage;
    if (currentBalance != null) map['currentBalance'] = currentBalance;
    if (age != null) map['age'] = age;
    if (dob != null) map['dob'] = dob;
    if (createdAt != null) map['createdAt'] = Timestamp.fromDate(createdAt!);
    return map;
  }

  int? get calculatedAge {
    if (dob == null) return age;
    final now = DateTime.now();
    final dateOfBirth = dob!.toDate();
    int calcAge = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      calcAge--;
    }
    return calcAge;
  }

  static int _ageFromTimestamp(Timestamp dob) {
    final now = DateTime.now();
    final dateOfBirth = dob.toDate();
    int calcAge = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      calcAge--;
    }
    return calcAge;
  }
}
