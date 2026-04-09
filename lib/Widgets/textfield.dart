
import 'package:friendfy/Themes/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';



class MyTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final int? maxLength;
  final int? maxLines;
  final InputBorder? border;
  final InputBorder? focusedBorder;
  final bool? enabled;
  final Color? fillColor;
  final bool? filled;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool? obscure; 
  final TextStyle? textStyle;
  final Color? cursorColor;
  final TextStyle? hintStyle;
  final String? counterText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final double? width;
  final double? height;
  final Function(String)? onChanged;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? contentPadding;
  final TextAlign? textAlign;
  final BorderRadius? radius;
  const MyTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.maxLength,
    this.maxLines = 1,
    this.border,
    this.focusedBorder,
    this.enabled = true,
    this.fillColor,
    this.filled = false,
    this.hintText = "Hello World!",
    this.prefixIcon,
    this.suffixIcon,
    this.obscure = false,
    this.textStyle,
    this.cursorColor,
    this.hintStyle,
    this.counterText = "",
    this.validator,
    this.keyboardType,
    this.width,
    this.height ,
    this.onChanged,
    this.margin,
    this.contentPadding,
    this.textAlign,
    this.radius,
    });

  @override
  Widget build(BuildContext context) {




    var defaultBorder = OutlineInputBorder(borderRadius: radius ?? BorderRadius.circular(50),borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.5)));
    return Container(
      margin: margin ?? const EdgeInsets.all(0),

      width: width,
      height: height ,
      child: TextFormField(
        focusNode: focusNode,
        controller: controller,
        maxLength: maxLength,
        maxLines: maxLines,
        keyboardType: keyboardType,
        obscureText: obscure!,
        style: textStyle ?? GoogleFonts.poppins(fontWeight: FontWeight.w500,fontSize: 14.sp),
        textAlign: textAlign ?? TextAlign.left,
        cursorColor: cursorColor ?? MyColors.purple,
        validator: validator,
        onChanged: onChanged,
        
        decoration: InputDecoration(
          prefixIconColor: Colors.grey.withValues(alpha: 0.5),
           contentPadding: contentPadding,
          counterText: counterText,
          border: border ?? defaultBorder,
          enabled: enabled!,
          focusedBorder: focusedBorder ?? defaultBorder,
          fillColor: fillColor ?? Theme.of(context).inputDecorationTheme.fillColor,
          filled: filled,
          hintText: hintText,
          enabledBorder: border ?? defaultBorder,
          hintStyle: hintStyle ?? GoogleFonts.inter(color: Colors.grey.withOpacity(0.4),fontSize: 13,fontWeight: FontWeight.w400),
          suffixIcon: suffixIcon,
          prefixIcon: prefixIcon ,
    
          
        ),
      ),
    );
  }
}
