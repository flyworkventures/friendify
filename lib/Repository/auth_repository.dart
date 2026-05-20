import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthRepository {
  // Google Sign-In instance with serverClientId for Android
  // Server Client ID from iOS Info.plist: 137535160742-let1k5rhqu6ecqmlpj91g7336gctc8mt.apps.googleusercontent.com
  // Android Client ID: 137535160742-pai7kjdb0nlr4lm9r1j4tc0o7ulpinli.apps.googleusercontent.com
  static bool _initialized = false;
  
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      if (Platform.isAndroid) {
        debugPrint("🔵 [Google Sign-In] Initializing for Android");
        debugPrint("🔵 [Google Sign-In] Client ID: 137535160742-pai7kjdb0nlr4lm9r1j4tc0o7ulpinli.apps.googleusercontent.com");
        debugPrint("🔵 [Google Sign-In] Server Client ID: 137535160742-let1k5rhqu6ecqmlpj91g7336gctc8mt.apps.googleusercontent.com");
        try {
          await GoogleSignIn.instance.initialize(
            clientId: "137535160742-pai7kjdb0nlr4lm9r1j4tc0o7ulpinli.apps.googleusercontent.com",
            serverClientId: "137535160742-let1k5rhqu6ecqmlpj91g7336gctc8mt.apps.googleusercontent.com",
          );
          debugPrint("✅ [Google Sign-In] Android initialization successful");
        } catch (e) {
          debugPrint("❌ [Google Sign-In] Android initialization failed: $e");
          rethrow;
        }
      } else {
        debugPrint("🍎 [Google Sign-In] Initializing for iOS");
        try {
          await GoogleSignIn.instance.initialize();
          debugPrint("✅ [Google Sign-In] iOS initialization successful");
        } catch (e) {
          debugPrint("❌ [Google Sign-In] iOS initialization failed: $e");
          rethrow;
        }
      }
      _initialized = true;
    }
  }

Future<GoogleSignInAccount?> googleSignIn() async{
  try {
    debugPrint("🔵 [Google Sign-In] Starting Google Sign-In process...");
    debugPrint("🔵 [Google Sign-In] Platform: ${Platform.isAndroid ? 'Android' : 'iOS'}");
    
    // Ensure Google Sign-In is initialized
    await _ensureInitialized();
    
    // Try to sign out first to clear any stale sessions (helps with reauth errors)
    try {
      debugPrint("🔵 [Google Sign-In] Checking for existing sessions...");
      await GoogleSignIn.instance.signOut();
      debugPrint("✅ [Google Sign-In] Cleared any existing sessions");
      
      // Wait a bit to ensure cleanup is complete
      await Future.delayed(Duration(milliseconds: 300));
    } catch (signOutError) {
      debugPrint("🔵 [Google Sign-In] No existing session to clear (this is OK)");
    }
    
    debugPrint("🔵 [Google Sign-In] Starting sign-in flow...");
    
    // Retry mechanism for "Account reauth failed" errors
    int maxRetries = 2;
    GoogleSignInAccount? account;
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint("🔵 [Google Sign-In] Attempt $attempt of $maxRetries...");
        
        // Start the sign-in flow using authenticate() method
        account = await GoogleSignIn.instance.authenticate(
          scopeHint: ['email', 'profile'],
        );
        
        // If we get here, sign-in was successful
        break;
      } on GoogleSignInException catch (e) {
        final errorString = e.toString();
        final isReauthError = errorString.contains('reauth') || 
                              errorString.contains('Account reauth') ||
                              (e.code == GoogleSignInExceptionCode.canceled && 
                               errorString.contains('[16]'));
        
        if (isReauthError && attempt < maxRetries) {
          debugPrint("⚠️ [Google Sign-In] Account reauth error on attempt $attempt");
          debugPrint("🔄 [Google Sign-In] Retrying after clearing sessions...");
          
          // More aggressive cleanup before retry
          try {
            await GoogleSignIn.instance.signOut();
            await Future.delayed(Duration(milliseconds: 500));
          } catch (_) {}
          
          continue; // Retry
        } else {
          // Re-throw if it's not a reauth error or we've exhausted retries
          rethrow;
        }
      }
    }
    
    if (account == null) {
      debugPrint("❌ [Google Sign-In] Failed after $maxRetries attempts");
      return null;
    }
    
    // Sign-in successful
    debugPrint("✅ [Google Sign-In] Sign-in successful!");
    debugPrint("✅ [Google Sign-In] Email: ${account.email}");
    debugPrint("✅ [Google Sign-In] Display Name: ${account.displayName}");
    debugPrint("✅ [Google Sign-In] ID: ${account.id}");
    debugPrint("✅ [Google Sign-In] Photo URL: ${account.photoUrl}");
    
    // Get authentication token for server verification
    try {
      GoogleSignInAuthentication auth = account.authentication;
      debugPrint("✅ [Google Sign-In] Authentication obtained");
      debugPrint("✅ [Google Sign-In] ID Token: ${auth.idToken != null ? 'Yes (${auth.idToken!.length} chars)' : 'No'}");
      if (auth.idToken != null) {
        debugPrint("✅ [Google Sign-In] ID Token preview: ${auth.idToken!.substring(0, auth.idToken!.length > 50 ? 50 : auth.idToken!.length)}...");
      }
    } catch (tokenError) {
      debugPrint("⚠️ [Google Sign-In] Could not get authentication tokens: $tokenError");
    }
    
    return account;
  } on GoogleSignInException catch (e) {
    debugPrint("❌ [Google Sign-In] GoogleSignInException occurred");
    debugPrint("❌ [Google Sign-In] Exception Code: ${e.code}");
    debugPrint("❌ [Google Sign-In] Exception String: $e");
    
    // Handle specific GoogleSignInException codes
    if (e.code == GoogleSignInExceptionCode.canceled) {
      debugPrint("⚠️ [Google Sign-In] Sign-in was CANCELED");
      debugPrint("⚠️ [Google Sign-In] This can happen if:");
      debugPrint("   1. User cancelled the sign-in dialog");
      debugPrint("   2. Account reauth failed (device account issue)");
      debugPrint("   3. Credential Manager error");
      
      final errorString = e.toString();
      if (errorString.contains('reauth') || errorString.contains('Account reauth')) {
        debugPrint("❌ [Google Sign-In] Account reauth failed detected!");
        debugPrint("❌ [Google Sign-In] Solution:");
        debugPrint("   1. Go to Android Settings > Accounts");
        debugPrint("   2. Remove the Google account from device");
        debugPrint("   3. Try signing in again");
        debugPrint("   4. Or clear app data and try again");
        debugPrint("   5. Or try signing out from Google Sign-In first");
      }
    } else {
      debugPrint("❌ [Google Sign-In] Error code: ${e.code}");
      debugPrint("❌ [Google Sign-In] Possible causes:");
      debugPrint("   1. SHA-1 fingerprint not added to Google Cloud Console");
      debugPrint("   2. Package name mismatch (expected: com.flywork.friendify)");
      debugPrint("   3. OAuth Client ID configuration incorrect");
      debugPrint("   4. Server Client ID not configured correctly");
      debugPrint("   5. Network connectivity issues");
    }
    
    log("❌ [Google Sign-In] GoogleSignInException in googleSignIn method. Code: ${e.code}, Error: $e");
    return null;
  } on PlatformException catch (e) {
    debugPrint("❌ [Google Sign-In] Platform Exception occurred");
    debugPrint("❌ [Google Sign-In] Error Code: ${e.code}");
    debugPrint("❌ [Google Sign-In] Error Message: ${e.message}");
    debugPrint("❌ [Google Sign-In] Error Details: ${e.details}");
    
    // Common error codes and their meanings
    switch (e.code) {
      case 'sign_in_canceled':
        debugPrint("⚠️ [Google Sign-In] User cancelled the sign-in");
        break;
      case 'sign_in_failed':
        debugPrint("❌ [Google Sign-In] Sign-in failed - check configuration");
        debugPrint("❌ [Google Sign-In] Possible causes:");
        debugPrint("   1. SHA-1 fingerprint not added to Google Cloud Console");
        debugPrint("   2. Package name mismatch (expected: com.flywork.friendify)");
        debugPrint("   3. OAuth Client ID configuration incorrect");
        debugPrint("   4. Server Client ID not configured correctly");
        break;
      case 'network_error':
        debugPrint("❌ [Google Sign-In] Network error - check internet connection");
        break;
      case 'sign_in_required':
        debugPrint("⚠️ [Google Sign-In] Sign-in required");
        break;
      case 'DEVELOPER_ERROR':
        debugPrint("❌ [Google Sign-In] DEVELOPER_ERROR - Configuration issue");
        debugPrint("❌ [Google Sign-In] Check:");
        debugPrint("   1. SHA-1 fingerprint in Google Cloud Console");
        debugPrint("   2. Package name: com.flywork.friendify");
        debugPrint("   3. AndroidManifest.xml intent-filter configuration");
        debugPrint("   4. OAuth Client ID settings");
        break;
      case '10':
        debugPrint("❌ [Google Sign-In] Error 10 - OAuth configuration issue");
        debugPrint("❌ [Google Sign-In] Check OAuth Client ID and package name");
        break;
      case '12500':
        debugPrint("❌ [Google Sign-In] Error 12500 - Sign-in cancelled or network issue");
        break;
      default:
        debugPrint("❌ [Google Sign-In] Unknown error code: ${e.code}");
    }
    
    log("❌ [Google Sign-In] Platform Exception in googleSignIn method. Code: ${e.code}, Message: ${e.message}, Details: ${e.details}");
    return null;
  } catch (e, stackTrace) {
    debugPrint("❌ [Google Sign-In] Unexpected error occurred");
    debugPrint("❌ [Google Sign-In] Error Type: ${e.runtimeType}");
    debugPrint("❌ [Google Sign-In] Error: $e");
    debugPrint("📍 [Google Sign-In] StackTrace: $stackTrace");
    log("❌ [Google Sign-In] Error in AuthRepo on googleSignIn method. Error: $e");
    log("📍 [Google Sign-In] StackTrace: $stackTrace");
    return null;
  }
}

  

  Future<Map<String, dynamic>?> appleSignIn() async{
    try {
      debugPrint("🍎 Starting Apple login...");
      
      // Check if Apple Sign In is available (iOS 13+)
      if (!Platform.isIOS) {
        debugPrint("⚠️ Apple Sign In is only available on iOS");
        return null;
      }
      
      // Request Apple Sign In
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      
      debugPrint("✅ Apple Auth credential received");
      debugPrint("📧 Email: ${credential.email}");
      debugPrint("👤 Name: ${credential.givenName} ${credential}");
      debugPrint("🆔 UserIdentifier: ${credential.userIdentifier}");
      
      // Apple sometimes doesn't return email/name on subsequent logins
      // Only available on first login
      String? email = credential.email;
      String? fullName = credential.givenName != null && credential.familyName != null
          ? "${credential.givenName} ${credential.familyName}"
          : credential.givenName ?? credential.familyName;
      
      return {
        'userIdentifier': credential.userIdentifier, // Unique Apple user ID
        'email': email,
        'fullName': fullName,
        'identityToken': credential.identityToken, // JWT token
        'authorizationCode': credential.authorizationCode,
      };
    } catch (e, stackTrace) {
      if (e.toString().contains('canceled')) {
        debugPrint("⚠️ Apple login CANCELLED by user");
      } else {
        log("❌ Error in AuthRepo on appleSignIn method. Error: $e");
        debugPrint("📍 StackTrace: $stackTrace");
      }
      return null;
    }
  }

}