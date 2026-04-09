import 'package:flutter/material.dart';

class MyButton extends StatelessWidget {
  final Color? backgroundColor;
  final Size? size;
  final BorderRadiusGeometry? radius;
  final Widget? child;
  final void Function()? onTap;
  final EdgeInsetsGeometry? margin;
  final BoxBorder? boxBorder;
  const MyButton({super.key, this.backgroundColor, this.size, this.radius, this.child, this.onTap,this.margin,this.boxBorder});

  @override
  Widget build(BuildContext context) {

    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        width: size?.width,
        height: size?.height,
        decoration: BoxDecoration(
          border: boxBorder,
          color: backgroundColor,
          borderRadius: radius
        ),
        child: child,
      ),
    );
  }
}


class MyGradientButton extends StatelessWidget {
  final List<Color>? colors;
  final Size? size;
  final AlignmentGeometry? end;
  final AlignmentGeometry? begin;
  final BorderRadiusGeometry? radius;
  final Widget? child;
  final void Function()? onTap;
  final EdgeInsetsGeometry? margin;
  const MyGradientButton({super.key, this.size, this.radius, this.child, this.onTap,this.margin,  this.colors, this.end, this.begin});

  @override
  Widget build(BuildContext context) {

    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        width: size?.width,
        height: size?.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors ?? [Color(0xffD55EFF),Color(0xff2D30FF)],end: end ?? Alignment.centerRight,begin: AlignmentGeometry.centerLeft),
          borderRadius: radius
        ),
        child: child,
      ),
    );
  }
}

