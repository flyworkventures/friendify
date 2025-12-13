// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:flutter/foundation.dart';

class UserModel {
  final int? id;
  final String username;
  final String email;
  final String? password;
  final String? token;
  final DateTime accountCreatedDate;
  final DateTime birthdate;
  final dynamic memberships;
  final List? ownAgents; // sahip olunan agent idleri 
  final int verificated; // kodları olacak true - email-verification-waiting gibi gibi
  final dynamic credential;
  final String? refreshToken;
  final String? phoneNumber;
  final dynamic lastLogins;
  final String? counrty;
  final String? gender;
  final dynamic hobbies;
  final String? photoURL;
  UserModel({
    
     this.id,
    required this.username,
    required this.email,
    this.password,
    this.token,
    required this.accountCreatedDate,
    required this.birthdate,
    required this.memberships,
     this.ownAgents,
    required this.verificated,
    required this.credential,
    this.refreshToken,
    this.phoneNumber,
    required this.lastLogins,
    this.counrty,
    this.gender = "male",
    this.hobbies,
    this.photoURL
  });

  UserModel copyWith({
    int? id,
    String? username,
    String? email,
    String? password,
    String? token,
    DateTime? accountCreatedDate,
    DateTime? birthdate,
    dynamic? memberships,
    List? ownAgents,
    int? verificated,
    dynamic? credential,
    String? refreshToken,
    String? phoneNumber,
    dynamic? lastLogins,
    String? counrty,
    String? gender,
    dynamic? hobbies,
    String? photoURL
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      token: token ?? this.token,
      accountCreatedDate: accountCreatedDate ?? this.accountCreatedDate,
      birthdate: birthdate ?? this.birthdate,
      memberships: memberships ?? this.memberships,
      ownAgents: ownAgents ?? this.ownAgents,
      verificated: verificated ?? this.verificated,
      credential: credential ?? this.credential,
      refreshToken: refreshToken ?? this.refreshToken,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      lastLogins: lastLogins ?? this.lastLogins,
      counrty: counrty ?? this.counrty,
      gender: gender ?? this.gender,
      hobbies: hobbies ?? this.hobbies,
      photoURL: photoURL ?? this.photoURL,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'username': username,
      'email': email,
      'password': password,
      'token': token,
      'accountCreatedDate': accountCreatedDate.toIso8601String(),
      'birthdate': birthdate.toIso8601String(),
      'memberships': memberships,
      'ownAgents': ownAgents,
      'verificated': verificated,
      'credential': credential,
      'refreshToken': refreshToken,
      'phoneNumber': phoneNumber,
      'lastLogins': lastLogins,
      'counrty': counrty,
      'gender': gender,
      'hobbies': hobbies,
      'photoURL': photoURL,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int,
      username: map['username'] as String,
      email: map['email'] as String,
      password: map['password'] != null ? map['password'] as String : null,
      token: map['token'] != null ? map['token'] as String : null,
      accountCreatedDate: DateTime.parse(map['accountCreatedDate']),
      birthdate: DateTime.parse(map['birthdate']) ,
      memberships: map['memberships'] as dynamic,
      ownAgents: map['ownAgents'],
      verificated: map['verificated'] as int,
      credential: map['credential'] as dynamic,
      refreshToken: map['refreshToken'] != null ? map['refreshToken'] as String : null,
      phoneNumber: map['phoneNumber'] != null ? map['phoneNumber'] as String : null,
      lastLogins: map['lastLogins'] as dynamic,
      counrty: map['counrty'] != null ? map['counrty'] as String : null,
      gender: map['gender'] != null ? map['gender'] as String : null,
      hobbies: map['hobbies'],
      photoURL: map['photoURL'] != null ? map['photoURL'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory UserModel.fromJson(String source) => UserModel.fromMap(json.decode(source) as Map<String, dynamic>);

}
