import 'package:flutter/material.dart';

class MyColors{
  static Color blue = Colors.blue;
  static Color purple = Color(0xffAB10E2);
  static Color purplesical = Color(0xff9282FF);
  static Color purpleAccent = Color(0xffCBD0FA);
  static Color pinkAccent = Color(0xffEAD4D0);
  static Color pink = Color(0xffD4A6E4);
  static Color orangeAccent = Color(0xffF7C7B3);
  static Gradient defaultGradient = LinearGradient(colors: [purple,purpleAccent,pinkAccent,pink],begin: Alignment.topLeft,end: Alignment.bottomRight);

}