import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
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
import 'package:substring_highlight/substring_highlight.dart';
import 'package:url_launcher/url_launcher.dart';
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

      body: BackgroundWidget(
        child: SafeArea(
        
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [

               SizedBox(
                height: 337.h,
                width: 385.w,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Image.asset("assets/images/daisy.png",width: 212.w,height: 263.7.h,)),
                    Align(
                      alignment: Alignment.topRight,
                      child: Image.asset("assets/images/lara.png",width: 207.w,height: 257.31.h,)),
                  ],
                ),
               ),

               SizedBox(height: 20.h,),



             Text("Let's Get Started",style: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.w700,fontSize: 24.sp),) ,
               Text("Find the perfect match for you and start chatting right away",style: GoogleFonts.quicksand(color: Colors.white,fontSize: 16.sp,fontWeight: FontWeight.w400,),textAlign: TextAlign.center,) ,
          
          SizedBox(height: 40.h,),
          
          
              if(Platform.isIOS)...[
          
                   MyButton(
                    onTap: ()async{
                             debugPrint("🍎 Apple button clicked");
              await ref.read(AllControllers.onboardViewController.notifier).appleAuth();
              
                    },
                    boxBorder: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    margin: EdgeInsets.symmetric(horizontal: 20),
                    radius: BorderRadius.circular(50),
                    backgroundColor: Colors.black,
                    
                    
                    size:Size(double.infinity, 50.h),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        SvgPicture.asset("assets/apple.svg",color: Colors.white,width: 22.w,),
                       SizedBox(width: 10.w,),
                          Text("Apple",style: GoogleFonts.quicksand(color: Colors.white,fontSize: 16.sp,fontWeight: FontWeight.w600),),
                            SizedBox.shrink(),
                        
                      
                        ],
                      ),
                    ),
                  ),
          
                     SizedBox(height: 20.h,),
          
                      MyButton(
                    onTap: ()async{
                await ref.read(AllControllers.onboardViewController.notifier).googleAuth();
                    },
                    margin: EdgeInsets.symmetric(horizontal: 20),
                    radius: BorderRadius.circular(50),
                    backgroundColor: Colors.white,
                    
                    size:Size(double.infinity, 50.h),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                     
                        children: [
                        Image.asset("assets/google.png",width: 22.w,),
                        SizedBox(width: 10.w,),
                       
                          Text("Google",style: GoogleFonts.quicksand(color: Colors.black,fontSize: 16.sp,fontWeight: FontWeight.w600),),
                       
                        
                      
                        ],
                      ),
                    ),
                  ),
          
          
          
                
          
              
          
            // Misafir giriş butonu
                   MyButton(
                    onTap: () async {
                      debugPrint("👤 Guest button clicked");
                      await ref.read(AllControllers.onboardViewController.notifier).guestLogin();
                    },
                    margin: EdgeInsets.symmetric(horizontal: 20).copyWith(bottom: 20),
                    radius: BorderRadius.circular(50),
                    backgroundColor: Colors.transparent,
                    size: Size(250.w, 45.h),
                    child: Center(
                      child: Text(
                        Translate.translate("continue_as_guest", context),
                        style: GoogleFonts.quicksand(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
            
            ],
          
          
          
            if(Platform.isAndroid)...[
          
                   MyButton(
                    onTap: (){
          
          
          
                      ref.read(AllControllers.onboardViewController.notifier).googleAuth();
                    },
                    margin: EdgeInsets.symmetric(horizontal: 20),
                    radius: BorderRadius.circular(50),
                    backgroundColor: Colors.white,
                    size:Size(MediaQuery.sizeOf(context).width, 50.h),
                    child: Center(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        Image.asset("assets/google.png",width: 30.w,),
                          SizedBox(width: 10.h,),
                          Text(Translate.translate("continue_with_google", context),style: GoogleFonts.quicksand(color: Colors.black,fontSize: 14.sp,fontWeight: FontWeight.w500),),
                         
                        
          
                        ],
                      ),
                    ),
                  ),
                        SizedBox(height: 20.h,),
          
                      MyButton(
                    onTap: () async {
                      debugPrint("👤 Guest button clicked");
                      await ref.read(AllControllers.onboardViewController.notifier).guestLogin();
                    },
                    margin: EdgeInsets.symmetric(horizontal: 20).copyWith(bottom: 20),
                    radius: BorderRadius.circular(50),
                    backgroundColor: Colors.transparent,
                    size: Size(500.w, 45.h),
                    child: Center(
                      child: Text(
                        Translate.translate("continue_as_guest", context),
                        style: GoogleFonts.quicksand(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
          
          
          
                   SizedBox(height: 5.h,),
          
          
              socialAuthAreaAndroid()
            ],
          
          
           GestureDetector(
              onTap: () async{
               await launchUrl(Uri.parse("https://fly-work.com/friendify/terms/"));
              },
              child: SubstringHighlight(
              text: Translate.translate("terms_signup_text", context),
              term: Translate.translate("terms_signup_highlight", context),
              textAlign: TextAlign.center,
              textStyle: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.w400,fontSize: 12.sp),
              textStyleHighlight: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.w600,decoration: TextDecoration.underline,fontSize: 12.sp),
            ),
            ),
          
          
            
            GestureDetector(
                  onTap: () async{
              await  launchUrl(Uri.parse("https://fly-work.com/friendify/privacy-policy/"));
              },
              child: SubstringHighlight(
              text: Translate.translate("privacy_data_text", context),
              term: Translate.translate("privacy_data_highlight", context),
              textAlign: TextAlign.center,
              textStyle: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.w400,fontSize: 12.sp),
              textStyleHighlight: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.w600,decoration: TextDecoration.underline,fontSize: 12.sp),
                    ),
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




  Widget socialAuthAreaAndroid(){
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        /*
        socialButton(onTap: (){}, child: Center(child: Image.asset("assets/google.png",width: 20.w,),), backgroundColor: Colors.white),
        SizedBox(width: 15.w,),
        */
        socialButton(onTap: () async{
          debugPrint("🔵 Facebook button clicked");
         
           await ref.read(AllControllers.onboardViewController.notifier).facebookAuth();
          
          debugPrint("🔵 Facebook auth completed");
        }, child: Center(child: SvgPicture.asset("assets/facebook.svg"),), backgroundColor: Color(0xff1877F2)),
        SizedBox(width: 15.w,),
        socialButton(onTap: () async{
          debugPrint("🍎 Apple button clicked");
          await ref.read(AllControllers.onboardViewController.notifier).appleAuth();
          debugPrint("🍎 Apple auth completed");
        }, child: Center(child: SvgPicture.asset("assets/apple.svg",color: Colors.white,width: 18.w,),), backgroundColor: Colors.black)
      ],
    );
  }



  Widget socialAuthAreaIOS(){
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        
        socialButton(onTap: (){}, child: Center(child: Image.asset("assets/google.png",width: 20.w,),), backgroundColor: Colors.white),
        SizedBox(width: 15.w,),
        /*
        socialButton(onTap: () async{
          debugPrint("🔵 Facebook button clicked");
         
           await ref.read(AllControllers.onboardViewController.notifier).facebookAuth();
          
          debugPrint("🔵 Facebook auth completed");
        }, child: Center(child: SvgPicture.asset("assets/facebook.svg"),), backgroundColor: Color(0xff1877F2)),
        */
        SizedBox(width: 15.w,),
        socialButton(onTap: () async{
    ref.read(AllControllers.onboardViewController.notifier).googleAuth();
        }, child: Center(child: Image.asset("assets/google.png",width: 24.w,),), backgroundColor: Colors.white)
      ],
    );
  }



Widget socialButton({required Function() onTap,required Widget child,required Color backgroundColor}){
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 45.w,
      height: 45.h,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Center(
        child: child,
      ),
    ),
  );
}


}