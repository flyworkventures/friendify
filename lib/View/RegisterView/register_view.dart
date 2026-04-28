import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Models/interest_option.dart';
import 'package:friendfy/Services/interest_service.dart';
import 'package:friendfy/Themes/colors.dart';
import 'package:friendfy/Widgets/background.dart';
import 'package:friendfy/Widgets/button.dart';
import 'package:friendfy/Widgets/smooth_slide.dart';
import 'package:friendfy/Widgets/textfield.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Kayıt 4–5. adım tek seçim seçenekleri (slug backend’e gider).
class _RegChoiceOption {
  const _RegChoiceOption({
    required this.slug,
    required this.emoji,
    required this.labelKey,
  });
  final String slug;
  final String emoji;
  final String labelKey;
}

const List<_RegChoiceOption> _kAiExpectationOptions = [
  _RegChoiceOption(slug: 'fun', emoji: '🥳', labelKey: 'register_expect_fun'),
  _RegChoiceOption(
    slug: 'connection',
    emoji: '💬',
    labelKey: 'register_expect_connection',
  ),
  _RegChoiceOption(
    slug: 'flirting',
    emoji: '🔥',
    labelKey: 'register_expect_flirting',
  ),
  _RegChoiceOption(
    slug: 'comfort',
    emoji: '☁️',
    labelKey: 'register_expect_comfort',
  ),
  _RegChoiceOption(
    slug: 'motivation',
    emoji: '🚀',
    labelKey: 'register_expect_motivation',
  ),
];

const List<_RegChoiceOption> _kAiTimingOptions = [
  _RegChoiceOption(
    slug: 'morning',
    emoji: '☀️',
    labelKey: 'register_time_morning',
  ),
  _RegChoiceOption(
    slug: 'after_work',
    emoji: '🌇',
    labelKey: 'register_time_after_work',
  ),
  _RegChoiceOption(
    slug: 'late_night',
    emoji: '🌙',
    labelKey: 'register_time_late_night',
  ),
  _RegChoiceOption(
    slug: 'randomly',
    emoji: '🎲',
    labelKey: 'register_time_randomly',
  ),
  _RegChoiceOption(
    slug: 'feeling_down',
    emoji: '❤️',
    labelKey: 'register_time_feeling_down',
  ),
];

class RegisterView extends ConsumerStatefulWidget {
  const RegisterView({super.key});

  @override
  ConsumerState<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends ConsumerState<RegisterView> {
  /// Seçilen ilgi alanı **slug** listesi (API / kayıt ile uyumlu).
  List<String> tags = [];

  List<InterestOption> _interestsApi = [];
  bool _interestsLoading = false;
  bool _interestsLoadScheduled = false;
  String? _interestsError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_interestsLoadScheduled) {
      _interestsLoadScheduled = true;
      _loadInterestsFromApi();
    }
  }

  /// `interest.md` — desteklenen dil kodlarına göre `lang` gönderilir.
  String _interestApiLang(Locale locale) {
    const supported = {
      'tr',
      'en',
      'de',
      'fr',
      'pt',
      'it',
      'zh',
      'ja',
      'ru',
      'hi',
      'ko',
    };
    final code = locale.languageCode.toLowerCase();
    return supported.contains(code) ? code : 'en';
  }

  Future<void> _loadInterestsFromApi() async {
    if (!mounted) return;
    setState(() {
      _interestsLoading = true;
      _interestsError = null;
    });
    try {
      final lang = _interestApiLang(Localizations.localeOf(context));
      final list = await InterestService.fetchLocalized(lang);
      if (!mounted) return;
      setState(() {
        _interestsApi = list;
        _interestsLoading = false;
        _interestsError = null;
      });
    } catch (e, st) {
      debugPrint('Interests load error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _interestsLoading = false;
        _interestsError = 'failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reg = ref.watch(AllControllers.registerViewController);
    final stepIndex = reg.currentIndex;
    const totalSteps = 5;

    final nextBlocked =
        (stepIndex == 3 &&
            (reg.aiPartnerExpectation == null ||
                reg.aiPartnerExpectation!.isEmpty)) ||
        (stepIndex == 4 &&
            (reg.aiPreferredTime == null || reg.aiPreferredTime!.isEmpty));

    return Scaffold(
      body: BackgroundWidget(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 10,
                ).copyWith(top: 20).r,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            ref
                                .read(
                                  AllControllers
                                      .registerViewController
                                      .notifier,
                                )
                                .previousPage();
                          },
                          child: Icon(
                            CupertinoIcons.chevron_left_circle_fill,
                            color: Colors.white,
                            size: 20.w,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Text(
                          Translate.translate(TranslateKeys.back, context),
                          style: GoogleFonts.quicksand(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Expanded(child: asamalar()),
                    Text(
                      "${stepIndex + 1} / $totalSteps",
                      style: GoogleFonts.quicksand(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              Expanded(child: bottom()),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 10,
                ).copyWith(bottom: 10).r,
                child: Opacity(
                  opacity: nextBlocked ? 0.45 : 1,
                  child: AbsorbPointer(
                    absorbing: nextBlocked,
                    child: MyGradientButton(
                      onTap: () async {
                        FocusScope.of(context).unfocus();
                        final notifier = ref.read(
                          AllControllers.registerViewController.notifier,
                        );
                        final currentIndex = ref
                            .read(AllControllers.registerViewController)
                            .currentIndex;
                        final r = ref.read(
                          AllControllers.registerViewController,
                        );

                        if (currentIndex == 4) {
                          if (r.aiPreferredTime == null ||
                              r.aiPreferredTime!.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  Translate.translate(
                                    TranslateKeys.registerPleaseSelectOption,
                                    context,
                                  ),
                                ),
                              ),
                            );
                            return;
                          }
                          if (!context.mounted) return;
                          Navigator.of(
                            context,
                          ).pushReplacementNamed('/accountCreatedView');
                          return;
                        }

                        if (currentIndex == 3) {
                          if (r.aiPartnerExpectation == null ||
                              r.aiPartnerExpectation!.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  Translate.translate(
                                    TranslateKeys.registerPleaseSelectOption,
                                    context,
                                  ),
                                ),
                              ),
                            );
                            return;
                          }
                        }

                        if (currentIndex == 2) {
                          notifier.updateHobbies(tags);
                        }
                        notifier.pushBirthdayPage();
                      },
                      size: Size(MediaQuery.sizeOf(context).width, 48.h),
                      margin: EdgeInsets.zero,
                      radius: BorderRadius.circular(50),
                      child: Center(
                        child: Text(
                          Translate.translate(TranslateKeys.next, context),
                          style: GoogleFonts.quicksand(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15.sp,
                          ),
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
    );
  }

  Widget bottom() {
    return Container(
      padding: EdgeInsets.only(top: 30, bottom: 15),
      width: double.infinity,
      decoration: const BoxDecoration(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 20.h),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  child: PageView(
                    controller: ref
                        .read(AllControllers.registerViewController.notifier)
                        .pageController,
                    physics: NeverScrollableScrollPhysics(),
                    children: [
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SmoothSlide(
                              child: Text(
                                Translate.translate(
                                  TranslateKeys.tellAboutYourself,
                                  context,
                                ),
                                style: GoogleFonts.quicksand(
                                  color: Colors.white,
                                  fontSize: 24.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SmoothSlide(
                              child: Text(
                                Translate.translate(
                                  TranslateKeys.bioHelps,
                                  context,
                                ),
                                style: GoogleFonts.quicksand(
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w400,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(height: 20.h),
                            Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Text(
                                Translate.translate(
                                  TranslateKeys.fullName,
                                  context,
                                ),
                                style: GoogleFonts.quicksand(
                                  color: Colors.white,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(height: 10.h),

                            MyTextField(
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.2),
                              textStyle: GoogleFonts.quicksand(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              hintText: Translate.translate(
                                TranslateKeys.enterYourFullname,
                                context,
                              ),
                              hintStyle: GoogleFonts.quicksand(
                                color: Colors.white,
                                fontSize: 14.sp,
                              ),
                              height: 40.h,
                              contentPadding: EdgeInsets.only(
                                top: 5.h,
                                left: 5.w,
                              ),
                              border: OutlineInputBorder(
                                borderSide: BorderSide.none,
                                borderRadius: BorderRadius.circular(8).r,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide.none,
                                borderRadius: BorderRadius.circular(8).r,
                              ),
                              controller: ref
                                  .read(
                                    AllControllers
                                        .registerViewController
                                        .notifier,
                                  )
                                  .usernameController,
                            ),

                            SizedBox(height: 15.h),
                            Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Text(
                                Translate.translate(
                                  TranslateKeys.gender,
                                  context,
                                ),
                                style: GoogleFonts.quicksand(
                                  color: Colors.white,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(height: 10.h),
                            _buildGenderSegmentedControl(context),
                            SizedBox(height: 20.h),
                          ],
                        ),
                      ),

                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SmoothSlide(
                              child: Text(
                                Translate.translate(
                                  TranslateKeys.whatsYourBirthdate,
                                  context,
                                ),
                                style: GoogleFonts.quicksand(
                                  color: Colors.white,
                                  fontSize: 26.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SmoothSlide(
                              child: Text(
                                Translate.translate(
                                  TranslateKeys.birthdayNote,
                                  context,
                                ),
                                style: GoogleFonts.quicksand(
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w400,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(height: 24.h),
                            _RegisterBirthdateSection(
                              title: Translate.translate(
                                TranslateKeys.birthdate,
                                context,
                              ),
                              existingBirthdate: ref
                                  .read(
                                    AllControllers
                                        .registerViewController
                                        .notifier,
                                  )
                                  .birthdate,
                              onDateChanged: (d) {
                                ref
                                    .read(
                                      AllControllers
                                          .registerViewController
                                          .notifier,
                                    )
                                    .updateBirthdate(d);
                              },
                            ),
                          ],
                        ),
                      ),

                      SingleChildScrollView(
                        child: Column(
                          children: [
                            SmoothSlide(
                              child: Text(
                                Translate.translate(
                                  TranslateKeys.shareInterests,
                                  context,
                                ),
                                style: GoogleFonts.quicksand(
                                  color: Colors.white,
                                  fontSize: 26.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            SizedBox(height: 20.h),
                            _buildInterestsChips(context),
                          ],
                        ),
                      ),
                      _buildAiExpectationStep(context),
                      _buildAiTimingStep(context),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 15.h),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsChips(BuildContext context) {
    if (_interestsLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 32.h),
        child: Center(
          child: SizedBox(
            width: 28.w,
            height: 28.w,
            child: const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (_interestsError != null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 8.w),
        child: Column(
          children: [
            Text(
              Translate.translate(TranslateKeys.interestsLoadFailed, context),
              textAlign: TextAlign.center,
              style: GoogleFonts.quicksand(
                color: Colors.white70,
                fontSize: 14.sp,
              ),
            ),
            SizedBox(height: 12.h),
            TextButton(
              onPressed: _loadInterestsFromApi,
              child: Text(
                Translate.translate(TranslateKeys.retry, context),
                style: GoogleFonts.quicksand(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15.sp,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_interestsApi.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        child: Text(
          Translate.translate(TranslateKeys.interestsLoadFailed, context),
          textAlign: TextAlign.center,
          style: GoogleFonts.quicksand(color: Colors.white54, fontSize: 14.sp),
        ),
      );
    }

    return SizedBox(
      width: MediaQuery.sizeOf(context).width,
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _interestsApi.map((interest) {
            final isSelected = tags.contains(interest.slug);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    tags.remove(interest.slug);
                  } else {
                    tags.add(interest.slug);
                  }
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
                decoration: BoxDecoration(
                  color: !isSelected
                      ? Colors.white.withValues(alpha: 0.15)
                      : Color(0xffDC7AFF).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8).r,
                  border: Border.all(
                    color: isSelected ? Color(0xffD55EFF) : Colors.transparent,
                    width: isSelected ? 1 : 0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.62,
                      ),
                      child: Text(
                        interest.label,
                        style: GoogleFonts.quicksand(
                          color: Colors.white,
                          fontSize: 15.sp,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (interest.emoji.isNotEmpty) ...[
                      Text(interest.emoji, style: TextStyle(fontSize: 16.sp)),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _registerChoiceTile({
    required BuildContext context,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: selected
              ? Color(0xffDC7AFF).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: selected ? const Color(0xffD55EFF) : Colors.transparent,
            width: selected ? 1.5 : 0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.quicksand(
            color: Colors.white,
            fontSize: 15.sp,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildAiExpectationStep(BuildContext context) {
    final selected = ref
        .watch(AllControllers.registerViewController)
        .aiPartnerExpectation;
    final notifier = ref.read(AllControllers.registerViewController.notifier);
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SmoothSlide(
            child: Text(
              Translate.translate(
                TranslateKeys.registerAiExpectationTitle,
                context,
              ),
              style: GoogleFonts.quicksand(
                color: Colors.white,
                fontSize: 26.sp,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 24.h),
          ..._kAiExpectationOptions.map(
            (o) => Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: _registerChoiceTile(
                context: context,
                label: '${o.emoji} ${Translate.translate(o.labelKey, context)}',
                selected: selected == o.slug,
                onTap: () => notifier.updateAiPartnerExpectation(o.slug),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiTimingStep(BuildContext context) {
    final selected = ref
        .watch(AllControllers.registerViewController)
        .aiPreferredTime;
    final notifier = ref.read(AllControllers.registerViewController.notifier);
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SmoothSlide(
            child: Text(
              Translate.translate(TranslateKeys.registerAiTimingTitle, context),
              style: GoogleFonts.quicksand(
                color: Colors.white,
                fontSize: 26.sp,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 24.h),
          ..._kAiTimingOptions.map(
            (o) => Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: _registerChoiceTile(
                context: context,
                label: '${o.emoji} ${Translate.translate(o.labelKey, context)}',
                selected: selected == o.slug,
                onTap: () => notifier.updateAiPreferredTime(o.slug),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget asamalar() {
    final idx = ref.watch(AllControllers.registerViewController).currentIndex;
    const inactive = Color(0x33FFFFFF);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        children: List.generate(5, (i) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < 4 ? 5 : 0),
              height: 2,
              decoration: BoxDecoration(
                color: idx >= i ? MyColors.purple : inactive,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Görseldeki gibi yatay segment kontrol: Erkek | Kadın | Gizli/Private
  Widget _buildGenderSegmentedControl(BuildContext context) {
    const unselectedTint = Color(0xFFB8B8C0);

    return Consumer(
      builder: (context, ref, _) {
        final selectedGender = ref
            .watch(AllControllers.registerViewController)
            .gender;

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
                      .read(AllControllers.registerViewController.notifier)
                      .updateGender(value);
                },
                borderRadius: BorderRadius.circular(12.r),
                splashColor: Colors.white.withValues(alpha: 0.08),
                highlightColor: Colors.white.withValues(alpha: 0.04),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    vertical: 12.h,
                    horizontal: 4.w,
                  ),
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
                label: Translate.translate(
                  TranslateKeys.genderPrivate,
                  context,
                ),
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
      },
    );
  }
}

/// iOS tarzı tekerlek + üstte seçili tarih kutusu (tekerlek her kaydırmada yeniden oluşmasın diye ValueNotifier).
class _RegisterBirthdateSection extends StatefulWidget {
  const _RegisterBirthdateSection({
    required this.title,
    required this.existingBirthdate,
    required this.onDateChanged,
  });

  final String title;
  final DateTime? existingBirthdate;
  final ValueChanged<DateTime> onDateChanged;

  @override
  State<_RegisterBirthdateSection> createState() =>
      _RegisterBirthdateSectionState();
}

class _RegisterBirthdateSectionState extends State<_RegisterBirthdateSection> {
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
        SizedBox(height: 8.h),
        SizedBox(
          height: 216.h,
          child: CupertinoTheme(
            data: CupertinoThemeData(
              brightness: Brightness.dark,
              textTheme: CupertinoTextThemeData(
                textStyle: GoogleFonts.quicksand(
                  color: Colors.white,
                  fontSize: 20.sp,
                ),
                dateTimePickerTextStyle: GoogleFonts.quicksand(
                  color: Colors.white,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _pickerInitial,
              minimumDate: _minDate,
              maximumDate: _maxDate,
              onDateTimeChanged: (DateTime d) {
                _displayedDate.value = d;
                widget.onDateChanged(d);
              },
            ),
          ),
        ),
      ],
    );
  }
}
