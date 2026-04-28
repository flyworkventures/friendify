import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';
import 'package:friendfy/Widgets/background.dart';
import 'package:friendfy/locale_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class LanguageView extends ConsumerStatefulWidget {
  const LanguageView({super.key});

  @override
  ConsumerState<LanguageView> createState() => _LanguageViewState();
}

class _LanguageViewState extends ConsumerState<LanguageView> {
  final List<_LanguageOption> _languageOptions = const [
    _LanguageOption(
      locale: Locale('en', 'US'),
      title: 'English',
      flagEmoji: '🇬🇧',
    ),
    _LanguageOption(
      locale: Locale('de', 'DE'),
      title: 'German',
      flagEmoji: '🇩🇪',
    ),
    _LanguageOption(
      locale: Locale('it', 'IT'),
      title: 'Italian',
      flagEmoji: '🇮🇹',
    ),
    _LanguageOption(
      locale: Locale('fr', 'FR'),
      title: 'French',
      flagEmoji: '🇫🇷',
    ),
    _LanguageOption(
      locale: Locale('tr', 'TR'),
      title: 'Turkish',
      flagEmoji: '🇹🇷',
    ),
    _LanguageOption(
      locale: Locale('ja', 'JP'),
      title: 'Japanese',
      flagEmoji: '🇯🇵',
    ),
    _LanguageOption(
      locale: Locale('es', 'ES'),
      title: 'Spanish',
      flagEmoji: '🇪🇸',
    ),
    _LanguageOption(
      locale: Locale('ru', 'RU'),
      title: 'Russian',
      flagEmoji: '🇷🇺',
    ),
    _LanguageOption(
      locale: Locale('ko', 'KR'),
      title: 'Korean',
      flagEmoji: '🇰🇷',
    ),
    _LanguageOption(
      locale: Locale('hi', 'IN'),
      title: 'Hindi',
      flagEmoji: '🇮🇳',
    ),
    _LanguageOption(
      locale: Locale('pt', 'PT'),
      title: 'Portuguese',
      flagEmoji: '🇵🇹',
    ),
    _LanguageOption(
      locale: Locale('zh', 'CN'),
      title: 'Chinese',
      flagEmoji: '🇨🇳',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final appPrv = ref.watch(appProvider);
    final Locale currentLocale = appPrv.currentLang ?? const Locale('en', 'US');

    return BackgroundWidget(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: _LanguageContent(
            options: _languageOptions,
            currentLocale: currentLocale,
            onSave: (selectedLocale) async {
              await appPrv.changeLang(selectedLocale);
              if (!mounted) return;
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }
}

class _LanguageContent extends StatefulWidget {
  final List<_LanguageOption> options;
  final Locale currentLocale;
  final Future<void> Function(Locale selectedLocale) onSave;

  const _LanguageContent({
    required this.options,
    required this.currentLocale,
    required this.onSave,
  });

  @override
  State<_LanguageContent> createState() => _LanguageContentState();
}

class _LanguageContentState extends State<_LanguageContent> {
  late Locale _selectedLocale;

  @override
  void initState() {
    super.initState();
    _selectedLocale = widget.currentLocale;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(
                  CupertinoIcons.back,
                  color: Colors.white,
                  size: 24.sp,
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    Translate.translate(TranslateKeys.language, context),
                    style: GoogleFonts.quicksand(
                      color: Colors.white,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 24.w),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            itemCount: widget.options.length,
            separatorBuilder: (_, __) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              final lang = widget.options[index];
              final isSelected =
                  _selectedLocale.languageCode == lang.locale.languageCode &&
                  _selectedLocale.countryCode == lang.locale.countryCode;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedLocale = lang.locale;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xffA13AF4)
                          : Colors.white.withValues(alpha: 0.05),
                      width: isSelected ? 1.6 : 1,
                    ),
                    gradient: LinearGradient(
                      colors: isSelected
                          ? [
                              const Color(0xff51126E).withValues(alpha: 0.58),
                              const Color(0xff2F0E40).withValues(alpha: 0.58),
                            ]
                          : [
                              const Color(0xffFFFFFF).withValues(alpha: 0.12),
                              const Color(0xffFFFFFF).withValues(alpha: 0.06),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36.w,
                        height: 36.w,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          lang.flagEmoji,
                          style: TextStyle(fontSize: 22.sp),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        lang.title,
                        style: GoogleFonts.quicksand(
                          color: Colors.white,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 26.h),
          child: GestureDetector(
            onTap: () => widget.onSave(_selectedLocale),
            child: Container(
              width: double.infinity,
              height: 56.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32.r),
                gradient: const LinearGradient(
                  colors: [Color(0xffCD63FF), Color(0xff3E34FF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Center(
                child: Text(
                  "✨ ${Translate.translate(TranslateKeys.editCharacterSaveChanges, context)}",
                  style: GoogleFonts.quicksand(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LanguageOption {
  final Locale locale;
  final String title;
  final String flagEmoji;

  const _LanguageOption({
    required this.locale,
    required this.title,
    required this.flagEmoji,
  });
}
