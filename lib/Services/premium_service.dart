import 'dart:convert';
import 'package:friendfy/Models/premium_model.dart';
import 'package:friendfy/Models/user_model.dart';

class PremiumService {
  // ⏱️ Bedava premium süresi (gün cinsinden)
  static const int freeTrialDays = 7;
  
  // 📨 Premium olmayan kullanıcılar için günlük mesaj limiti
  static const int dailyMessageLimit = 20;
  
  // 📸 Premium olmayan kullanıcılar için günlük fotoğraf gönderme limiti
  static const int dailyPhotoLimit = 2;
  
  // 👤 Premium olmayan kullanıcılar için karakter düzenleme limiti
  static const int characterEditLimit = 2;

  /// Premium bilgilerini parse eder (memberships array'inden)
  static List<PremiumModel> parseMemberships(dynamic memberships) {
    if (memberships == null) return [];
    
    try {
      // Eğer string ise JSON parse et
      if (memberships is String) {
        final decoded = json.decode(memberships);
        if (decoded is List) {
          return decoded
              .map((item) => PremiumModel.fromMap(item as Map<String, dynamic>))
              .toList();
        }
      }
      
      // Eğer zaten List ise direkt map et
      if (memberships is List) {
        return memberships
            .map((item) {
              if (item is Map<String, dynamic>) {
                return PremiumModel.fromMap(item);
              }
              if (item is String) {
                return PremiumModel.fromMap(json.decode(item) as Map<String, dynamic>);
              }
              return null;
            })
            .whereType<PremiumModel>()
            .toList();
      }
      
      // Eğer Map ise tek bir premium olabilir
      if (memberships is Map) {
        return [PremiumModel.fromMap(memberships as Map<String, dynamic>)];
      }
    } catch (e) {
      print("⚠️ Premium parse hatası: $e");
    }
    
    return [];
  }

  /// Kullanıcının aktif premium'u var mı kontrol eder
  static PremiumModel? getActivePremium(UserModel? user) {
    if (user == null) return null;
    
    final memberships = parseMemberships(user.memberships);
    final now = DateTime.now();
    
    // Son premium'u bul (en son bitiş tarihine sahip olan)
    PremiumModel? activePremium;
    
    for (var membership in memberships) {
      if (!membership.isActive) continue;
      
      // Bitiş tarihi kontrolü
      if (membership.endDate != null) {
        if (now.isAfter(membership.endDate!)) {
          continue; // Süresi dolmuş
        }
      }
      
      // Başlangıç tarihi kontrolü
      if (now.isBefore(membership.startDate)) {
        continue; // Henüz başlamamış
      }
      
      // Aktif premium bulundu
      if (activePremium == null || 
          (membership.endDate != null && 
           (activePremium.endDate == null || 
            membership.endDate!.isAfter(activePremium.endDate!)))) {
        activePremium = membership;
      }
    }
    
    return activePremium;
  }

  /// Kullanıcı premium mu kontrol eder
  static bool isPremiumActive(UserModel? user) {
    return getActivePremium(user) != null;
  }

  /// Bedava premium kullanılabilir mi kontrol eder
  /// - Üye olduğu tarihten itibaren 7 gün içindeyse
  /// - Daha önce bedava premium kullanmamışsa
  static bool canUseFreeTrial(UserModel? user) {
    if (user == null) return false;
    
    // Zaten aktif premium'u varsa bedava premium kullanamaz
    if (isPremiumActive(user)) return false;
    
    final now = DateTime.now();
    final accountCreatedDate = user.accountCreatedDate;
    
    // 7 günlük süre kontrolü
    final daysSinceAccountCreated = now.difference(accountCreatedDate).inDays;
    if (daysSinceAccountCreated > freeTrialDays) {
      return false; // 7 gün geçmiş
    }
    
    // Daha önce bedava premium kullanmış mı kontrol et
    final memberships = parseMemberships(user.memberships);
    final hasUsedFreeTrial = memberships.any(
      (m) => m.type == PremiumType.freeTrial,
    );
    
    return !hasUsedFreeTrial;
  }

  /// Kullanıcının günlük mesaj limitini döndürür
  /// Premium ise null (sınırsız), değilse 20
  static int? getDailyMessageLimit(UserModel? user) {
    if (isPremiumActive(user)) {
      return null; // Sınırsız
    }
    
    // Bedava premium kullanılabilir mi?
    if (canUseFreeTrial(user)) {
      return null; // Bedava premium süresince sınırsız
    }
    
    return dailyMessageLimit; // Premium değilse 20 mesaj
  }

  /// Botları düzenleyebilir mi kontrol eder
  /// Premium üyeler botları düzenleyebilir
  static bool canEditAgents(UserModel? user) {
    if (isPremiumActive(user)) {
      return true; // Premium üye her şeyi düzenleyebilir
    }
    
    // Bedava premium süresince düzenleyebilir
    if (canUseFreeTrial(user)) {
      return true;
    }
    
    return false; // Premium olmayan üye düzenleyemez
  }

  /// Günlük fotoğraf gönderme limitini döndürür
  /// Premium ise null (sınırsız), değilse 2
  static int? getDailyPhotoLimit(UserModel? user) {
    if (isPremiumActive(user)) {
      return null; // Sınırsız
    }
    
    // Bedava premium kullanılabilir mi?
    if (canUseFreeTrial(user)) {
      return null; // Bedava premium süresince sınırsız
    }
    
    return dailyPhotoLimit; // Premium değilse 2 fotoğraf
  }

  /// Fotoğraf gönderebilir mi kontrol eder
  static bool canSendPhoto(UserModel? user, int todayPhotoCount) {
    final limit = getDailyPhotoLimit(user);
    
    if (limit == null) {
      return true; // Sınırsız
    }
    
    return todayPhotoCount < limit;
  }

  /// Karakter düzenleme limitini döndürür
  /// Premium ise null (sınırsız), değilse 2
  static int? getCharacterEditLimit(UserModel? user) {
    if (isPremiumActive(user)) {
      return null; // Sınırsız
    }
    
    // Bedava premium kullanılabilir mi?
    if (canUseFreeTrial(user)) {
      return null; // Bedava premium süresince sınırsız
    }
    
    return characterEditLimit; // Premium değilse 2 karakter
  }

  /// Karakter düzenleyebilir mi kontrol eder (limit kontrolü ile)
  static bool canEditCharacter(UserModel? user, int currentEditedCount) {
    final limit = getCharacterEditLimit(user);
    
    if (limit == null) {
      return true; // Sınırsız
    }
    
    return currentEditedCount < limit;
  }

  /// Günlük mesaj sayısını kontrol eder (limit aşılmış mı?)
  /// Mesaj sayısını backend'den veya local storage'dan almalı
  static bool hasReachedDailyLimit(UserModel? user, int todayMessageCount) {
    final limit = getDailyMessageLimit(user);
    
    if (limit == null) {
      return false; // Sınırsız
    }
    
    return todayMessageCount >= limit;
  }

  /// Bedava premium oluşturur (7 günlük)
  static PremiumModel createFreeTrial(UserModel user) {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: freeTrialDays));
    
    return PremiumModel(
      startDate: now,
      endDate: endDate,
      productId: 'free_trial_${user.id}',
      type: PremiumType.freeTrial,
      isActive: true,
      purchasedAt: null,
    );
  }

  /// Premium üyelik oluşturur (satın alınmış)
  static PremiumModel createPaidPremium({
    required DateTime startDate,
    DateTime? endDate,
    required String productId,
    DateTime? purchasedAt,
  }) {
    return PremiumModel(
      startDate: startDate,
      endDate: endDate,
      productId: productId,
      type: PremiumType.paid,
      isActive: true,
      purchasedAt: purchasedAt ?? DateTime.now(),
    );
  }

  /// Yeni premium'u memberships array'ine ekler
  static List<PremiumModel> addPremiumToMemberships(
    UserModel user,
    PremiumModel newPremium,
  ) {
    final existingMemberships = parseMemberships(user.memberships);
    
    // Eski aktif premium'ları pasif yap
    final updatedMemberships = existingMemberships.map((m) {
      if (m.isActive && newPremium.type == PremiumType.paid) {
        return m.copyWith(isActive: false);
      }
      return m;
    }).toList();
    
    // Yeni premium'u ekle
    updatedMemberships.add(newPremium);
    
    return updatedMemberships;
  }

  /// Memberships array'ini JSON string'e çevirir (backend'e göndermek için)
  static String membershipsToJson(List<PremiumModel> memberships) {
    return json.encode(memberships.map((m) => m.toMap()).toList());
  }
}

