// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/legacy.dart';

class LoginViewController extends StateNotifier<LoginState>{
  LoginViewController() : super(LoginState());
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  bool buttonActive = false;

  changeButtonState(){
    debugPrint("Email ${emailController.text}");
    debugPrint("Password ${passwordController.text}");
    if (emailController.text.isNotEmpty && passwordController.text.isNotEmpty) {

      state = state.copyWith(buttonActive:  true);
    }else{
        state = state.copyWith(buttonActive:  false);
    }
  }




}


class LoginState {
  final bool buttonActive;

  LoginState({
     this.buttonActive = false,
  });


  LoginState copyWith({
    bool? buttonActive,
  }) {
    return LoginState(
      buttonActive: buttonActive ?? this.buttonActive,
    );
  }

}
