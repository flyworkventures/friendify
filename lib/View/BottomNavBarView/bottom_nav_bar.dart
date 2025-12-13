import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/Themes/colors.dart';
import 'package:heroicons/heroicons.dart';

class MyBottomNavBar extends StatelessWidget {
  final List<MyBottomNavBarItem>? items;
  final Color? backgroundColor;
  final double width;
  final int currentIndex;
  

  const MyBottomNavBar({super.key, this.items, this.backgroundColor, required this.width, required this.currentIndex});
  

  @override
  Widget build(BuildContext context) {
    return Container(
                margin: EdgeInsets.only(bottom: 7,right: 20,left: 20).r,
                width: double.infinity,
                height: 60.h,
                padding: EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                       blurRadius: 4,
                       blurStyle: BlurStyle.outer,
                      offset: Offset(0, 1),
                      color: Colors.grey.withOpacity(0.4)
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: items?.map((item) => item.build(items?[currentIndex] == item ? true : false)).toList() ?? [],
                ),
              );
  }
}



class MyBottomNavBarItem {
  final HeroIcons icon;
  final Color? activeColor;
  final Color? inactiveColor;
  final VoidCallback? onTap;

  MyBottomNavBarItem({
    required this.icon,
    this.onTap,
    this.inactiveColor = Colors.grey,
    this.activeColor = const Color(0xffAB10E2),
  });

  Widget build(bool isActive, {double size = 24.0}) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 60.w,
        child: HeroIcon(
          icon,
          color: isActive ? activeColor : inactiveColor,
          size: size,
        ),
      ),
    );
  }
}