import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:heroicons/heroicons.dart';

class MyBottomNavBar extends StatelessWidget {
  final List<MyBottomNavBarItem>? items;
  final Color? backgroundColor;
  final double width;
  final int currentIndex;
  

  const MyBottomNavBar({super.key, this.items, this.backgroundColor, required this.width, required this.currentIndex});
  

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: 20,left: 20).r,
      child: ClipRRect(
         borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10,sigmaY: 10),
          child: Container(
                     
                      width: double.infinity,
                      height: 60.h,
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(40),
                    
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: items?.map((item) => item.build(items?[currentIndex] == item ? true : false)).toList() ?? [],
                      ),
                    ),
        ),
      ),
    );
  }
}



class MyBottomNavBarItem {
  final String icon;
  final Color? activeColor;
  final Color? inactiveColor;
  final VoidCallback? onTap;

  MyBottomNavBarItem({
    required this.icon,
    this.onTap,
    this.inactiveColor = Colors.grey,
    this.activeColor = Colors.white,
  });

  Widget build(bool isActive, {double size = 24.0}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 60.w,
        height: 60.h,
        alignment: Alignment.center,
        child: SvgPicture.asset(
          icon,
          color: isActive ? activeColor : Colors.white.withValues(alpha: 0.5),

        ),
      ),
    );
  }
}