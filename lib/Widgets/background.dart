import 'package:friendfy/Themes/colors.dart';
import 'package:flutter/material.dart';

class BackgroundWidget extends StatelessWidget {
  final Widget child;
  const BackgroundWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return          Container(
          width: MediaQuery.sizeOf(context).width,
          height: MediaQuery.sizeOf(context).height,
          decoration: BoxDecoration(
          
            gradient: LinearGradient(colors: [MyColors.purple,MyColors.purpleAccent,MyColors.pinkAccent,MyColors.pink],begin: Alignment.topLeft,end: Alignment.bottomRight)
          ),
          child: child,
      
        );
  }
}