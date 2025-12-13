import 'package:flutter/material.dart';

class MyButton extends StatelessWidget {
  final Color? backgroundColor;
  final Size? size;
  final BorderRadiusGeometry? radius;
  final Widget? child;
  final void Function()? onTap;
  final EdgeInsetsGeometry? margin;
  const MyButton({super.key, this.backgroundColor, this.size, this.radius, this.child, this.onTap,this.margin});

  @override
  Widget build(BuildContext context) {

    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        width: size?.width,
        height: size?.height,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: radius
        ),
        child: child,
      ),
    );
  }
}