// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Http/http_service.dart';
import 'package:friendfy/Models/user_model.dart';
import 'package:friendfy/Services/local_service.dart';
import 'package:friendfy/main.dart';
import 'package:friendfy/utils/app_constants.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:friendfy/Repository/auth_repository.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardViewController extends StateNotifier<OnboardViewModel>{
  final Ref ref; 

  OnboardViewController(this.ref) : super(OnboardViewModel(state: OnboardViewState.normal));

  AuthRepository authRepository = AuthRepository();
  HttpService httpService = HttpService();

  googleAuth ()async{
    LocalService localService = LocalService(prefs: await SharedPreferences.getInstance());
   GoogleSignInAccount? googleSignInAccount = await authRepository.googleSignIn();
   if (googleSignInAccount != null) {
    debugPrint("Account not null");
   Response response = await httpService.post(path: AppConstants.checkMailURL,body: {"email": googleSignInAccount.email},headers: {"Content-type":"application/json"});
   if (response.statusCode == 200) {
    debugPrint("Account 200");
    // UserModel? userModel;
    ref.read(AllControllers.registerViewController.notifier).updateEmail(googleSignInAccount.email);
    ref.read(AllControllers.registerViewController.notifier).updateCredential("google");
   // ref.read(AllControllers.registerViewController.notifier).updateUsername(googleSignInAccount.displayName);
      await navigatorKey.currentState?.pushNamed('/register');
   } else {
      debugPrint("Account 2001");
     
      var json = jsonDecode(response.body);
       log("Usermodel: ${json["model"][0]}");
       UserModel userModel = UserModel.fromMap(json["model"][0]);
      
      localService.setToken(userModel.token!);
      ref.read(AllControllers.userController.notifier).updateUserModel(userModel);
      debugPrint("✅ UserController updated with user ID: ${userModel.id}");
      
      // State güncellemesini bekle
      await Future.delayed(Duration(milliseconds: 200));
      
      debugPrint("🔄 Fetching user data...");
               await ref.read(AllControllers.chatViewController.notifier).getConversations();
         await ref.read(AllControllers.agentsViewController.notifier).getAgents();
         await ref.read(AllControllers.agentsViewController.notifier).getRecentAgents();
      
      debugPrint("✨ All data fetched, navigating to home");
        await navigatorKey.currentState?.pushNamed('/bottomNavbar');
   }
   } else {
     
   }
  }

  facebookAuth ()async{
    try {
      debugPrint("🟢 facebookAuth started");
      LocalService localService = LocalService(prefs: await SharedPreferences.getInstance());
      
      debugPrint("🟢 Calling authRepository.facebookSignIn()");
      Map<String, dynamic>? facebookData = await authRepository.facebookSignIn();
      
      if (facebookData != null) {
        debugPrint("✅ Facebook Account not null");
        debugPrint("📦 Facebook data: $facebookData");
        
        final userData = facebookData['userData'];
        final String email = userData['email'] ?? '';
        final String name = userData['name'] ?? '';
        
        debugPrint("📧 Email: $email, Name: $name");
        
        if (email.isEmpty) {
          debugPrint("❌ Email not provided by Facebook");
          return;
        }

        debugPrint("🌐 Checking email on server...");
        Response response = await httpService.post(
          path: AppConstants.checkMailURL,
          body: {"email": email},
          headers: {"Content-type":"application/json"}
        );
        
        debugPrint("📡 Server response: ${response.statusCode}");
        
        if (response.statusCode == 200) {
          debugPrint("✨ Facebook Account 200 - New user, navigating to register");
          ref.read(AllControllers.registerViewController.notifier).updateEmail(email);
          ref.read(AllControllers.registerViewController.notifier).updateCredential("facebook");
          await navigatorKey.currentState?.pushNamed('/register');
        } else {
          debugPrint("✨ Facebook Account exists, logging in");
          var json = jsonDecode(response.body);
          log("Usermodel: ${json["model"][0]}");
          UserModel userModel = UserModel.fromMap(json["model"][0]);
          
          localService.setToken(userModel.token!);
          ref.read(AllControllers.userController.notifier).updateUserModel(userModel);
          debugPrint("✅ UserController updated with user ID: ${userModel.id}");
          
          // State güncellemesini bekle
          await Future.delayed(Duration(milliseconds: 200));
          
          debugPrint("🔄 Fetching user data...");
          await ref.read(AllControllers.chatViewController.notifier).getConversations();
          await ref.read(AllControllers.agentsViewController.notifier).getAgents();
          await ref.read(AllControllers.agentsViewController.notifier).getRecentAgents();
          
          debugPrint("✨ All data fetched, navigating to home");
          await navigatorKey.currentState?.pushNamed('/bottomNavbar');
        }
      } else {
        debugPrint("⚠️ Facebook login cancelled or failed");
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Error in facebookAuth: $e");
      debugPrint("📍 StackTrace: $stackTrace");
    }
  }

  appleAuth() async{
    try {
      debugPrint("🍎 appleAuth started");
      LocalService localService = LocalService(prefs: await SharedPreferences.getInstance());
      
      debugPrint("🍎 Calling authRepository.appleSignIn()");
      Map<String, dynamic>? appleData = await authRepository.appleSignIn();
      
      if (appleData != null) {
        debugPrint("✅ Apple Account not null");
        debugPrint("📦 Apple data: $appleData");
        
        final String? email = appleData['email'];
        final String? fullName = appleData['fullName'];
        final String userIdentifier = appleData['userIdentifier'];
        final String? authorizationCode = appleData['authorizationCode']; // Apple token (revoke için)
        
        debugPrint("📧 Email: $email, Name: $fullName, ID: $userIdentifier");
        
        // Apple için userIdentifier kontrolü (Apple'ın benzersiz kullanıcı ID'si)
        if (userIdentifier.isEmpty) {
          debugPrint("❌ No userIdentifier provided by Apple");
          return;
        }

        debugPrint("🌐 Checking Apple user with identifier on server...");
        Response response = await httpService.post(
          path: AppConstants.checkMailURL,
          body: {"appleUserIdentifier": userIdentifier},
          headers: {"Content-type":"application/json"}
        );
        
        debugPrint("📡 Server response: ${response.statusCode}");
        
        if (response.statusCode == 200) {
          debugPrint("✨ Apple Account 200 - New user, navigating to register");
          final registerController = ref.read(AllControllers.registerViewController.notifier);
          registerController.updateEmail(email ?? "$userIdentifier@privaterelay.appleid.com");
          registerController.updateCredential("apple");
          
          // Apple userIdentifier ve authorizationCode kaydet (register sırasında kullanılacak)
          registerController.updateAppleUserIdentifier(userIdentifier);
          if (authorizationCode != null && authorizationCode.isNotEmpty) {
            registerController.updateAppleToken(authorizationCode);
            debugPrint("🍎 Apple Token (authorizationCode) stored for account deletion: $authorizationCode");
          }
          debugPrint("🍎 Apple UserIdentifier stored for registration: $userIdentifier");
          
          // Apple'dan alınan kullanıcı adını username controller'a ekle
          if (fullName != null && fullName.isNotEmpty) {
            registerController.usernameController.text = fullName;
            registerController.updateUsername(fullName);
            debugPrint("✅ Apple username set to controller: $fullName");
          }
          
          await navigatorKey.currentState?.pushNamed('/register');
        } else {
          debugPrint("✨ Apple Account exists, logging in");
          var json = jsonDecode(response.body);
          log("Usermodel: ${json["model"][0]}");
          UserModel userModel = UserModel.fromMap(json["model"][0]);
          
          localService.setToken(userModel.token!);
          ref.read(AllControllers.userController.notifier).updateUserModel(userModel);
          debugPrint("✅ UserController updated with user ID: ${userModel.id}");
          
          // State güncellemesini bekle
          await Future.delayed(Duration(milliseconds: 200));
          
          debugPrint("🔄 Fetching user data...");
          await ref.read(AllControllers.chatViewController.notifier).getConversations();
          await ref.read(AllControllers.agentsViewController.notifier).getAgents();
          await ref.read(AllControllers.agentsViewController.notifier).getRecentAgents();
          
          debugPrint("✨ All data fetched, navigating to home");
          await navigatorKey.currentState?.pushNamed('/bottomNavbar');
        }
      } else {
        debugPrint("⚠️ Apple login cancelled or failed");
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Error in appleAuth: $e");
      debugPrint("📍 StackTrace: $stackTrace");
    }
  }

  guestLogin() async {
    try {
      debugPrint("👤 guestLogin started");
      LocalService localService = LocalService(prefs: await SharedPreferences.getInstance());
      
      // Device ID al veya oluştur
      String deviceId = await localService.getOrCreateGuestDeviceId();
      debugPrint("📱 Device ID: $deviceId");
      
      // Guest login endpoint'ine istek gönder
      Response response = await httpService.post(
        path: AppConstants.guestLoginURL,
        body: {"deviceId": deviceId},
        headers: {"Content-type": "application/json"}
      );
      
      debugPrint("📡 Server response: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        debugPrint("✅ Guest login successful");
        
        UserModel userModel = UserModel.fromMap(json["user"]);
        
        localService.setToken(userModel.token!);
        ref.read(AllControllers.userController.notifier).updateUserModel(userModel);
        debugPrint("✅ UserController updated with guest user ID: ${userModel.id}");
        
        // State güncellemesini bekle
        await Future.delayed(Duration(milliseconds: 200));
        
        debugPrint("🔄 Fetching user data...");
        await ref.read(AllControllers.chatViewController.notifier).getConversations();
        await ref.read(AllControllers.agentsViewController.notifier).getAgents();
        await ref.read(AllControllers.agentsViewController.notifier).getRecentAgents();
        
        debugPrint("✨ All data fetched, navigating to home");
        await navigatorKey.currentState?.pushNamed('/bottomNavbar');
      } else {
        debugPrint("❌ Guest login failed: ${response.statusCode}");
        var errorJson = jsonDecode(response.body);
        debugPrint("❌ Error: ${errorJson['msg']}");
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Error in guestLogin: $e");
      debugPrint("📍 StackTrace: $stackTrace");
    }
  }

  
}

class OnboardViewModel {
  final OnboardViewState state;
  OnboardViewModel({
    required this.state,
  });
  

  OnboardViewModel copyWith({
    OnboardViewState? state,
  }) {
    return OnboardViewModel(
      state: state ?? this.state,
    );
  }


}



enum OnboardViewState{
  loading,
  normal
}

