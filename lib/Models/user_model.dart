import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? address;
  final String? role;
  final String? profileImage;
  final double? currentBalance;
  final int? age; // Added age field
  final Timestamp? dob; // Added dob field
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  UserModel({
    required this.uid,
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.address,
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
    return UserModel(
      uid: uid,
      firstName: map['firstName'],
      lastName: map['lastName'],
      email: map['email'],
      phone: map['phone'],
      address: map['address'],
      role: map['role'],
      profileImage: map['profileImage'],
      currentBalance: map['currentBalance'] != null
          ? (map['currentBalance'] as num).toDouble()
          : null,
      age: map['dob'] != null
          ? _calculateAgeFromDob(map['dob'])
          : (map['age'] != null ? (map['age'] as num).toInt() : null),
      dob: map['dob'],
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (firstName != null) map['firstName'] = firstName;
    if (lastName != null) map['lastName'] = lastName;
    if (email != null) map['email'] = email;
    if (phone != null) map['phone'] = phone;
    if (address != null) map['address'] = address;
    if (role != null) map['role'] = role;
    if (profileImage != null) map['profileImage'] = profileImage;
    if (currentBalance != null) map['currentBalance'] = currentBalance;
    if (age != null) map['age'] = age;
    if (dob != null) map['dob'] = dob;
    if (createdAt != null) map['createdAt'] = createdAt;
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

  static int _calculateAgeFromDob(Timestamp dob) {
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
