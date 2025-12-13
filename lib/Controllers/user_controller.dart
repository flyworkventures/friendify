import 'dart:developer';

import 'package:flutter_riverpod/legacy.dart';
import 'package:friendfy/Models/user_model.dart';

class UserController extends StateNotifier<UserModel?> {


  UserController() : super(null);


  updateUserModel(UserModel newmodel){
    state = newmodel;
    log("New Model: ${state?.email}");
  }


  
}