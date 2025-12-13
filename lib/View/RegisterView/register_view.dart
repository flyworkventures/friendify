import 'package:cross_fade/cross_fade.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_holo_date_picker/date_picker_theme.dart';
import 'package:flutter_holo_date_picker/widget/date_picker_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Themes/colors.dart';
import 'package:friendfy/Widgets/button.dart';
import 'package:friendfy/Widgets/smooth_slide.dart';
import 'package:friendfy/Widgets/textfield.dart';
import 'package:google_fonts/google_fonts.dart';

class RegisterView extends ConsumerStatefulWidget {
  const RegisterView({super.key});

  @override
  ConsumerState<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends ConsumerState<RegisterView> {
  List<String> get hobbies => [
    TranslateKeys.travel,
    TranslateKeys.gaming,
    TranslateKeys.cooking,
    TranslateKeys.hiking,
    TranslateKeys.photography,
    TranslateKeys.movies,
    TranslateKeys.yoga,
    TranslateKeys.pets,
    TranslateKeys.music,
    TranslateKeys.painting,
    
    TranslateKeys.fitness,
    TranslateKeys.reading
  ];



  List<String> tags = [];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CrossFade(value: ref.watch(AllControllers.registerViewController).currentIndex, builder: (context,index)=> Image.asset(ref.read(AllControllers.registerViewController.notifier).imagePaths[index],width: MediaQuery.sizeOf(context).width,height: MediaQuery.sizeOf(context).height,fit: BoxFit.cover,),),
          
           bottom()
        ],
      ),
    );
  }


  Widget bottom(){
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: EdgeInsets.only(top: 30,bottom: 15),
        width: MediaQuery.sizeOf(context).width,
        height: MediaQuery.sizeOf(context).height / 1.6,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xffAB10E2),Color(0xff3330FE).withValues(alpha: 0.0)],end: Alignment.topCenter,begin: Alignment.bottomCenter),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(40),topRight: Radius.circular(40))
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                   Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                   GestureDetector(
                    onTap: () {
                      ref.read(AllControllers.registerViewController.notifier).previousPage();
                    },
                    child: Container(
                    margin: EdgeInsets.only(left: 10),
                    width: 35.w,
                    height: 35.h,
                                 decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.4),borderRadius: BorderRadius.circular(50)),
                                 child: Center(
                                  child: Icon(CupertinoIcons.back,color: Colors.white,size: 20,),
                                   ),
                                 ),
                               ),
            
                  Expanded(child: asamalar()),
            
            ],
                   ),
             
                SizedBox(height: 20.h,),
               Expanded(
                flex: 1,
                 child: Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 13),
                   child: PageView(
                    controller: ref.read(AllControllers.registerViewController.notifier).pageController,
                    physics: NeverScrollableScrollPhysics(),
                    children: [
                   
                   
                      SingleChildScrollView(
                   
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                                SmoothSlide(
                      child: Text(Translate.translate(TranslateKeys.tellAboutYourself, context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 26.sp,fontWeight: FontWeight.bold,),textAlign: TextAlign.center,)
                      ),
                           SmoothSlide(
                      child: Text(Translate.translate(TranslateKeys.bioHelps, context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 14.sp,fontWeight: FontWeight.w400,),textAlign: TextAlign.center,)
                      ),
                      SizedBox(height: 20.h,),
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Text(Translate.translate(TranslateKeys.fullName, context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 16.sp,fontWeight: FontWeight.w600,)),
                      ),
                       SizedBox(height: 10.h,),
             
                      MyTextField(
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.2),
                        textStyle: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.bold),
                        hintText: Translate.translate(TranslateKeys.enterYourFullname, context),
                        hintStyle: GoogleFonts.quicksand(color: Colors.white),
                        border: OutlineInputBorder(borderSide: BorderSide.none,borderRadius: BorderRadius.circular(50)),
                        controller: ref.read(AllControllers.registerViewController.notifier).usernameController),
            
                      SizedBox(height: 15.h,),
                      // Gender selection
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Text(Translate.translate(TranslateKeys.selectGender, context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 16.sp,fontWeight: FontWeight.w600,)),
                      ),
                      SizedBox(height: 8.h,),
                      // Erkek ve Kadın yan yana
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: 6.w),
                              child: genderButton(Translate.translate(TranslateKeys.male, context), "male", "assets/male.svg"),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: 6.w),
                              child: genderButton(Translate.translate(TranslateKeys.female, context), "female", "assets/female.svg"),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h,),
                      // Belirtmeyi Tercih Etmiyorum aşağıda tek başına
                      genderButton(Translate.translate(TranslateKeys.preferNotToSay, context), null, null),
            
                                         SizedBox(height: 20.h,),
                        ],
                        ),
                      ),
                   
                   
                      SingleChildScrollView(
                        child: Column(
                        children: [
                                SmoothSlide(
                      child: Text(Translate.translate(TranslateKeys.whatsYourBirthdate, context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 26.sp,fontWeight: FontWeight.bold,),textAlign: TextAlign.center,)
                      ),
                           SmoothSlide(
                      child: Text(Translate.translate(TranslateKeys.birthdayNote, context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 14.sp,fontWeight: FontWeight.w400,),textAlign: TextAlign.center,)
                      ),
                      SizedBox(height: 10.h,),
                      DatePickerWidget(
                        dateFormat: "dd/MMMM/yyyy",
                        lastDate: DateTime(2017),
                        firstDate: DateTime(1950),
                        initialDate: DateTime(2001,01,01),
                        onChange: (dateTime, selectedIndex) {
                          ref.read(AllControllers.registerViewController.notifier).updateBirthdate(dateTime);
                        },
                        pickerTheme: DateTimePickerTheme(
                          backgroundColor: Colors.transparent,
                          dividerColor: Colors.white,
                          
                          itemTextStyle: GoogleFonts.quicksand(color: Colors.white)
                        ),
                      )
                        ],
                        ),
                      ),
                   
                   
                      SingleChildScrollView(
                        child: Column(
                        children: [
                                SmoothSlide(
                      child: Text(Translate.translate(TranslateKeys.shareInterests, context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 26.sp,fontWeight: FontWeight.bold,),textAlign: TextAlign.center,)
                      ),
                           SmoothSlide(
                      child: Text(Translate.translate(TranslateKeys.shareExcitement, context),style: GoogleFonts.quicksand(color: Colors.white,fontSize: 14.sp,fontWeight: FontWeight.w400,),textAlign: TextAlign.center,)
                      ),
                      SizedBox(height: 20.h,),
                       
            
                      SizedBox(
                        width: MediaQuery.sizeOf(context).width,
                  
                        child: SingleChildScrollView(
                          child: Wrap(
                        spacing: 10,
                            runSpacing: 10,
                            children: hobbies.map((hobby) {
                              final isSelected = tags.contains(hobby);
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      tags.remove(hobby);
                                    } else {
                                      tags.add(hobby);
                                    }
                                    debugPrint("Selected tags: $tags");
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(isSelected ? 0.3 : 0.2),
                            borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: isSelected ? Colors.white : Colors.transparent,
                                      width: isSelected ? 1 : 0,
                                    ),
                                  ),
                                  child: Text(
                                    Translate.translate(hobby, context),
                                    style: GoogleFonts.quicksand(
            color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                  ),
                ),
              );
                            }).toList(),
                          ),
                          ),
                      )
                         
                        ],
                        ),
                      ),
                   
                   
                   
                   
                    ],
                   ),
                 ),
               ),
            

MyButton(
                  onTap: () async {
                    final currentIndex = ref.read(AllControllers.registerViewController).currentIndex;
                    
                    // İlgi alanları sayfasındaysak, seçilen hobbies'i kaydet ve kullanıcıyı oluştur
                    if (currentIndex == 2) {
                      ref.read(AllControllers.registerViewController.notifier).updateHobbies(tags);
                      // Son sayfada, kullanıcıyı oluştur
                      await ref.read(AllControllers.registerViewController.notifier).createUser();
                    } else {
                      // Diğer sayfalarda normal navigasyon
                    ref.read(AllControllers.registerViewController.notifier).pushBirthdayPage();
                    }
                  },
                  size: Size(200.w, 50.h),
                  backgroundColor: Colors.white.withValues(alpha: 0.4),
                  radius: BorderRadius.circular(50),
                  child: Center(child: Text(Translate.translate(TranslateKeys.next, context),style: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.w800,fontSize: 15.sp),)),
                 ),
              ],
            ),



          ],
        ),
      ),
    );
  }


  Widget hobbieWidget(String hobbie){
    return Container(
      height: 30.h,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(50)
      ),
      padding: EdgeInsets.symmetric(horizontal: 10,vertical: 3),
      child: Center(child: Text(hobbie,style: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.w500,fontSize: 14.sp),)),
    );
  }

Widget asamalar(){
  return  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 15),
    child: Row(
      children: [
        Expanded(
          child: Container(
            margin: EdgeInsets.only(right: 5),
                  width: MediaQuery.sizeOf(context).width,
                  height: 2,
                  
                  decoration: BoxDecoration(
                   color: ref.watch(AllControllers.registerViewController).currentIndex > 0 ? MyColors.purple : Colors.white,
                   borderRadius: BorderRadius.circular(10) 
                  ),
                ),
        ),
              
              
                    Expanded(
                      child: Container(
                         margin: EdgeInsets.only(right: 5),
                                    width: MediaQuery.sizeOf(context).width,
                                    height: 2,
                                    
                                    decoration: BoxDecoration(
                                     color: ref.watch(AllControllers.registerViewController).currentIndex > 1 ? MyColors.purple : Colors.white,
                                     borderRadius: BorderRadius.circular(10) 
                                    ),
                                  ),
                    ),
                    Expanded(
                      child: Container(
                         margin: EdgeInsets.only(right: 5),
                                    width: MediaQuery.sizeOf(context).width,
                                    height: 2,
                                    
                                    decoration: BoxDecoration(
                                     color: ref.watch(AllControllers.registerViewController).currentIndex > 2 ? MyColors.purple : Colors.white,
                                     borderRadius: BorderRadius.circular(10) 
                                    ),
                                  ),
                    ),
      ],
    ),
  );
}

Widget genderButton(String label, String? genderValue, String? iconPath) {
  return Consumer(
    builder: (context, ref, child) {
      final selectedGender = ref.watch(AllControllers.registerViewController).gender;
      final isSelected = selectedGender == genderValue;
      
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Sadece gender'ı güncelle, başka bir işlem yapma
            ref.read(AllControllers.registerViewController.notifier).updateGender(genderValue);
          },
          borderRadius: BorderRadius.circular(30),
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 20.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(isSelected ? 0.3 : 0.2),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: isSelected ? 2 : 0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
         
           if (iconPath == null) ...[
                  // Icon yoksa da Row'u dengede tutmak için
                  SizedBox(),
                  
                ],


                Center(
                  child:    Text(
                  label,
                  style: GoogleFonts.quicksand(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                ),
            
                if (iconPath != null) ...[
                  SizedBox(width: 8.w),
                  SvgPicture.asset(
                    iconPath,
                    width: 24.w,
                    height: 24.h,
                  ),
                ] else ...[
                  // Icon yoksa da Row'u dengede tutmak için
                  SizedBox(),
                  
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

}