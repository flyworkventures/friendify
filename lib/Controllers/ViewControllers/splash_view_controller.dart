import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:friendfy/AppNavigate/app_navigate.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Http/http_service.dart';
import 'package:friendfy/Models/user_model.dart';
import 'package:friendfy/Services/local_service.dart';
import 'package:friendfy/main.dart';
import 'package:friendfy/utils/app_constants.dart';
import 'package:riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashViewController extends StateNotifier<void>{
  SplashViewState pageState = SplashViewState.initial;
  final Ref ref; 

  SplashViewController(this.ref) : super(null);

  init() async{
    AppConfigState appState = await getConfig();

    if (appState == AppConfigState.normal) {
         bool? firstOpen = await getFirstOpen();
    if (firstOpen == true || firstOpen == null) {
      changeFirstOpen();
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/onboard', (a)=>false);
    } else {
      // localden jwt Tokeni getireceğiz
      LocalService localService = LocalService(prefs: await SharedPreferences.getInstance());
      HttpService httpService = HttpService(ref: ref);
      String? token = await localService.getToken();

       if (token != null) {
        debugPrint("Token null değil");
        //token doğrula
        var response = await httpService.post(path: AppConstants.verifyTokenURL,body: {"token":token});
        var json = jsonDecode(response.body);
        debugPrint("JSON: $json");
        if (json["msg"] == "Valid Token") {
          UserModel userModel = UserModel.fromMap(json["user"]);
          ref.read(AllControllers.userController.notifier).updateUserModel(userModel);
         await ref.read(AllControllers.chatViewController.notifier).getConversations();
         await ref.read(AllControllers.agentsViewController.notifier).getAgents();
         await ref.read(AllControllers.agentsViewController.notifier).getRecentAgents();
          await navigatorKey.currentState?.pushNamedAndRemoveUntil('/bottomNavbar', (a)=>false);
        }

       } else {
             // token bilgisi yok
              Future.delayed(Duration(seconds: 2),()async=> await navigatorKey.currentState?.pushNamedAndRemoveUntil('/onboard', (a)=>false));
       }

    
 
    }
    }else if(appState == AppConfigState.maintenance){

    }else{
 navigatorKey.currentState?.pushNamed('/serverError');
    }
 
  }


  Future<bool?> getFirstOpen() async{
   LocalService localService =  LocalService(prefs:await SharedPreferences.getInstance());
   bool? firstOpen =await  localService.getFirstOpen();
   return firstOpen;}

  
  Future<void> changeFirstOpen() async{
   LocalService localService =  LocalService(prefs:await SharedPreferences.getInstance());
   await  localService.changeFirstOpen(false);
 }


Future<AppConfigState> getConfig()async{
try {
    HttpService httpService = HttpService(ref: ref);
  var response = await httpService.post(path: AppConstants.configURL);
  if (response.statusCode == 200) {
    return AppConfigState.normal;
  }else{
   return AppConfigState.error;
  }
} catch (e) {
  
  return AppConfigState.error;
}

}


}


enum SplashViewState{loading,done,initial}
enum AppConfigState{normal,maintenance,error}