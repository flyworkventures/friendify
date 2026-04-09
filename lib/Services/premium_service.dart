import 'dart:convert';
import 'package:friendfy/Models/premium_model.dart';
import 'package:friendfy/Models/user_model.dart';

class PremiumService {
  // ⏱️ Bedava premium süresi (gün cinsinden)
  static const int freeTrialDays = 2;
  
  // 👤 Misafir kullanıcı limitleri
  static const int guestDailyMessageLimit = 10;
  static const int guestDailyPhotoLimit = 2;
  static const int guestDailyAudioLimit = 2;
  
  // 🎁 Free trial limitleri
  static const int freeTrialDailyMessageLimit = 20;
  static const int freeTrialDailyPhotoLimit = 5;
  static const int freeTrialDailyAudioLimit = 10;
  
  // 📨 Premium olmayan kullanıcılar için günlük mesaj limiti (eski kod uyumluluğu için)
  static const int dailyMessageLimit = 20;
  
  // 📸 Premium olmayan kullanıcılar için günlük fotoğraf gönderme limiti (eski kod uyumluluğu için)
  static const int dailyPhotoLimit = 2;
  
  // 🎤 Premium olmayan kullanıcılar için günlük sesli mesaj gönderme limiti (standart paket)
  static const int dailyAudioLimit = 2;
  
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

  /// Kullanıcı premium mu kontrol eder (sadece paid premium, free trial değil)
  static bool isPremiumActive(UserModel? user) {
    final activePremium = getActivePremium(user);
    // Sadece paid premium'u premium olarak say (free trial değil)
    return activePremium != null && activePremium.type == PremiumType.paid;
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
  /// Premium ise null (sınırsız)
  /// Free trial ise 20 mesaj
  /// Misafir ise 10 mesaj
  /// Normal kullanıcı ise 20 mesaj
  static int? getDailyMessageLimit(UserModel? user) {
    if (user == null) return null;
    
    // Premium kullanıcı sınırsız
    if (isPremiumActive(user)) {
      return null;
    }
    
    // Misafir kullanıcı
    if (user.credential == "guest") {
      return guestDailyMessageLimit; // 10 mesaj
    }
    
    // Aktif free trial kontrolü (öncelikli)
    final activePremium = getActivePremium(user);
    if (activePremium != null && activePremium.type == PremiumType.freeTrial) {
      return freeTrialDailyMessageLimit; // 20 mesaj
    }
    
    // Free trial kullanılabilir mi kontrolü (henüz aktif olmayan ama kullanılabilir)
    if (canUseFreeTrial(user)) {
      return freeTrialDailyMessageLimit; // 20 mesaj
    }
    
    // Normal kullanıcı
    return dailyMessageLimit; // 20 mesaj
  }

  /// Botları düzenleyebilir mi kontrol eder
  /// Premium üyeler botları düzenleyebilir
  /// Free trial kullanıcılar düzenleyemez (paywall tetiklenmeli)
  static bool canEditAgents(UserModel? user) {
    if (user == null) return false;
    
    // Premium kullanıcı düzenleyebilir
    if (isPremiumActive(user)) {
      return true;
    }
    
    // Free trial kullanıcı düzenleyemez (paywall tetiklenmeli)
    if (canUseFreeTrial(user)) {
      return false;
    }
    
    // Misafir ve normal kullanıcı düzenleyemez
    return false;
  }

  /// Günlük fotoğraf gönderme limitini döndürür
  /// Premium ise null (sınırsız)
  /// Free trial ise 5 fotoğraf
  /// Misafir ise 2 fotoğraf
  /// Normal kullanıcı ise 2 fotoğraf
  static int? getDailyPhotoLimit(UserModel? user) {
    if (user == null) return null;
    
    // Premium kullanıcı sınırsız
    if (isPremiumActive(user)) {
      return null;
    }
    
    // Misafir kullanıcı
    if (user.credential == "guest") {
      return guestDailyPhotoLimit; // 2 fotoğraf
    }
    
    // Aktif free trial kontrolü (öncelikli)
    final activePremium = getActivePremium(user);
    if (activePremium != null && activePremium.type == PremiumType.freeTrial) {
      return freeTrialDailyPhotoLimit; // 5 fotoğraf
    }
    
    // Free trial kullanılabilir mi kontrolü (henüz aktif olmayan ama kullanılabilir)
    if (canUseFreeTrial(user)) {
      return freeTrialDailyPhotoLimit; // 5 fotoğraf
    }
    
    // Normal kullanıcı
    return dailyPhotoLimit; // 2 fotoğraf
  }
  
  /// Günlük sesli mesaj gönderme limitini döndürür
  /// Premium ise null (sınırsız)
  /// Free trial ise 10 sesli mesaj
  /// Misafir ise 2 sesli mesaj
  /// Normal kullanıcı ise 2 sesli mesaj
  static int? getDailyAudioLimit(UserModel? user) {
    if (user == null) return null;
    
    // Premium kullanıcı sınırsız
    if (isPremiumActive(user)) {
      return null;
    }
    
    // Misafir kullanıcı
    if (user.credential == "guest") {
      return guestDailyAudioLimit; // 2 sesli mesaj
    }
    
    // Aktif free trial kontrolü (öncelikli)
    final activePremium = getActivePremium(user);
    if (activePremium != null && activePremium.type == PremiumType.freeTrial) {
      return freeTrialDailyAudioLimit; // 10 sesli mesaj
    }
    
    // Free trial kullanılabilir mi kontrolü (henüz aktif olmayan ama kullanılabilir)
    if (canUseFreeTrial(user)) {
      return freeTrialDailyAudioLimit; // 10 sesli mesaj
    }
    
    // Normal kullanıcı (free trial olmayan, standart paket)
    return dailyAudioLimit; // 2 sesli mesaj
  }
  
  /// Sesli mesaj gönderebilir mi kontrol eder
  static bool canSendAudio(UserModel? user, int todayAudioCount) {
    final limit = getDailyAudioLimit(user);
    
    if (limit == null) {
      return true; // Sınırsız
    }
    
    return todayAudioCount < limit;
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
  /// Premium ise null (sınırsız)
  /// Free trial ve diğerleri için 0 (düzenleyemez, paywall tetiklenmeli)
  static int? getCharacterEditLimit(UserModel? user) {
    if (user == null) return 0;
    
    // Premium kullanıcı sınırsız
    if (isPremiumActive(user)) {
      return null;
    }
    
    // Free trial ve diğerleri düzenleyemez
    return 0;
  }

  /// Karakter düzenleyebilir mi kontrol eder
  /// Premium ise true, diğerleri false (paywall tetiklenmeli)
  static bool canEditCharacter(UserModel? user, int currentEditedCount) {
    if (user == null) return false;
    
    // Premium kullanıcı sınırsız
    if (isPremiumActive(user)) {
      return true;
    }
    
    // Free trial ve diğerleri düzenleyemez
    return false;
  }
  
  /// Karakter oluşturabilir mi kontrol eder
  /// Premium ise true, diğerleri false (paywall tetiklenmeli)
  static bool canCreateCharacter(UserModel? user) {
    if (user == null) return false;
    
    // Premium kullanıcı oluşturabilir
    if (isPremiumActive(user)) {
      return true;
    }
    
    // Free trial ve diğerleri oluşturamaz
    return false;
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

