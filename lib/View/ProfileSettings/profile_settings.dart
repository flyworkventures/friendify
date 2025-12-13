import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Themes/colors.dart';
import 'package:friendfy/Widgets/button.dart';
import 'package:friendfy/Widgets/textfield.dart';
import 'package:friendfy/main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:shimmer/shimmer.dart';

class ProfileSettings extends ConsumerStatefulWidget {
  const ProfileSettings({super.key});

  @override
  ConsumerState<ProfileSettings> createState() => _ProfileSettingsState();
}

class _ProfileSettingsState extends ConsumerState<ProfileSettings> {

  @override
  void initState() {
    Future.microtask(()=> ref.read(AllControllers.profileSettingsViewController.notifier).init());
    super.initState();
  }
  @override
  void didChangeDependencies() {

    super.didChangeDependencies();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(onPressed: ()=> navigatorKey.currentState?.pop(), icon: Icon(CupertinoIcons.back,color: Colors.white,)),
        centerTitle: false,
        title: Text(Translate.translate("profile_settings", context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 17.sp,fontWeight: FontWeight.w800),),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              top(),
              SizedBox(height: 20.h,),
          Padding(
            padding:  EdgeInsets.symmetric(horizontal: 40.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                    Text(Translate.translate("basic_details", context),style: GoogleFonts.quicksand(color: Colors.black,fontWeight: FontWeight.w800,fontSize: 16.sp),),
                    SizedBox(height: 10.h,),
                    textField(controller: ref.read(AllControllers.profileSettingsViewController.notifier).nameController, hintText: Translate.translate("full_name", context), title: Translate.translate("full_name", context),enabled: true,onChanged: (val) => ref.read(AllControllers.profileSettingsViewController.notifier).nameChanged(val),),
                    SizedBox(height: 10.h,),
                    if(ref.watch(AllControllers.userController)?.email.contains('@privaterelay.appleid.com') == false)...[
                          textField(controller: ref.read(AllControllers.profileSettingsViewController.notifier).emailController, hintText: Translate.translate("email", context), title: Translate.translate("email", context),enabled: false,onChanged: (val) {
                       
                     },)
                    ]
                 
              ],
            ),
          )
            ],
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsetsGeometry.symmetric(horizontal: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    MyButton(
                      onTap: () {
                        if (ref.read(AllControllers.profileSettingsViewController).nameChanged == true) {
                          ref.read(AllControllers.profileSettingsViewController.notifier).updateProfile();
                        }
                      },
                      radius: BorderRadius.circular(50.r),
                      size: Size(MediaQuery.sizeOf(context).width, 50.h),
                      backgroundColor: MyColors.purple.withValues(alpha: ref.watch(AllControllers.profileSettingsViewController).nameChanged == true ? 1 : 0.4),
                      child: ref.watch(AllControllers.profileSettingsViewController).isLoading == true
                          ? Center(
                            child: SizedBox(
                                width: 20.w,
                                height: 20.h,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                          )
                          : Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  HeroIcon(HeroIcons.bookmark,color: Colors.white,),
                                  SizedBox(width: 10.w,),
                                  Text(Translate.translate("save", context),style: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.w600,fontSize: 14.sp),)
                                ],
                              ),
                            ),
                    ),

                    SizedBox(height: 10.h,),
                    MyButton(
                      onTap: () => _showLogoutDialog(context),
                      radius: BorderRadius.circular(50.r),
                      size: Size(MediaQuery.sizeOf(context).width, 50.h),
                      backgroundColor: Colors.white,
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            HeroIcon(HeroIcons.arrowLeftEndOnRectangle,color: Colors.red,),
                            SizedBox(width: 10.w,),
                            Text(Translate.translate("sign_out", context),style: GoogleFonts.quicksand(color: Colors.red,fontWeight: FontWeight.w600,fontSize: 14.sp),)
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 10.h,),
                    MyButton(
                      onTap: () => _showDeleteAccountDialog(context),
                      radius: BorderRadius.circular(50.r),
                      size: Size(MediaQuery.sizeOf(context).width, 50.h),
                      backgroundColor: Colors.red,
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            HeroIcon(HeroIcons.trash,color: Colors.white,),
                            SizedBox(width: 10.w,),
                            Text(Translate.translate("delete_account", context),style: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.w600,fontSize: 14.sp),)
                          ],
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }


textField({required TextEditingController controller,required String hintText,required String title,required bool enabled,required Function(String) onChanged}){
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
       Text(title,style: GoogleFonts.quicksand(color: Colors.black,fontWeight: FontWeight.w600,fontSize: 13.sp),),
       MyTextField(
        controller: controller,
        hintText: hintText,
        onChanged: (val)=> onChanged(val),
        enabled: enabled,)
    ],
  );
}


  Widget top(){
    final selectedImagePath = ref.watch(AllControllers.profileSettingsViewController).selectedImagePath;
    final photoURL = ref.watch(AllControllers.profileSettingsViewController).photoURL;
    
    return Stack(
     children: [
       Container(
         height: 250.h,
         width: MediaQuery.sizeOf(context).width,
        child: Stack(
         children: [
           Align(
             alignment: Alignment.topCenter,
             child: Container(
               width: MediaQuery.sizeOf(context).width,
               height: 190.h,
               decoration: BoxDecoration(
                 gradient: LinearGradient(colors: [Color(0xffA213E4),Color(0xff2D30FF)],begin: Alignment.topLeft,end: Alignment.bottomRight),
             
               ),
             ),
           ),
           Align(
             alignment: Alignment.bottomCenter,
             child: Column(
               mainAxisAlignment: MainAxisAlignment.end,
               children: [
                 Stack(
                   children: [
                     ClipOval(
                       child: Container(
                         width: 125.w,
                         height: 125.h,
                         child: selectedImagePath != null
                             ? Image.file(
                                 File(selectedImagePath),
                                 fit: BoxFit.cover,
                               )
                             : CachedNetworkImage(
                                 imageUrl: photoURL ?? "https://fakefriend.b-cdn.net/profile.png",
                                 fit: BoxFit.cover,
                                 placeholder: (context, url) => Shimmer.fromColors(
                                   baseColor: Colors.grey[300]!,
                                   highlightColor: Colors.grey[100]!,
                                   child: Container(
                                     color: Colors.white,
                                   ),
                                 ),
                                 errorWidget: (context, url, error) => Container(
                                   color: Colors.grey[300],
                                   child: Icon(Icons.person, size: 60),
                                 ),
                               ),
                       ),
                     ),
                     Positioned(
                       bottom: 0,
                       right: 0,
                       child: GestureDetector(
                         onTap: () {
                           ref.read(AllControllers.profileSettingsViewController.notifier).pickImage();
                         },
                         child: Container(
                           width: 40.w,
                           height: 40.h,
                           decoration: BoxDecoration(
                             color: MyColors.purple,
                             shape: BoxShape.circle,
                             border: Border.all(color: Colors.white, width: 3),
                           ),
                           child: Icon(
                             Icons.camera_alt,
                             color: Colors.white,
                             size: 20.sp,
                           ),
                         ),
                       ),
                     ),
                   ],
                 ),
               
           
               ],
             ),
             )
         ],
        ),
       ),
       
     ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          title: Text(
            Translate.translate("logout_dialog_title", context),
            style: GoogleFonts.quicksand(
              fontWeight: FontWeight.w700,
              fontSize: 18.sp,
            ),
          ),
          content: Text(
            Translate.translate("logout_dialog_content", context),
            style: GoogleFonts.quicksand(
              fontSize: 14.sp,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                Translate.translate("cancel", context),
                style: GoogleFonts.quicksand(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ref.read(AllControllers.profileSettingsViewController.notifier).logout();
              },
              child: Text(
                Translate.translate("sign_out", context),
                style: GoogleFonts.quicksand(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          title: Text(
            Translate.translate("delete_account_dialog_title", context),
            style: GoogleFonts.quicksand(
              fontWeight: FontWeight.w700,
              fontSize: 18.sp,
              color: Colors.red,
            ),
          ),
          content: Text(
            Translate.translate("delete_account_dialog_content", context),
            style: GoogleFonts.quicksand(
              fontSize: 14.sp,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                Translate.translate("cancel", context),
                style: GoogleFonts.quicksand(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ref.read(AllControllers.profileSettingsViewController.notifier).deleteAccount();
              },
              child: Text(
                Translate.translate("delete_account", context),
                style: GoogleFonts.quicksand(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }




}