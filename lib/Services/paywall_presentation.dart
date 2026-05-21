import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:friendfy/View/PremiumScreen/premium_screen.dart';
import 'package:friendfy/Widgets/future_progress_dialog.dart';
import 'package:friendfy/main.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// Premium paywall açılışlarında [showFutureProgressDialog] gösterir.
class PaywallPresentation {
  PaywallPresentation._();

  static Future<PaywallResult?> present(
    BuildContext context, {
    bool displayCloseButton = false,
    Offering? offering,
  }) async {
    if (!context.mounted) return null;
    try {
      return await context.runWithProgressDialog(() {
        if (offering != null) {
          return RevenueCatUI.presentPaywall(
            displayCloseButton: displayCloseButton,
            offering: offering,
          );
        }
        return RevenueCatUI.presentPaywall(
          displayCloseButton: displayCloseButton,
        );
      });
    } catch (e) {
      debugPrint("⚠️ Paywall present error: $e");
      return null;
    }
  }

  static Future<PaywallResult?> presentFromNavigator({
    bool displayCloseButton = false,
    Offering? offering,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return null;
    return present(
      context,
      displayCloseButton: displayCloseButton,
      offering: offering,
    );
  }

  /// Android: [PremiumScreen], iOS: RevenueCat modal paywall.
  static Future<void> presentPlatformPaywall(
    BuildContext context, {
    bool displayCloseButton = true,
  }) async {
    if (!context.mounted) return;
    if (Platform.isAndroid) {
      await openPremiumScreen(context);
      return;
    }
    await present(context, displayCloseButton: displayCloseButton);
  }

  static Future<void> openPremiumScreen(BuildContext context) async {
    if (!context.mounted) return;
    await context.runWithProgressDialog(() async {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const PremiumScreen()),
      );
    });
  }

  static Future<PaywallResult?> presentSpecialOffer(
    BuildContext context, {
    String offeringId = "special_offer",
    bool displayCloseButton = true,
  }) async {
    if (!context.mounted) return null;
    try {
      return await context.runWithProgressDialog(() async {
        final offerings = await Purchases.getOfferings();
        final specialOffer =
            offerings.getOffering(offeringId) ??
            offerings.getOffering("Special Offer");
        if (specialOffer != null) {
          return RevenueCatUI.presentPaywall(
            offering: specialOffer,
            displayCloseButton: displayCloseButton,
          );
        }
        return RevenueCatUI.presentPaywall(
          displayCloseButton: displayCloseButton,
        );
      });
    } catch (e) {
      debugPrint("⚠️ Special offer paywall error: $e");
      return null;
    }
  }
}
