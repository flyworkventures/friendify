import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:friendfy/Services/premium_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Aynı fiziksel cihazda yalnızca bir kez uygulama içi 3 günlük deneme (çoklu hesap sınırlaması).
/// [PremiumService] ile senkron tutulur; kalıcı doğrulama için backend şarttır (kayıt/silme sonrası yeniden kurulum).
class DeviceTrialEligibilityService {
  static const _kClaimedFp = 'friendify_free_trial_claimed_device_fp_v1';

  /// iOS: `identifierForVendor`. Android: Settings.Secure Android ID.
  static Future<String?> deviceTrialFingerprint() async {
    if (kIsWeb) return null;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = await DeviceInfoPlugin().iosInfo;
        return ios.identifierForVendor;
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        return const AndroidId().getId();
      }
    } catch (_) {}
    return null;
  }

  /// Uygulama açılışında veya kayıt öncesi: yerelde işaretli cihaz ise [PremiumService] kilidini günceller.
  static Future<void> applyStoredTrialLockToPremiumService() async {
    final fp = await deviceTrialFingerprint();
    if (fp == null || fp.isEmpty) {
      PremiumService.setFreeTrialConsumedOnThisDevice(false);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final claimed = prefs.getString(_kClaimedFp);
    PremiumService.setFreeTrialConsumedOnThisDevice(claimed == fp);
  }

  static Future<void> markTrialClaimedForThisDevice() async {
    final fp = await deviceTrialFingerprint();
    if (fp == null || fp.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kClaimedFp, fp);
    PremiumService.setFreeTrialConsumedOnThisDevice(true);
  }
}
