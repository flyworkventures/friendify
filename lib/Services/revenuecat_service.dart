import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/utils/app_constants.dart';
import 'package:friendfy/Models/user_model.dart';
import 'package:friendfy/Models/premium_model.dart';
import 'package:friendfy/Services/premium_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// RevenueCat satın alma listener ve premium tanımlama servisi
class RevenueCatService {
  static bool _listenerAdded = false;

  /// RevenueCat purchase listener ekler (satın alma sonrası premium tanımlama için)
  static void addPurchaseListener(WidgetRef? ref) {
    if (_listenerAdded) {
      debugPrint("⚠️ RevenueCat listener zaten eklenmiş");
      return;
    }

    try {
      // CustomerInfo güncellemelerini dinle
      Purchases.addCustomerInfoUpdateListener((customerInfo) async {
        debugPrint("📦 RevenueCat customerInfo updated");
        await handlePurchaseUpdate(customerInfo, ref);
      });

      _listenerAdded = true;
      debugPrint("✅ RevenueCat purchase listener eklendi");
    } catch (e) {
      debugPrint("❌ RevenueCat listener eklenirken hata: $e");
    }
  }

  /// Satın alma sonrası customerInfo güncellemesini handle eder
  static Future<void> handlePurchaseUpdate(
    CustomerInfo customerInfo,
    WidgetRef? ref,
  ) async {
    try {
      debugPrint("💰 Purchase update işleniyor...");
      debugPrint("💰 CustomerInfo: ${customerInfo.toString()}");
      
      // Aktif entitelments (premium üyelikler)
      final entitlements = customerInfo.entitlements.all;
      debugPrint("📦 Entitlements count: ${entitlements.length}");
      
      if (entitlements.isEmpty) {
        debugPrint("⚠️ Hiç entitlement bulunamadı!");
        return;
      }
      
      for (final entitlement in entitlements.entries) {
        debugPrint("📦 Entitlement: ${entitlement.key}, Active: ${entitlement.value.isActive}");
        debugPrint("📦 Entitlement Product ID: ${entitlement.value.productIdentifier}");
        debugPrint("📦 Entitlement Will Renew: ${entitlement.value.willRenew}");
        debugPrint("📦 Entitlement Period Type: ${entitlement.value.periodType}");
      }

      // Kullanıcıyı al
      final user = ref?.read(AllControllers.userController);
      if (user == null) {
        debugPrint("⚠️ User null, premium tanımlama yapılamıyor");
        return;
      }
      
      debugPrint("👤 User ID: ${user.id}, Email: ${user.email}");

      // Aktif premium var mı kontrol et
      bool hasActivePremium = false;
      PremiumModel? newPremium;

      for (final entitlement in entitlements.values) {
        debugPrint("🔍 Kontrol ediliyor: ${entitlement.identifier}, Active: ${entitlement.isActive}");
        
        if (entitlement.isActive) {
          hasActivePremium = true;
          debugPrint("✅ Aktif entitlement bulundu: ${entitlement.identifier}");
          
          // Product ID ve tarihleri al
          final productId = entitlement.productIdentifier;
          // RevenueCat tarihleri String? olarak döner, parse etmemiz gerekiyor
          final purchaseDateString = entitlement.latestPurchaseDate;
          final expirationDateString = entitlement.expirationDate;

          debugPrint("📦 Product ID: $productId");
          debugPrint("📦 Purchase Date: $purchaseDateString");
          debugPrint("📦 Expiration Date: $expirationDateString");

          // Product ID kontrolü
          if (productId.isEmpty) {
            debugPrint("⚠️ Product ID boş, premium tanımlanamıyor");
            continue;
          }

          // Tarihleri String'den DateTime'a çevir (RevenueCat String? döndürüyor)
          DateTime purchaseDateTime = DateTime.now();
          if (purchaseDateString != null) {
            try {
              purchaseDateTime = DateTime.parse(purchaseDateString);
              debugPrint("✅ Purchase date parsed: $purchaseDateTime");
            } catch (e) {
              debugPrint("⚠️ Purchase date parse hatası: $e, şu anki zaman kullanılıyor");
              purchaseDateTime = DateTime.now();
            }
          }
          
          DateTime? expirationDateTime;
          if (expirationDateString != null) {
            try {
              expirationDateTime = DateTime.parse(expirationDateString);
              debugPrint("✅ Expiration date parsed: $expirationDateTime");
            } catch (e) {
              debugPrint("⚠️ Expiration date parse hatası: $e, null olarak ayarlanıyor");
              expirationDateTime = null;
            }
          }

          // Premium model oluştur
          newPremium = PremiumService.createPaidPremium(
            startDate: purchaseDateTime,
            endDate: expirationDateTime,
            productId: productId,
            purchasedAt: purchaseDateTime,
          );
          
          debugPrint("✅ Premium model oluşturuldu: ${newPremium.productId}, Type: ${newPremium.type}, Active: ${newPremium.isActive}");

          break; // İlk aktif premium'u al
        }
      }

      if (hasActivePremium && newPremium != null) {
        debugPrint("✅ Premium tanımlanıyor...");
        
        // Premium'u backend'e gönder
        await updatePremiumOnBackend(user, newPremium, ref);
        
        // Local state'i güncelle
        await refreshUserFromBackend(ref);
                 await ref?.read(AllControllers.chatViewController.notifier).getConversations();
         await ref?.read(AllControllers.agentsViewController.notifier).getAgents();
         await ref?.read(AllControllers.agentsViewController.notifier).getRecentAgents();
      } else {
        debugPrint("ℹ️ Aktif premium bulunamadı");
        debugPrint("ℹ️ hasActivePremium: $hasActivePremium, newPremium: ${newPremium != null}");
        if (!hasActivePremium) {
          debugPrint("⚠️ Hiç aktif entitlement bulunamadı!");
        }
        if (newPremium == null) {
          debugPrint("⚠️ Premium model oluşturulamadı!");
        }
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Purchase update handle edilirken hata: $e");
      debugPrint("❌ Stack trace: $stackTrace");
    }
  }

  /// Backend'e premium bilgisini gönderir
  static Future<void> updatePremiumOnBackend(
    UserModel user,
    PremiumModel newPremium,
    WidgetRef? ref,
  ) async {
    try {
      debugPrint("🌐 Backend'e premium bilgisi gönderiliyor...");
      debugPrint("📦 Yeni premium: ${newPremium.productId}, Start: ${newPremium.startDate}, End: ${newPremium.endDate}");
      
      // Yeni premium'u ekle
      final updatedMemberships = PremiumService.addPremiumToMemberships(
        user,
        newPremium,
      );
      
      debugPrint("📦 Updated memberships count: ${updatedMemberships.length}");

      // JSON'a çevir
      final membershipsJson = PremiumService.membershipsToJson(updatedMemberships);
      debugPrint("📦 Memberships JSON: $membershipsJson");

      // User ID kontrolü
      if (user.id == null) {
        debugPrint("❌ User ID null, premium güncellenemiyor");
        return;
      }

      // Backend'e gönder - direkt http.post kullan (WidgetRef sorunu için)
      final userToken = user.token ?? "";
      final headers = {
        'x-auth-token': userToken,
        'Content-Type': 'application/json'
      };
      
      final response = await http.post(
        Uri.parse("${AppConstants.baseURL}${AppConstants.updatePremiumURL}"),
        headers: headers,
        body: jsonEncode({
          "userId": user.id!,
          "memberships": membershipsJson,
        }),
      );

      debugPrint("📡 Backend response status: ${response.statusCode}");
      debugPrint("📡 Backend response body: ${response.body}");
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        debugPrint("✅ Premium backend'de güncellendi: ${json['msg']}");
        debugPrint("✅ Success: ${json['success']}");
        
        // Backend'den güncellenmiş user bilgisini al ve güncelle
        if (json['user'] != null) {
          try {
            final updatedUser = UserModel.fromMap(json['user']);
            ref?.read(AllControllers.userController.notifier).updateUserModel(updatedUser);
            debugPrint("✅ User model güncellendi (backend response'dan)");
          } catch (e) {
            debugPrint("⚠️ User model güncellenirken hata: $e");
          }
        }
      } else {
        debugPrint("❌ Premium backend'de güncellenemedi: ${response.statusCode}");
        debugPrint("Response: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Backend'e premium gönderilirken hata: $e");
    }
  }

  /// Backend'den güncel kullanıcı bilgisini çeker (premium bilgisi dahil)
  static Future<void> refreshUserFromBackend(WidgetRef? ref) async {
    try {
      debugPrint("🔄 Kullanıcı bilgisi backend'den çekiliyor...");
      
      final user = ref?.read(AllControllers.userController);
      if (user?.token == null || user?.token?.isEmpty == true) {
        debugPrint("⚠️ Token yok, kullanıcı bilgisi çekilemiyor");
        return;
      }

      final userToken = user!.token!;
      // Direkt http.post kullan (WidgetRef sorunu için)
      final headers = {
        'x-auth-token': userToken,
        'Content-Type': 'application/json'
      };
      
      final response = await http.post(
        Uri.parse("${AppConstants.baseURL}${AppConstants.verifyTokenURL}"),
        headers: headers,
        body: jsonEncode({"token": userToken}),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json["msg"] == "Valid Token") {
          final updatedUser = UserModel.fromMap(json["user"]);
          ref?.read(AllControllers.userController.notifier).updateUserModel(updatedUser);
          debugPrint("✅ Kullanıcı bilgisi güncellendi");
        }
      }
    } catch (e) {
      debugPrint("❌ Kullanıcı bilgisi çekilirken hata: $e");
    }
  }

  /// Manuel olarak customerInfo'yu kontrol eder ve premium tanımlar
  static Future<void> syncCustomerInfo(WidgetRef? ref) async {
    try {
      debugPrint("🔄 CustomerInfo senkronize ediliyor...");
      final customerInfo = await Purchases.getCustomerInfo();
      await handlePurchaseUpdate(customerInfo, ref);
    } catch (e) {
      debugPrint("❌ CustomerInfo senkronize edilirken hata: $e");
    }
  }
}
