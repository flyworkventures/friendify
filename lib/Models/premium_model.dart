// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class PremiumModel {
  final DateTime startDate;
  final DateTime? endDate;
  final String productId;
  final PremiumType type;
  final bool isActive;
  final DateTime? purchasedAt;
  
  PremiumModel({
    required this.startDate,
    this.endDate,
    required this.productId,
    required this.type,
    required this.isActive,
    this.purchasedAt,
  });

  PremiumModel copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? productId,
    PremiumType? type,
    bool? isActive,
    DateTime? purchasedAt,
  }) {
    return PremiumModel(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      productId: productId ?? this.productId,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      purchasedAt: purchasedAt ?? this.purchasedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'productId': productId,
      'type': type.toString().split('.').last, // PremiumType.paid -> "paid"
      'isActive': isActive,
      'purchasedAt': purchasedAt?.toIso8601String(),
    };
  }

  factory PremiumModel.fromMap(Map<String, dynamic> map) {
    return PremiumModel(
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: map['endDate'] != null 
          ? DateTime.parse(map['endDate'] as String) 
          : null,
      productId: map['productId'] as String,
      type: PremiumType.fromString(map['type'] as String? ?? 'paid'),
      isActive: map['isActive'] as bool? ?? false,
      purchasedAt: map['purchasedAt'] != null
          ? DateTime.parse(map['purchasedAt'] as String)
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory PremiumModel.fromJson(String source) => 
      PremiumModel.fromMap(json.decode(source) as Map<String, dynamic>);
}

enum PremiumType {
  paid,        // Satın alınmış premium
  trial,       // Deneme sürümü
  freeTrial;   // Üyelikten sonra 7 günlük bedava premium

  static PremiumType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'paid':
        return PremiumType.paid;
      case 'trial':
        return PremiumType.trial;
      case 'freetrial':
      case 'free_trial':
        return PremiumType.freeTrial;
      default:
        return PremiumType.paid;
    }
  }
}

