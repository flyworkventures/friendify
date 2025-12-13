import 'dart:developer';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthRepository {
  // Google Sign-In instance with serverClientId for Android
  // Server Client ID from iOS Info.plist: 137535160742-let1k5rhqu6ecqmlpj91g7336gctc8mt.apps.googleusercontent.com
  GoogleSignIn signIn = GoogleSignIn.instance;

Future<GoogleSignInAccount?> googleSignIn() async{
  try {
   if (Platform.isAndroid) {
      signIn.initialize(clientId: "137535160742-pai7kjdb0nlr4lm9r1j4tc0o7ulpinli.apps.googleusercontent.com",serverClientId: "137535160742-let1k5rhqu6ecqmlpj91g7336gctc8mt.apps.googleusercontent.com");
   }
    GoogleSignInAccount account = await signIn.authenticate();
     debugPrint("Google Auth account: ${account.email},${account.displayName}");
     return account;
 } catch (e) {
   log("Error in AuthRepo on googleSignIn method. Error $e");
   return null;
    }
  }

  Future<Map<String, dynamic>?> facebookSignIn() async{
    try {
      debugPrint("🔷 Starting Facebook login...");
      debugPrint("🔷 Platform: ${Platform.isAndroid ? 'Android' : 'iOS'}");
      
      // Check if user is already logged in
      final AccessToken? accessToken = await FacebookAuth.instance.accessToken;
      if (accessToken != null) {
        debugPrint("🔷 Found existing access token, logging out first...");
        await FacebookAuth.instance.logOut();
      }
      
      // For Android, try Facebook login
      LoginResult result;
      if (Platform.isAndroid) {
        debugPrint("🔷 Android detected - attempting Facebook login");
        result = await FacebookAuth.instance.login(
          permissions: ['email', 'public_profile'],
        );
        debugPrint("🔷 Login result status: ${result.status}");
      } else {
        // iOS
        result = await FacebookAuth.instance.login(
          permissions: ['email', 'public_profile'],
        );
      }

      debugPrint("🔷 Facebook login result status: ${result.status}");
      debugPrint("🔷 Facebook login result message: ${result.message}");
      
      if (result.message != null) {
        debugPrint("🔷 Facebook login message details: ${result.message}");
      }

      if (result.status == LoginStatus.success) {
        debugPrint("✅ Facebook login SUCCESS");
        
        // Get access token
        final AccessToken? token = result.accessToken;
        debugPrint("✅ Facebook Auth token exists: ${token != null}");
        if (token != null) {
          debugPrint("✅ Facebook Auth token: ${token.token}");
          debugPrint("✅ Token expiration: ${token.expires}");
        }
        
        // Get user data
        try {
          final userData = await FacebookAuth.instance.getUserData();
          debugPrint("✅ Facebook Auth userData: $userData");
          
          return {
            'userData': userData,
            'accessToken': token?.token,
          };
        } catch (userDataError) {
          debugPrint("⚠️ Could not fetch user data, but login succeeded: $userDataError");
          // Return with access token even if user data fetch fails
          return {
            'userData': {'email': null, 'name': null},
            'accessToken': token?.token,
          };
        }
      } else if (result.status == LoginStatus.cancelled) {
        debugPrint("⚠️ Facebook login CANCELLED by user");
        return null;
      } else if (result.status == LoginStatus.failed) {
        debugPrint("❌ Facebook login FAILED: ${result.message}");
        debugPrint("❌ Error code: ${result.message}");
        
        // Provide more helpful error message
        if (result.message?.contains('feature') ?? false || 
            result.message!.contains('unavailable') ) {
          debugPrint("❌ 'Feature Unavailable' error detected!");
          debugPrint("❌ This usually means:");
          debugPrint("   1. Facebook App is in Development mode (should be Live)");
          debugPrint("   2. Key Hash is missing from Facebook Developer Console");
          debugPrint("   3. Package name mismatch (current: com.flywork.friendify)");
          debugPrint("   4. Facebook Login feature not approved");
        }
        
        return null;
      } else {
        debugPrint("⚠️ Facebook login status: ${result.status}");
        debugPrint("⚠️ Unknown status, returning null");
        return null;
      }
    } catch (e, stackTrace) {
      log("❌ Error in AuthRepo on facebookSignIn method. Error: $e");
      debugPrint("📍 StackTrace: $stackTrace");
      debugPrint("❌ Error type: ${e.runtimeType}");
      if (e.toString().contains('feature') || e.toString().contains('unavailable')) {
        debugPrint("❌ This is a 'Feature Unavailable' error!");
        debugPrint("❌ Please check:");
        debugPrint("   1. Facebook Developer Console > Settings > Basic");
        debugPrint("   2. Add Android platform with package: com.flywork.friendify");
        debugPrint("   3. Add Key Hashes (debug and release)");
        debugPrint("   4. Ensure app is in 'Live' mode, not 'Development'");
      }
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