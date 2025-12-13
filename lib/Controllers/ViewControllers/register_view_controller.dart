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
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegisterViewController extends StateNotifier<RegisterModel>{
  final Ref? ref;


  RegisterViewController(this.ref):super(RegisterModel());

  PageController pageController = PageController(initialPage: 0);

  TextEditingController usernameController = TextEditingController();
  HttpService httpService = HttpService();
   String? gender;

   List hobbies = [];
   UserModel? user;
   DateTime? birthdate;
   String credential = "google";

   List<String> imagePaths = [
    "assets/register1.png",
    "assets/register2.png",
    "assets/register3.png",
    "assets/register4.png",
   ];


   updateBirthdate(DateTime newBirthdate){
    birthdate = newBirthdate;
    debugPrint("New birthday: ${birthdate?.day}/${birthdate?.month}/${birthdate?.year}");
   }

  updateCredential(String newCredential){
    credential = newCredential;
  }

   updateUserModel(UserModel userModel){
    state = state.copyWith(userModel: userModel);
   }
   updateEmail(String? email){
    state = state.copyWith(email: email);
   }
   String? appleUserIdentifier;
   String? appleToken; // Apple authorizationCode (token revoke için)
   
   updateAppleUserIdentifier(String identifier){
    appleUserIdentifier = identifier;
    debugPrint("✅ Apple UserIdentifier stored: $identifier");
   }
   
   updateAppleToken(String token){
    appleToken = token;
    debugPrint("✅ Apple Token stored: $token");
   }
   updateUsername(String username){
    state = state.copyWith(username: username);
   }

  updateGender(String? newGender){
    gender = newGender;
    state = state.copyWith(gender: newGender);
    debugPrint("Selected gender: $gender");
  }

  updateHobbies(List newHobbies){
    hobbies = newHobbies;
    state = state.copyWith(selectedTags: List<String>.from(newHobbies));
    debugPrint("Selected hobbies: $hobbies");
  }

   toggleTag(String tag){
    List<String> currentTags = List<String>.from(state.selectedTags);
    if (currentTags.contains(tag)) {
      currentTags.remove(tag);
    } else {
      currentTags.add(tag);
    }
    state = state.copyWith(selectedTags: currentTags);
    hobbies = currentTags;
    debugPrint("Tags updated: $currentTags");
   }


  createUser()async{
    try {
      debugPrint("🟢 createUser started with credential: $credential");
      
      if (credential == "google" || credential == "facebook" || credential == "apple") {
        UserModel userModel = UserModel(
          username: usernameController.text, 
          email: state.email!, 
          accountCreatedDate: DateTime.now(), 
          birthdate: birthdate!,
          memberships: {}, 
          ownAgents: [], 
          verificated: 1, 
          credential: credential, 
          lastLogins: {},
          counrty: "tr",
          hobbies: hobbies,
          gender: gender ?? null
        );
        
        debugPrint("🌐 Sending signup request with credential: $credential");
        
        // Apple için userIdentifier ve appleToken'ı userModel'e ekle
        Map<String, dynamic> userModelMap = userModel.toMap();
        if (credential == "apple" && appleUserIdentifier != null) {
          userModelMap['appleUserIdentifier'] = appleUserIdentifier;
          userModelMap['userIdentifier'] = appleUserIdentifier; // Backend için alternatif key
          if (appleToken != null && appleToken!.isNotEmpty) {
            userModelMap['appleToken'] = appleToken;
            userModelMap['authorizationCode'] = appleToken; // Backend için alternatif key
            debugPrint("🍎 Adding Apple Token (authorizationCode) to userModel: $appleToken");
          }
          debugPrint("🍎 Adding Apple UserIdentifier to userModel: $appleUserIdentifier");
        }
        
        Response response = await httpService.post(
          path: AppConstants.signupURL,
          body: {
            "credential": credential,
            "userModel": userModelMap
          },
          headers: {"Content-type": "application/json"}
        );
        
        debugPrint("📡 Signup response status: ${response.statusCode}");
        
      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
          debugPrint("✅ Signup response: ${response.body}");
          
        if (json["token"] != null) {
            // Token kaydet locale
            await LocalService(prefs: await SharedPreferences.getInstance()).setToken(json["token"]);
            
            // Backend'den gelen user bilgilerini kullan (ID dahil)
            UserModel completeUserModel;
            if (json["user"] != null) {
              // Backend'den tam user bilgileri geldi
              completeUserModel = UserModel.fromMap(json["user"]);
              debugPrint("✅ UserModel from backend with ID: ${completeUserModel.id}");
            } else {
              // Sadece token geldi, local userModel'i kullan
              completeUserModel = userModel.copyWith(token: json["token"]);
              debugPrint("⚠️ Using local UserModel (ID may be null)");
            }
            
            // UserController'ı güncelle
            ref?.read(AllControllers.userController.notifier).updateUserModel(completeUserModel);
            debugPrint("✅ UserController updated with user ID: ${completeUserModel.id}");
            
            // UserModel tam olarak set edildikten sonra agents çek
            await Future.delayed(Duration(milliseconds: 200));
            
            debugPrint("🔄 Fetching conversations...");
            await ref?.read(AllControllers.chatViewController.notifier).getConversations();
            
            debugPrint("🔄 Fetching agents...");
            await ref?.read(AllControllers.agentsViewController.notifier).getAgents();
            await ref?.read(AllControllers.agentsViewController.notifier).getRecentAgents();
            
            debugPrint("✨ All data fetched, navigating to account created view");
            navigatorKey.currentState?.pushNamed('/accountCreatedView',);
          }
        } else if (response.statusCode == 400) {
          // Kullanıcı zaten var hatası
          var json = jsonDecode(response.body);
          debugPrint("⚠️ Signup failed - User already exists");
          debugPrint("Response: ${response.body}");
          
          // Kullanıcıya hata mesajı göster
          if (navigatorKey.currentContext != null) {
            ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
              SnackBar(
                content: Text(json["msg"] ?? "This email is already registered"),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          
          // Login sayfasına yönlendir
          await Future.delayed(Duration(seconds: 2));
          navigatorKey.currentState?.pushNamedAndRemoveUntil('/onboard', (route) => false);
        } else {
          debugPrint("❌ Signup failed with status: ${response.statusCode}");
          debugPrint("Response body: ${response.body}");
          
          // Genel hata mesajı
          if (navigatorKey.currentContext != null) {
            ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
              const SnackBar(
                content: Text("Something went wrong. Please try again."),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        debugPrint("⚠️ Unsupported credential: $credential");
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Error in createUser: $e");
      debugPrint("📍 StackTrace: $stackTrace");
    }
  }
   


   previousPage(){
     if (state.currentIndex > 0) {
       pageController.previousPage(duration: Duration(milliseconds: 500), curve: Curves.ease);
       state = state.copyWith(currentIndex: state.currentIndex - 1);
     } else {
       // İlk sayfadaysa geri git
       navigatorKey.currentState?.pop();
     }
   }

   pushBirthdayPage(){
    
     if (state.currentIndex == 0) {
              if (usernameController.text.trim().isNotEmpty) {
                updateUsername(usernameController.text);
                 debugPrint("Selected username ${state.userModel?.username}");
          pageController.nextPage(duration: Duration(seconds: 1), curve: Curves.ease);
         state = state.copyWith(currentIndex: 1);
        }
     }else if(state.currentIndex == 1){
     if (birthdate != null) {
         pageController.nextPage(duration: Duration(seconds: 1), curve: Curves.ease);
       state = state.copyWith(currentIndex: 2);
     }

     }else if(state.currentIndex == 2){
       // İlgi alanları sayfası - createUser register_view'dan çağrılıyor
     }

   }





}

class RegisterModel {
   UserModel? userModel;
   String? email;
   String? username;
   int currentIndex;
   List<String> selectedTags;
   String? gender;
  RegisterModel({
     this.userModel,
     this.email,
     this.username,
     this.currentIndex = 0,
     this.selectedTags = const [],
     this.gender,
  });


  RegisterModel copyWith({
    UserModel? userModel,
    String? email,
   String? username,
     int? currentIndex,
     List<String>? selectedTags,
     String? gender,
  }) {
    return RegisterModel(
      userModel: userModel ?? this.userModel,
      email: email ?? this.email,
      username: username ?? this.username,
      currentIndex: currentIndex ?? this.currentIndex,
      selectedTags: selectedTags ?? this.selectedTags,
      gender: gender ?? this.gender,
    );
  }
}
