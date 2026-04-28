import 'dart:io';

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
import 'package:friendfy/Widgets/textfield.dart';
import 'package:friendfy/main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
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
                      MyButton(
                        onTap: () => _showDeleteAccountBottomSheet(context),
                        radius: BorderRadius.circular(50.r),
                        margin: EdgeInsets.symmetric(horizontal: 10.r),
                        size: Size(MediaQuery.sizeOf(context).width, 50.h),
                        backgroundColor: Colors.transparent,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(left: 17.r),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                                  child: HeroIcon(
                                    HeroIcons.trash,
                                    color: Colors.red,
                                    style: HeroIconStyle.solid,
                                    size: 20,
                                  ),
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
                                        HeroIcons.bookmark,
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
                                        fontSize: 14.sp,
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
                  .read(AllControllers.profileSettingsViewController.notifier)
                  .genderChanged(value);
            },
            borderRadius: BorderRadius.circular(12.r),
            splashColor: Colors.white.withValues(alpha: 0.08),
            highlightColor: Colors.white.withValues(alpha: 0.04),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 4.w),
              decoration: BoxDecoration(
                color: selected ? MyColors.purple : Colors.transparent,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  leading,
                  SizedBox(width: 6.w),
                  Flexible(
                    child: Text(
                      label,
                      style: GoogleFonts.quicksand(
                        color: selected ? Colors.white : unselectedTint,
                        fontSize: 13.sp,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          segment(
            label: Translate.translate(TranslateKeys.male, context),
            value: 'male',
            selected: selectedGender == 'male',
            leading: SvgPicture.asset(
              'assets/male.svg',
              width: 18.w,
              height: 18.w,
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
              width: 18.w,
              height: 18.w,
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
            leading: Icon(
              Icons.block_rounded,
              size: 18.sp,
              color: selectedGender == null ? Colors.white : unselectedTint,
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
                            height: 100.h,
                            child: selectedImagePath != null
                                ? Image.file(
                                    File(selectedImagePath),
                                    fit: BoxFit.cover,
                                  )
                                : CachedNetworkImage(
                                    imageUrl:
                                        photoURL ??
                                        "https://fakefriend.b-cdn.net/profile.png",
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
                            child: Container(
                              width: 40.w,
                              height: 40.h,
                              decoration: BoxDecoration(
                                color: MyColors.purple,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
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
                ref
                    .read(AllControllers.profileSettingsViewController.notifier)
                    .logout();
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
          padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 12.h),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 10.w),
            padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 20.h),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(22.r),
                topRight: Radius.circular(22.r),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48.w,
                    height: 5.h,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(100.r),
                    ),
                  ),
                ),
                SizedBox(height: 18.h),
                Text(
                  "We’re sad to see you go",
                  style: GoogleFonts.quicksand(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 31.sp,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  "Your membership has been cancelled. You can still reactivate before your billing period ends.",
                  style: GoogleFonts.quicksand(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w500,
                    fontSize: 16.sp,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 18.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(18.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                          SizedBox(width: 8.w),
                          Text(
                            "Change your mind?",
                            style: GoogleFonts.quicksand(
                              color: Colors.white,
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        "You can reactivate your membership now to keep your benefits.",
                        style: GoogleFonts.quicksand(
                          color: Colors.white.withValues(alpha: 0.70),
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 14.h),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18.r),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                          },
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 12.h,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18.r),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.link,
                                  color: MyColors.purple,
                                  size: 20.sp,
                                ),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: Text(
                                    "Wait, I want to reactivate",
                                    style: GoogleFonts.quicksand(
                                      color: Colors.white,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white,
                                  size: 20.sp,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30.r),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      ref
                          .read(
                            AllControllers.profileSettingsViewController.notifier,
                          )
                          .deleteAccount();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(30.r),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          "Delete my account",
                          style: GoogleFonts.quicksand(
                            color: Colors.red.shade200,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onDateChanged(_displayedDate.value);
    });
  }

  @override
  void dispose() {
    _displayedDate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();

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
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  DateFormat.yMMMMd(locale).format(date),
                  style: GoogleFonts.quicksand(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
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
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _pickerInitial,
              minimumDate: _minDate,
              maximumDate: _maxDate,
              onDateTimeChanged: (d) {
                final v = _clamp(d);
                _displayedDate.value = v;
                widget.onDateChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}
