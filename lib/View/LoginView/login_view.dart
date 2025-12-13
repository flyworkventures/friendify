import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Themes/colors.dart';
import 'package:friendfy/Themes/fonts.dart';
import 'package:friendfy/View/AgentsScreen/agents_screen.dart';
import 'package:friendfy/Widgets/background.dart';
import 'package:friendfy/Widgets/button.dart';
import 'package:friendfy/Widgets/textfield.dart';
import 'package:friendfy/utils/app_constants.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => LoginViewState();
}

class LoginViewState extends ConsumerState<LoginView> {
  TextEditingController emailController = TextEditingController(text: "ahmet@fly-work.com");
  TextEditingController passwordController = TextEditingController(text: "tester123");
  bool loading = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
    backgroundColor: Colors.white,
      body: SafeArea(
        
        child: SingleChildScrollView(
          padding: EdgeInsets.only(right: 30,left: 30,top: 70),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Welcome 👋",style: GoogleFonts.poppins(fontWeight: FontWeight.w600,fontSize: 24.sp)),
              Text("I am happy to see you. You can continue where you left off by logging in",style: GoogleFonts.poppins(color: Colors.black,fontWeight: FontWeight.w300,fontSize: 14.sp)),
         
              SizedBox(height: 40.h,),
                    
              Column(
                children: [
                           
                              MyTextField(
                                onChanged: (a) => ref.read(AllControllers.loginViewController.notifier).changeButtonState(),
                                prefixIcon: Icon(Ionicons.mail_outline),
              hintText: "Enter email",
              controller: ref.read(AllControllers.loginViewController.notifier).emailController),
                              
               SizedBox(height: 20.h,),
                              
                MyTextField(
                   onChanged: (a) => ref.read(AllControllers.loginViewController.notifier).changeButtonState(),
                  prefixIcon: Icon(Ionicons.lock_closed_outline),
              hintText: "Password",
              controller: ref.read(AllControllers.loginViewController.notifier).passwordController),
                ],
              ),
           
                    
                 SizedBox(height: 10.h,),
                    
                 Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                 // rememberMe(),
                 SizedBox(),
                  GestureDetector(
                    child: Text("Forgot Password?",style: GoogleFonts.poppins(color: MyColors.purple,fontWeight: FontWeight.w400,fontSize: 12.sp),),
                  )
                  ],
                 ),
                  
                 SizedBox(height: 30.h,),
                  
                 GestureDetector(
                  onTap: () {
                    login();
                  },
                  child: Container(
                    width: MediaQuery.sizeOf(context).width,
                    height: 50.h,
                    margin: EdgeInsets.symmetric(horizontal: 20.w),
                    decoration: BoxDecoration(
                      color: ref.watch(AllControllers.loginViewController.notifier).buttonActive ? MyColors.purple : MyColors.purple.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(50.r)
                    ),
                    child: Center(
                      child: loading ? SizedBox(width: 32,height: 32,child: CircularProgressIndicator(color: Colors.white,),)  :  Text("Sign In",style: GoogleFonts.poppins(color: Colors.white,fontWeight: FontWeight.w500,fontSize: 15.sp),),
                    ),
                  ),
                 ),
                  
                  
                 SizedBox(height: 30.h,),
                 signUpWithWidget(),
                 SizedBox(height: 30.h,),
                 
                 Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                 socialButtons(Image.asset("assets/google.png",height: 30.h,fit: BoxFit.cover,),"Sign In with Google"),
                 socialButtons(Image.asset("assets/facebook.png",height: 30.h,),"Sign In with Facebook"),
                  socialButtons(SvgPicture.asset("assets/apple.svg",height: 30.h),"Sign In with Apple"),
                  ],
                 ),
                  
                 
                  
            ],
          ),
        ),
      ),
    );





  }


Future login() async{
  setState(() {
    loading = true;
  });
 var res = await http.post(Uri.parse("${AppConstants.baseURL}${AppConstants.loginURL}",),headers: {'Content-Type': 'application/json'},body: jsonEncode({
  "email": emailController.text,
  "password": passwordController.text,
  "credential": "email"
 }));
 if (res.statusCode == 200) {
   var json = jsonDecode(res.body);
   SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
   sharedPreferences.setString("token",json["token"]);
   Navigator.push(context,CupertinoPageRoute(builder: (context)=> AgentsScreen()));

     setState(() {
    loading = false;
  });



 } else {
   
 }
}





Widget socialButtons(Widget icon,String text){
  return Container(

  height: 45.h,
  padding: EdgeInsets.symmetric(horizontal: 10),
  margin: EdgeInsets.symmetric(horizontal: 10,vertical: 5),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(50),
    border: Border.all(color: Color(0xffC2C2C2))
  ),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      icon,
      Text(text,style: GoogleFonts.poppins(color: Color(0xff8A8A8A),fontSize: 12.sp),),
      SizedBox()
    ],
  ),
  );
}


Widget signUpWithWidget(){
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 100.w,
        height: 0.5.h,
        color: Color(0xffB1B1B1),
        margin: EdgeInsets.only(right: 10),
      ),

      Text("OR",style: GoogleFonts.poppins(color: Color(0xffB1B1B1),fontWeight: FontWeight.w400,fontSize: 12.sp),),


            Container(
               margin: EdgeInsets.only(left: 10),
        width: 100.w,
        height: 0.5.h,
        color: Color(0xffB1B1B1),
      ),


    ],
  );
}


  Widget rememberMe(){
    return Row(
      children: [
        Checkbox(
        value: false,
        onChanged: (a){},
        side: BorderSide(
          color: Colors.grey.withValues(alpha: 0.7),
          width: 1
        ),
        shape: RoundedRectangleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),borderRadius: BorderRadius.circular(5)),),
  
        Text("Remember me",style: GoogleFonts.poppins(fontWeight: FontWeight.w300,fontSize: 12.sp))
      ],
    );
  }
}