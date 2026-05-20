import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Themes/colors.dart';
import 'package:friendfy/Widgets/background.dart';
import 'package:friendfy/Widgets/button.dart';
import 'package:friendfy/Widgets/future_progress_dialog.dart';
import 'package:friendfy/Widgets/textfield.dart';
import 'package:friendfy/main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_holo_date_picker/widget/date_picker_widget.dart';
import 'package:flutter_holo_date_picker/date_picker_theme.dart';

class ProfileSettings extends ConsumerStatefulWidget {
  const ProfileSettings({super.key});

  @override
  ConsumerState<ProfileSettings> createState() => _ProfileSettingsState();
}

class _ProfileSettingsState extends ConsumerState<ProfileSettings> {
  @override
  void initState() {
    Future.microtask(
      () => ref
          .read(AllControllers.profileSettingsViewController.notifier)
          .init(),
    );
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(
      AllControllers.profileSettingsViewController,
    );
    final user = ref.watch(AllControllers.userController);
    final selectedBirthdate = profileState.birthdate ?? user?.birthdate;

    return BackgroundWidget(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            onPressed: () => navigatorKey.currentState?.pop(),
            icon: Icon(CupertinoIcons.back, color: Colors.white),
          ),
          centerTitle: true,
          title: Text(
            Translate.translate("profile_settings", context),
            style: GoogleFonts.quicksand(
              color: Colors.white,
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                top(),
                SizedBox(height: 20.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 10.h),
                      textField(
                        controller: ref
                            .read(
                              AllControllers
                                  .profileSettingsViewController
                                  .notifier,
                            )
                            .nameController,
                        hintText: Translate.translate("full_name", context),
                        title: Translate.translate("full_name", context),
                        enabled: true,
                        maxLength: 20,
                        onChanged: (val) => ref
                            .read(
                              AllControllers
                                  .profileSettingsViewController
                                  .notifier,
                            )
                            .nameChanged(val),
                      ),
                      SizedBox(height: 10.h),
                      //   if(ref.watch(AllControllers.userController)?.email.contains('@privaterelay.appleid.com') == false)...[
                      Text(
                        Translate.translate("gender", context),
                        style: GoogleFonts.quicksand(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.sp,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      _buildGenderSegmentedControl(context),
                      SizedBox(height: 14.h),
                      _ProfileBirthdateSection(
                        title: Translate.translate(
                          TranslateKeys.birthdate,
                          context,
                        ),
                        existingBirthdate: selectedBirthdate,
                        onDateChanged: (d) {
                          ref
                              .read(
                                AllControllers
                                    .profileSettingsViewController
                                    .notifier,
                              )
                              .birthdateChanged(d);
                        },
                      ),

                      //],
                    ],
                  ),
                ),
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
                      /*
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
      */
                      SizedBox(height: 10.h),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: MyButton(
                          onTap: () => _showDeleteAccountBottomSheet(context),
                          radius: BorderRadius.circular(50.r),
                          margin: EdgeInsets.symmetric(horizontal: 10.r),
                          size: Size(MediaQuery.sizeOf(context).width, 50.h),
                          backgroundColor: Colors.transparent,
                          child: Padding(
                            padding: EdgeInsets.only(left: 17.r),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 30.w,
                                  height: 30.h,
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(10).r,
                                  ),
                                  child:Center(child: SvgPicture.asset("assets/icons/trash.svg",width: 20.w,height: 20.h,colorFilter: ColorFilter.mode(Colors.red, BlendMode.srcIn),),),
                                  
                                ),
                                SizedBox(width: 10.w),
                                Text(
                                  Translate.translate(
                                    "delete_account",
                                    context,
                                  ),
                                  style: GoogleFonts.quicksand(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 10.h),

                      MyGradientButton(
                        onTap: () {
                          if (ref
                                  .read(
                                    AllControllers
                                        .profileSettingsViewController,
                                  )
                                  .nameChanged ==
                              true) {
                            ref
                                .read(
                                  AllControllers
                                      .profileSettingsViewController
                                      .notifier,
                                )
                                .updateProfile();
                          }
                        },
                        margin: EdgeInsets.symmetric(horizontal: 10.r),
                        radius: BorderRadius.circular(50.r),
                        size: Size(MediaQuery.sizeOf(context).width, 50.h),
                        //  backgroundColor: MyColors.purple.withValues(alpha: ref.watch(AllControllers.profileSettingsViewController).nameChanged == true ? 1 : 0.4),
                        child:
                            ref
                                    .watch(
                                      AllControllers
                                          .profileSettingsViewController,
                                    )
                                    .isLoading ==
                                true
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 20.h,
                                      child: HeroIcon(
                                        HeroIcons.sparkles,
                                        style: HeroIconStyle.solid,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Text(
                                      Translate.translate("save", context),
                                      style: GoogleFonts.quicksand(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 20.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  textField({
    required TextEditingController controller,
    required String hintText,
    required String title,
    required bool enabled,
    int? maxLength,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.quicksand(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13.sp,
          ),
        ),
        SizedBox(height: 10.h),
        MyTextField(
          contentPadding: EdgeInsets.only(left: 15, right: 15),
          controller: controller,
          maxLength: maxLength,
          height: 40.h,
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(10).r,
          ),
          hintText: hintText,
          hintStyle: GoogleFonts.quicksand(color: Colors.white),
          textStyle: GoogleFonts.quicksand(
            color: Colors.white,
            fontSize: 14.sp,
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.2),
          onChanged: (val) => onChanged(val),
          enabled: enabled,
        ),
      ],
    );
  }

  Widget _buildGenderSegmentedControl(BuildContext context) {
    const unselectedTint = Color(0xFFB8B8C0);
    final userGender = ref.watch(AllControllers.userController)?.gender;
    final profileState = ref.watch(
      AllControllers.profileSettingsViewController,
    );
    final selectedGender = profileState.genderChanged == true
        ? profileState.gender
        : userGender;

    Widget segment({
      required String label,
      required String? value,
      required bool selected,
      required Widget leading,
    }) {
     return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  ref
                      .read(
                        AllControllers.profileSettingsViewController.notifier,
                      )
                      .genderChanged(value);
                },
              
                borderRadius: BorderRadius.circular(12.r),
                splashColor: Colors.white.withValues(alpha: 0.08),
                highlightColor: Colors.white.withValues(alpha: 0.04),
                child: AnimatedContainer(
                  height: 34.h,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
               
                    horizontal: 4.w,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? MyColors.purple : Colors.transparent,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      leading,
                      SizedBox(width: 6.w),
                       Text(
                          label,
                          style: GoogleFonts.quicksand(
                            color: selected ? Colors.white : unselectedTint,
                            fontSize: 14.sp,
                            fontWeight:  FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      
                    ],
                  ),
                ),
              ),
            ),
          );
    }

    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          segment(
            label: Translate.translate(TranslateKeys.male, context),
            value: 'male',
            selected: selectedGender == 'male',
            leading: SvgPicture.asset(
              'assets/male.svg',
      
              height: 16.w,
              colorFilter: ColorFilter.mode(
                selectedGender == 'male' ? Colors.white : unselectedTint,
                BlendMode.srcIn,
              ),
            ),
          ),
          SizedBox(width: 4.w),
          segment(
            label: Translate.translate(TranslateKeys.female, context),
            value: 'female',
            selected: selectedGender == 'female',
            leading: SvgPicture.asset(
              'assets/female.svg',
  
              height: 16.w,
              colorFilter: ColorFilter.mode(
                selectedGender == 'female' ? Colors.white : unselectedTint,
                BlendMode.srcIn,
              ),
            ),
          ),
          SizedBox(width: 4.w),
          segment(
            label: Translate.translate(TranslateKeys.genderPrivate, context),
            value: null,
            selected: selectedGender == null,
            leading: SvgPicture.asset(
              'assets/close.svg',
              width: 16.w,
              height: 16.w,
              colorFilter: ColorFilter.mode(
                selectedGender == null ? Colors.white : unselectedTint,
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget top() {
    final selectedImagePath = ref
        .watch(AllControllers.profileSettingsViewController)
        .selectedImagePath;
    final photoURL = ref
        .watch(AllControllers.profileSettingsViewController)
        .photoURL;

    return Stack(
      children: [
        Container(
          height: 230.h,
          width: MediaQuery.sizeOf(context).width,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Stack(
                      children: [
                        ClipOval(
                          child: Container(
                            width: 100.w,
                            height: 100.w,
                            child: selectedImagePath != null
                                ? Image.file(
                                    File(selectedImagePath),
                                    width: 100.w,
                                    height: 100.w,
                                    fit: BoxFit.cover,
                                  )
                                : CachedNetworkImage(
                                    width: 100.w,
                                    height: 100.w,
                                    imageUrl:
                                        photoURL ??
                                        "https://fakefriend.b-cdn.net/app/Group%201174.png",
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        Shimmer.fromColors(
                                          baseColor: Colors.grey[300]!,
                                          highlightColor: Colors.grey[100]!,
                                          child: Container(color: Colors.white),
                                        ),
                                    errorWidget: (context, url, error) =>
                                        Container(
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
                              ref
                                  .read(
                                    AllControllers
                                        .profileSettingsViewController
                                        .notifier,
                                  )
                                  .pickImage();
                            },
                            child: SvgPicture.asset("assets/pen.svg")
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
            style: GoogleFonts.quicksand(fontSize: 14.sp),
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
                context.runWithProgressDialog(
                  () => ref
                      .read(AllControllers.profileSettingsViewController.notifier)
                      .logout(),
                );
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

  /// Kullanıcı bilgileri bölümü
  Widget _buildUserInfoSection() {
    final user = ref.watch(AllControllers.userController);
    if (user == null) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /*
        // Oturum Açma Yöntemi
        if (user.credential != null && user.credential != "guest") ...[
          _buildInfoField(
            title: Translate.translate(TranslateKeys.loginMethod, context),
            valueWidget: _buildLoginMethod(user.credential.toString()),
          ),
          SizedBox(height: 10.h),
        ],
        
        */
        // Doğum Tarihi
        _buildInfoField(
          title: Translate.translate(TranslateKeys.birthdate, context),
          value: _formatBirthdate(user.birthdate),
        ),

        // Cinsiyet Tercihi
        if (user.gender != null) ...[
          SizedBox(height: 10.h),
          _buildInfoField(
            title: Translate.translate(TranslateKeys.genderPreference, context),
            value: _formatGender(user.gender),
          ),
        ],
      ],
    );
  }

  /// Bilgi alanı widget'ı (mevcut textField tasarımına uygun)
  Widget _buildInfoField({
    required String title,
    String? value,
    Widget? valueWidget,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.quicksand(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 13.sp,
          ),
        ),
        SizedBox(height: 5.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child:
              valueWidget ??
              Text(
                value ?? '',
                style: GoogleFonts.quicksand(
                  color: Colors.black,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
        ),
      ],
    );
  }

  /// Oturum açma yöntemi widget'ı
  Widget _buildLoginMethod(String credential) {
    String methodText;
    Widget icon;

    switch (credential.toLowerCase()) {
      case 'google':
        methodText = Translate.translate(TranslateKeys.googleLogin, context);
        icon = Container(
          width: 24.w,
          height: 24.h,
          decoration: BoxDecoration(
            color: Color(0xFF4285F4),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              'G',
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        break;
      case 'apple':
        methodText = Translate.translate(TranslateKeys.appleLogin, context);
        icon = HeroIcon(
          HeroIcons.devicePhoneMobile,
          size: 24,
          color: Colors.black,
        );
        break;
      case 'facebook':
        methodText = Translate.translate(TranslateKeys.facebookLogin, context);
        icon = Container(
          width: 24.w,
          height: 24.h,
          decoration: BoxDecoration(
            color: Color(0xFF1877F2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              'f',
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        break;
      default:
        methodText = Translate.translate(TranslateKeys.emailLogin, context);
        icon = HeroIcon(HeroIcons.envelope, size: 24, color: MyColors.purple);
    }

    return Row(
      children: [
        icon,
        SizedBox(width: 12.w),
        Text(
          methodText,
          style: GoogleFonts.quicksand(
            color: Colors.black,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Doğum tarihini formatla
  String _formatBirthdate(DateTime birthdate) {
    return '${birthdate.day.toString().padLeft(2, '0')}.${birthdate.month.toString().padLeft(2, '0')}.${birthdate.year}';
  }

  /// Cinsiyet tercihini formatla
  String _formatGender(String? gender) {
    if (gender == null)
      return Translate.translate(TranslateKeys.preferNotToSay, context);

    switch (gender.toLowerCase()) {
      case 'male':
        return Translate.translate("male", context);
      case 'female':
        return Translate.translate("female", context);
      default:
        return Translate.translate(TranslateKeys.preferNotToSay, context);
    }
  }

  /// Doğum tarihi textfield'ı
  Widget _buildBirthdateTextField() {
    final controller = ref
        .read(AllControllers.profileSettingsViewController.notifier)
        .birthdateController;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Translate.translate(TranslateKeys.birthdate, context),
          style: GoogleFonts.quicksand(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 13.sp,
          ),
        ),
        SizedBox(height: 5.h),
        GestureDetector(
          onTap: () {
            _showBirthdatePicker(context);
          },
          child: MyTextField(
            margin: EdgeInsets.zero,
            contentPadding: EdgeInsets.symmetric(horizontal: 15),
            controller: controller,
            height: 40.h,
            textStyle: GoogleFonts.quicksand(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 13.sp,
            ),
            hintText: Translate.translate(TranslateKeys.birthdate, context),
            enabled: false,
            onChanged: (val) {},
          ),
        ),
      ],
    );
  }

  void _showBirthdatePicker(BuildContext context) {
    final user = ref.read(AllControllers.userController);
    final currentBirthdate = user?.birthdate ?? DateTime(2001, 1, 1);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20.r),
              topRight: Radius.circular(20.r),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      Translate.translate(TranslateKeys.birthdate, context),
                      style: GoogleFonts.quicksand(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                      },
                      child: Text(
                        Translate.translate("ok", context),
                        style: GoogleFonts.quicksand(
                          color: MyColors.purple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: DatePickerWidget(
                  dateFormat: "dd/MMMM/yyyy",
                  lastDate: DateTime(2017),
                  firstDate: DateTime(1950),
                  initialDate: currentBirthdate,
                  onChange: (dateTime, selectedIndex) {
                    ref
                        .read(
                          AllControllers.profileSettingsViewController.notifier,
                        )
                        .birthdateChanged(dateTime);
                  },
                  pickerTheme: DateTimePickerTheme(
                    backgroundColor: Colors.transparent,
                    dividerColor: Colors.grey[300]!,
                    itemTextStyle: GoogleFonts.quicksand(color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Cinsiyet dropdown'ı
  Widget _buildGenderTextField() {
    final user = ref.watch(AllControllers.userController);
    final profileState = ref.watch(
      AllControllers.profileSettingsViewController,
    );

    // Dropdown için seçenekler - null yerine "prefer_not_to_say" kullanıyoruz
    const String preferNotToSayValue = "prefer_not_to_say";
    final genderOptions = [
      {"value": "male", "label": Translate.translate("male", context)},
      {"value": "female", "label": Translate.translate("female", context)},
      {
        "value": preferNotToSayValue,
        "label": Translate.translate(TranslateKeys.preferNotToSay, context),
      },
    ];

    // State'teki gender değişikliğini öncelikli olarak kullan (henüz kaydedilmemiş değişiklikler için)
    // genderChanged true ise state'teki gender'ı kullan (null dahil), değilse user'dan al
    // ÖNEMLİ: profileState.gender null olabilir (belirtmeyi tercih etmiyorum seçildiğinde)
    String? currentGender;
    if (profileState.genderChanged == true) {
      // State'te explicit olarak null set edilmişse (belirtmeyi tercih etmiyorum), null kullan
      // null değeri de geçerli bir seçimdir!
      currentGender = profileState.gender;
    } else {
      // State'te değişiklik yoksa user'dan al
      currentGender = user?.gender;
    }

    // Mevcut seçili değeri bul - null ise "prefer_not_to_say" olarak göster
    // Bu, dropdown'ın gösterdiği değer
    String selectedValue = currentGender ?? preferNotToSayValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Translate.translate(TranslateKeys.genderPreference, context),
          style: GoogleFonts.quicksand(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 13.sp,
          ),
        ),
        SizedBox(height: 5.h),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30.r),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              borderRadius: BorderRadius.circular(20.r),
              value: selectedValue,
              isExpanded: true,
              icon: Icon(CupertinoIcons.chevron_down, color: Colors.black),
              style: GoogleFonts.quicksand(
                color: Colors.black,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
              padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 0.h),
              items: genderOptions.map((option) {
                return DropdownMenuItem<String>(
                  value: option["value"] as String,
                  child: Text(
                    option["label"]!,
                    style: GoogleFonts.quicksand(
                      color: Colors.black,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                // "prefer_not_to_say" değerini null'a çevir
                String? genderToSave = newValue == preferNotToSayValue
                    ? null
                    : newValue;
                ref
                    .read(AllControllers.profileSettingsViewController.notifier)
                    .genderChanged(genderToSave);
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showDeleteAccountBottomSheet(BuildContext context) {
    int step = -1;
    int? selectedReason;
    bool isSubmittingDelete = false;
    final noteController = TextEditingController();
    final reasons = <String>[
      Translate.translate(TranslateKeys.deleteFlowReason1, context),
      Translate.translate(TranslateKeys.deleteFlowReason2, context),
      Translate.translate(TranslateKeys.deleteFlowReason3, context),
      Translate.translate(TranslateKeys.deleteFlowReason4, context),
      Translate.translate(TranslateKeys.deleteFlowReason5, context),
      Translate.translate(TranslateKeys.deleteFlowReason6, context),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final maxHeight = MediaQuery.sizeOf(context).height * 0.76;
          final profileState = ref.watch(
            AllControllers.profileSettingsViewController,
          );
          final isDeleting =
              isSubmittingDelete || profileState.isLoading == true;

          Future<void> onNext() async {
            if (step == 0 && selectedReason == null) return;
            if (step == 3) {
              setModalState(() => isSubmittingDelete = true);
              Navigator.of(sheetContext).pop();
              await context.runWithProgressDialog(
                () => ref
                    .read(AllControllers.profileSettingsViewController.notifier)
                    .deleteAccount(),
              );
              return;
            }
            setModalState(() => step = step + 1);
          }

          return SafeArea(
            top: false,
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(22.r),
                topRight: Radius.circular(22.r),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  color: const Color(0xFF050505).withValues(alpha: 0.94),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 8.h),
                      Container(
                        width: 46.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.26),
                          borderRadius: BorderRadius.circular(100.r),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Flexible(
                        child: SingleChildScrollView(
                          child: _buildDeleteAccountStepContent(
                            step: step,
                            reasons: reasons,
                            selectedReason: selectedReason,
                            noteController: noteController,
                            sheetContext: sheetContext,
                            onMonthlyPlanTap: () async {
                              try {
                                final offerings = await Purchases.getOfferings();
                                final specialOffer = offerings.getOffering("special_offer");
                                if (specialOffer != null) {
                                  final result = await RevenueCatUI.presentPaywall(
                                    offering: specialOffer,
                                    displayCloseButton: true,
                                  );
                                  if (result == PaywallResult.purchased || result == PaywallResult.restored) {
                                    Navigator.of(sheetContext).pop();
                                  }
                                } else {
                                  final result = await RevenueCatUI.presentPaywall(
                                    displayCloseButton: true,
                                  );
                                  if (result == PaywallResult.purchased || result == PaywallResult.restored) {
                                    Navigator.of(sheetContext).pop();
                                  }
                                }
                              } catch (e) {
                                debugPrint("⚠️ Special offer paywall error: $e");
                              }
                            },
                            onSelectReason: (value) {
                              setModalState(() => selectedReason = value);
                            },
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(20, (step == 1 || step == 2) ? 10 : 20, 20, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48.h,
                                child: ElevatedButton(
                                  onPressed: isDeleting
                                      ? null
                                      : () {
                                          if (step == 3) {
                                            onNext();
                                            return;
                                          }
                                          if (step == -1) {
                                            Navigator.of(sheetContext).pop();
                                            return;
                                          }
                                          setModalState(() => step = step - 1);
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: (step == 1 || step == 2 || step == 3)
                                        ? Colors.white.withValues(alpha: 0.5)
                                        : (step == -1 || step == 0)
                                            ? const Color(0xFFCE64FF)
                                            : const Color(0xFF9B9B9B),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        999.r,
                                      ),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    step == 3
                                        ? Translate.translate(
                                            TranslateKeys.deleteFlowDone,
                                            context,
                                          )
                                        : (step == -1
                                              ? Translate.translate(
                                                  TranslateKeys.cancel,
                                                  context,
                                                )
                                              : Translate.translate(
                                                  TranslateKeys.back,
                                                  context,
                                                )),
                                    style: GoogleFonts.quicksand(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (step < 3) ...[
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Container(
                                  height: 48.h,
                                  decoration: BoxDecoration(
                                    color: (step == 1 || step == 2)
                                        ? Colors.white.withValues(alpha: 0.5)
                                        : const Color(0xFF9B9B9B),
                                    borderRadius: BorderRadius.circular(999.r),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: ((step == 0 &&
                                                selectedReason == null) ||
                                            isDeleting)
                                        ? null
                                        : onNext,
                                    style: ElevatedButton.styleFrom(
                                      shadowColor: Colors.transparent,
                                      backgroundColor: Colors.transparent,
                                      disabledBackgroundColor: (step == 1 || step == 2)
                                          ? Colors.white.withValues(alpha: 0.5)
                                          : const Color(0xFF9B9B9B),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          999.r,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      step == -1
                                          ? Translate.translate(
                                              TranslateKeys.delete,
                                              context,
                                            )
                                          : Translate.translate(
                                              TranslateKeys.next,
                                              context,
                                            ),
                                      style: GoogleFonts.quicksand(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ).whenComplete(noteController.dispose);
  }

  Widget _buildDeleteAccountStepContent({
    required int step,
    required List<String> reasons,
    required int? selectedReason,
    required TextEditingController noteController,
    required BuildContext sheetContext,
    Future<void> Function()? onMonthlyPlanTap,
    required ValueChanged<int> onSelectReason,
  }) {
    switch (step) {
      case -1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 12.h),
            Container(
              width: 54.w,
              height: 54.w,
              decoration: BoxDecoration(
                color: const Color(0xFF8F2320),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Center(
                child: SvgPicture.asset("assets/icons/trash.svg",width: 24.w,height: 24.h,),
              )
            ),
            SizedBox(height: 18.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 18.w),
              child: Text(
                Translate.translate(
                  TranslateKeys.deleteFlowPrimaryTitle,
                  context,
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.quicksand(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            SizedBox(height: 12.h),
          ],
        );
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 13).r,
              color: Colors.white.withValues(alpha: 0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    Translate.translate(
                      TranslateKeys.deleteFlowIntroTitle,
                      context,
                    ),
                    style: GoogleFonts.quicksand(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    Translate.translate(
                      TranslateKeys.deleteFlowIntroSubtitle,
                      context,
                    ),
                    style: GoogleFonts.quicksand(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < reasons.length; i++)
                    InkWell(
                      onTap: () => onSelectReason(i),
                      borderRadius: BorderRadius.circular(10.r),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        child: Row(
                          children: [
                            Icon(
                              Icons.radio_button_checked,

                              color: selectedReason == i
                                  ? MyColors.purple
                                  : const Color(0xFFD0D0D4),
                              size: 22.sp,
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                reasons[i],
                                style: GoogleFonts.quicksand(
                                  color: const Color(0xFFE8E8EB),
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(height: 10.h),
                  Text(
                    Translate.translate(
                      TranslateKeys.deleteFlowMessageOptional,
                      context,
                    ),
                    style: GoogleFonts.quicksand(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  TextField(
                    controller: noteController,
                    style: GoogleFonts.quicksand(color: Colors.white),
                    minLines: 2,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: Translate.translate(
                        TranslateKeys.deleteFlowMessageHint,
                        context,
                      ),
                      hintStyle: GoogleFonts.quicksand(
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF111216),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 12.h,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: MyColors.purple,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case 1:
        return _buildOfferStep(
          title: Translate.translate(TranslateKeys.deleteFlowOfferTitle, context),
          subtitle: Translate.translate(
            TranslateKeys.deleteFlowOfferSubtitle,
            context,
          ),
          planTitle: Translate.translate(
            TranslateKeys.deleteFlowOfferPlanTitle,
            context,
          ),
          planSubTitle: Translate.translate(
            TranslateKeys.deleteFlowOfferPlanSubtitle,
            context,
          ),
          planBody: Translate.translate(
            TranslateKeys.deleteFlowOfferPlanBody,
            context,
          ),
          ctaText: Translate.translate(TranslateKeys.deleteFlowOfferCta, context),
          onCtaTap: onMonthlyPlanTap,
        );
      case 2:
        return _buildOfferStep(
          title: Translate.translate(TranslateKeys.deleteFlowSureTitle, context),
          subtitle: Translate.translate(
            TranslateKeys.deleteFlowSureSubtitle,
            context,
          ),
          planTitle: Translate.translate(
            TranslateKeys.deleteFlowSurePlanTitle,
            context,
          ),
          planSubTitle: Translate.translate(
            TranslateKeys.deleteFlowSurePlanSubtitle,
            context,
          ),
          planBody: null,
          ctaText: Translate.translate(TranslateKeys.deleteFlowSureCta, context),
          isSixtyPercentOffer: true,
          onCtaTap: () async {
            try {
              final offerings = await Purchases.getOfferings();
              final specialOffer = offerings.getOffering("Special Offer");
              if (specialOffer != null) {
                final result = await RevenueCatUI.presentPaywall(
                  offering: specialOffer,
                  displayCloseButton: true,
                );
                if (result == PaywallResult.purchased || result == PaywallResult.restored) {
                  Navigator.of(sheetContext).pop();
                }
              } else {
                final result = await RevenueCatUI.presentPaywall(
                  displayCloseButton: true,
                );
                if (result == PaywallResult.purchased || result == PaywallResult.restored) {
                  Navigator.of(sheetContext).pop();
                }
              }
            } catch (e) {
              debugPrint("⚠️ Special offer paywall error: $e");
            }
          },
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 13).r,
              color: Colors.white.withValues(alpha: 0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    Translate.translate(
                      TranslateKeys.deleteFlowFinalTitle,
                      context,
                    ),
                    style: GoogleFonts.quicksand(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    Translate.translate(
                      TranslateKeys.deleteFlowFinalSubtitle,
                      context,
                    ),
                    style: GoogleFonts.quicksand(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        Translate.translate(
                          TranslateKeys.deleteFlowChangeMindTitle,
                          context,
                        ),
                        style: GoogleFonts.quicksand(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    Translate.translate(
                      TranslateKeys.deleteFlowChangeMindSubtitle,
                      context,
                    ),
                    style: GoogleFonts.quicksand(
                      color: Colors.white.withValues(alpha: 0.64),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  GestureDetector(
                    onTap: () => Navigator.of(sheetContext).pop(),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 12.h,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          SvgPicture.asset("assets/icons/chain.svg",width: 16.w,height: 16.h,),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              Translate.translate(
                                TranslateKeys.deleteFlowReactivateCta,
                                context,
                              ),
                              style: GoogleFonts.quicksand(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 18.sp,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }

  Widget _buildOfferStep({
    required String title,
    required String subtitle,
    required String planTitle,
    required String planSubTitle,
    required String? planBody,
    required String ctaText,
    Future<void> Function()? onCtaTap,
    bool isSixtyPercentOffer = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 15, vertical: 13).r,
          color: Colors.white.withValues(alpha: 0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: GoogleFonts.quicksand(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                subtitle,
                style: GoogleFonts.quicksand(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (!isSixtyPercentOffer) ...[
          SizedBox(height: 14.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52.w,
                      height: 52.w,
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xffD55EFF)),
                        color: Color(0xFFD55EFF).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Center(
                            child: Image.asset(
                              "assets/icons/king.png",
                              width: 30.w,
                            ),
                          ),
                          Positioned(
                            right: -4.w,
                            bottom: -4.h,
                            child: Container(
                              width: 20.w,
                              height: 20.w,
                              decoration: BoxDecoration(
                                color: const Color(0xFFB14CFF),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.1,
                                ),
                              ),
                              child: SvgPicture.asset("assets/icons/badge.svg")
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            planTitle,
                            style: GoogleFonts.quicksand(
                              color: Colors.white,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            planSubTitle,
                            style: GoogleFonts.quicksand(
                              color: Colors.white.withValues(alpha: 0.62),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (planBody != null) ...[
                  SizedBox(height: 10.h),
                  Text(
                    planBody,
                    style: GoogleFonts.quicksand(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 12.h),
        ] else
          SizedBox(height: 14.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 20.sp),
                  SizedBox(width: 8.w),
                  Text(
                    Translate.translate(
                      TranslateKeys.deleteFlowWhatKeep,
                      context,
                    ),
                    style: GoogleFonts.quicksand(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              if (isSixtyPercentOffer) ...[
                _buildLossItem(
                  Translate.translate(
                    TranslateKeys.deleteFlowLossCharacter,
                    context,
                  ),
                  "assets/icons/group.svg",
                ),
                _buildLossItem(
                  Translate.translate(TranslateKeys.deleteFlowLossVideo, context),
                  "assets/icons/vieo_call.svg",
                ),
                _buildLossItem(
                  Translate.translate(
                    TranslateKeys.deleteFlowLossEditing,
                    context,
                  ),
                  "assets/icons/useredit.svg",
                ),
              ] else ...[
                _buildKeepItem(
                  Translate.translate(
                    TranslateKeys.deleteFlowKeepCharacters,
                    context,
                  ),
                ),
                _buildKeepItem(
                  Translate.translate(TranslateKeys.deleteFlowKeepVideo, context),
                ),
                _buildKeepItem(
                  Translate.translate(
                    TranslateKeys.deleteFlowKeepEditing,
                    context,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (isSixtyPercentOffer) ...[
          SizedBox(height: 12.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Row(
              children: [
                Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Center(child: SvgPicture.asset("assets/icons/offer.svg",width: 16.w,height: 16.h,color: Colors.white.withValues(alpha: 0.95),))
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        planTitle,
                        style: GoogleFonts.quicksand(
                          color: Colors.white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        planSubTitle,
                        style: GoogleFonts.quicksand(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: 12.h),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: GestureDetector(
            onTap: onCtaTap,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFCA60FF), Color(0xFF3F46FF)],
                ),
                borderRadius: BorderRadius.circular(999.r),
              ),
              alignment: Alignment.center,
              child: Text(
                ctaText,
                style: GoogleFonts.quicksand(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLossItem(String text, String icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: const Color(0xFF472220),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Center(child: SvgPicture.asset(icon, color: const Color(0xFFFF5C47), width: 18.sp, height: 18,)),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.quicksand(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeepItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: Colors.white.withValues(alpha: 0.9),
            size: 20.sp,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.quicksand(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileBirthdateSection extends StatefulWidget {
  const _ProfileBirthdateSection({
    required this.title,
    required this.existingBirthdate,
    required this.onDateChanged,
  });

  final String title;
  final DateTime? existingBirthdate;
  final ValueChanged<DateTime> onDateChanged;

  @override
  State<_ProfileBirthdateSection> createState() =>
      _ProfileBirthdateSectionState();
}

class _ProfileBirthdateSectionState extends State<_ProfileBirthdateSection> {
  static final DateTime _minDate = DateTime(1950, 1, 1);
  static final DateTime _maxDate = DateTime(2017, 12, 31);

  late final ValueNotifier<DateTime> _displayedDate;
  late final DateTime _pickerInitial;
  late int _selectedDay;
  late int _selectedMonth;
  late int _selectedYear;
  late final FixedExtentScrollController _dayController;
  late final FixedExtentScrollController _monthController;
  late final FixedExtentScrollController _yearController;

  DateTime _clamp(DateTime d) {
    if (d.isBefore(_minDate)) return _minDate;
    if (d.isAfter(_maxDate)) return _maxDate;
    return d;
  }

  @override
  void initState() {
    super.initState();
    final base = widget.existingBirthdate ?? DateTime(2001, 1, 1);
    _pickerInitial = _clamp(base);
    _displayedDate = ValueNotifier<DateTime>(_pickerInitial);
    _selectedDay = _pickerInitial.day;
    _selectedMonth = _pickerInitial.month;
    _selectedYear = _pickerInitial.year;
    _dayController = FixedExtentScrollController(initialItem: _selectedDay - 1);
    _monthController = FixedExtentScrollController(
      initialItem: _selectedMonth - 1,
    );
    _yearController = FixedExtentScrollController(
      initialItem: _selectedYear - _minDate.year,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onDateChanged(_displayedDate.value);
    });
  }

  int _daysInMonth(int month, int year) => DateTime(year, month + 1, 0).day;

  void _onPickerChanged() {
    final maxDay = _daysInMonth(_selectedMonth, _selectedYear);
    if (_selectedDay > maxDay) {
      _selectedDay = maxDay;
      _dayController.jumpToItem(_selectedDay - 1);
    }
    final next = _clamp(DateTime(_selectedYear, _selectedMonth, _selectedDay));
    _displayedDate.value = next;
    widget.onDateChanged(next);
  }

  @override
  void dispose() {
    _displayedDate.dispose();
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final monthNames = List<String>.generate(
      12,
      (i) => DateFormat.MMMM(locale).format(DateTime(2024, i + 1, 1)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 10.w),
          child: Text(
            widget.title,
            style: GoogleFonts.quicksand(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(height: 10.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          child: ValueListenableBuilder<DateTime>(
            valueListenable: _displayedDate,
            builder: (context, date, _) {
              return Container(
                height: 40.h,
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 0.h, horizontal: 16.w),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  DateFormat.yMMMMd(locale).format(date),
                  textAlign: TextAlign.left,
                  style: GoogleFonts.quicksand(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 12.h),
        SizedBox(
          height: 190.h,
          child: CupertinoTheme(
            data: const CupertinoThemeData(brightness: Brightness.dark),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 54.w,
                  child: CupertinoPicker(
                    scrollController: _dayController,
                    itemExtent: 38.h,
                    selectionOverlay: const SizedBox.shrink(),
                    onSelectedItemChanged: (index) {
                      _selectedDay = (index % 31) + 1;
                      _onPickerChanged();
                    },
                    children: List.generate(
                      31,
                      (i) => Center(
                        child: Text(
                          '${i + 1}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.quicksand(
                            color: Colors.white,
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                SizedBox(
                  width: 110.w,
                  child: CupertinoPicker(
                    scrollController: _monthController,
                    itemExtent: 38.h,
                    selectionOverlay: const SizedBox.shrink(),
                    onSelectedItemChanged: (index) {
                      _selectedMonth = (index % 12) + 1;
                      _onPickerChanged();
                    },
                    children: List.generate(
                      12,
                      (i) => Center(
                        child: Text(
                          monthNames[i],
                          textAlign: TextAlign.center,
                          style: GoogleFonts.quicksand(
                            color: Colors.white,
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                SizedBox(
                  width: 68.w,
                  child: CupertinoPicker(
                    scrollController: _yearController,
                    itemExtent: 38.h,
                    selectionOverlay: const SizedBox.shrink(),
                    onSelectedItemChanged: (index) {
                      final totalYears = _maxDate.year - _minDate.year + 1;
                      _selectedYear = _minDate.year + (index % totalYears);
                      _onPickerChanged();
                    },
                    children: List.generate(
                      _maxDate.year - _minDate.year + 1,
                      (i) => Center(
                        child: Text(
                          '${_minDate.year + i}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.quicksand(
                            color: Colors.white,
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
