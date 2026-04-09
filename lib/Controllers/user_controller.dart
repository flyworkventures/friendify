import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Models/user_model.dart';

class UserController extends StateNotifier<UserModel?> {
  final Ref? ref;

  UserController(this.ref) : super(null);


  updateUserModel(UserModel? newmodel){
    state = newmodel;
    log("New Model: ${state?.email}");
    
    // Kullanıcı değiştiğinde bildirimleri yeniden yükle
    if (ref != null && newmodel != null) {
      ref!.read(AllControllers.notificationsViewController.notifier).reloadNotificationsForUser();
    }
  }


  
}