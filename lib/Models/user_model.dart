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
    return {
      'firstName': firstName ?? '',
      'lastName': lastName ?? '',
      'email': email ?? '',
      'phone': phone ?? '',
      'address': address ?? '',
      'role': role ?? '',
      'profileImage': profileImage ?? '',
      'currentBalance': currentBalance ?? 0.0,
      'age': age,
      'dob': dob,
      'createdAt': createdAt,
      'updatedAt': FieldValue.serverTimestamp(),
    };
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
