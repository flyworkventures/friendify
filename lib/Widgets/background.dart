import 'package:friendfy/Themes/colors.dart';
import 'package:flutter/material.dart';

class BackgroundWidget extends StatelessWidget {
  final Widget child;
  const BackgroundWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return  Stack(
      children: [
        Image.asset("assets/images/bckg.png",width: MediaQuery.sizeOf(context).width,height: MediaQuery.sizeOf(context).height,fit: BoxFit.cover,),
        child
      ],
    );
  }
}