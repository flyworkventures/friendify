import 'package:flutter/cupertino.dart';


class AppNavigate {
  static push({required Widget page , required BuildContext context}){
    Navigator.push(context, CupertinoPageRoute(builder: (context)=> page));
  }




  static pushAndRemoveUntil({required Widget page , required BuildContext context}){
    Navigator.pushAndRemoveUntil(context, CupertinoPageRoute(builder: (context)=> page), (a)=> false);
  }

}