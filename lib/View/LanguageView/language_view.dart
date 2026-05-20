import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Models/agent_model.dart';
import 'package:friendfy/Widgets/background.dart';
import 'package:friendfy/Providers/agent_character_translation_provider.dart';
import 'package:friendfy/Services/agent_character_translation_service.dart';
import 'package:friendfy/locale_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';

class LanguageView extends ConsumerStatefulWidget {
  const LanguageView({super.key});

  @override
  ConsumerState<LanguageView> createState() => _LanguageViewState();
}

class _LanguageViewState extends ConsumerState<LanguageView> {
  final List<_LanguageOption> _languageOptions = const [
    _LanguageOption(locale: Locale('en', 'US'), title: 'English'),
    _LanguageOption(locale: Locale('de', 'DE'), title: 'German'),
    _LanguageOption(locale: Locale('it', 'IT'), title: 'Italian'),
    _LanguageOption(locale: Locale('fr', 'FR'), title: 'French'),
    _LanguageOption(locale: Locale('tr', 'TR'), title: 'Turkish'),
    _LanguageOption(locale: Locale('ja', 'JP'), title: 'Japanese'),
    _LanguageOption(locale: Locale('es', 'ES'), title: 'Spanish'),
    _LanguageOption(locale: Locale('ru', 'RU'), title: 'Russian'),
    _LanguageOption(locale: Locale('ko', 'KR'), title: 'Korean'),
    _LanguageOption(locale: Locale('hi', 'IN'), title: 'Hindi'),
    _LanguageOption(locale: Locale('pt', 'PT'), title: 'Portuguese'),
    _LanguageOption(locale: Locale('zh', 'CN'), title: 'Chinese'),
  ];

  @override
  Widget build(BuildContext context) {
    final appPrv = ref.watch(appProvider);
    final Locale currentLocale = appPrv.currentLang ??
        Localizations.maybeLocaleOf(context) ??
        const Locale('en', 'US');

    return BackgroundWidget(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: _LanguageContent(
            options: _languageOptions,
            currentLocale: currentLocale,
            onSave: (selectedLocale) async {
              await appPrv.changeLang(selectedLocale);
              final agentsVm = ref.read(AllControllers.agentsViewController);
              final allAgents = <AgentModel>[
                ...?agentsVm.agents,
                ...?agentsVm.userAgents,
                ...?agentsVm.recentAgents,
              ];
              if (allAgents.isNotEmpty) {
                await AgentCharacterTranslationService.instance.prefetchAgents(
                  allAgents,
                  selectedLocale.languageCode,
                );
                ref
                    .read(agentCharacterTranslationVersionProvider.notifier)
                    .state++;
              }
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
    _selectedLocale = widget.options
            .firstWhere(
              (option) =>
                  option.locale.languageCode ==
                  widget.currentLocale.languageCode,
              orElse: () => widget.options.first,
            )
            .locale;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h).copyWith(bottom: 10.h),
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
                  _selectedLocale.languageCode == lang.locale.languageCode;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedLocale = lang.locale;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h).copyWith(bottom: 5.h),
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
                        clipBehavior: Clip.antiAlias,
                        decoration: const BoxDecoration(
                         
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(2.w),
                          child: ClipOval(
                            child: Image.asset(
                              _flagAssetPath(lang.locale),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return ColoredBox(
                                  color: Colors.grey.shade300,
                                  child: Icon(
                                    Icons.language_rounded,
                                    size: 18.sp,
                                    color: Colors.grey.shade700,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        lang.title,
                        style: GoogleFonts.quicksand(
                          color: Colors.white,
                          fontSize: 16.sp,
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
          padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 0.h),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [   
                    HeroIcon(HeroIcons.sparkles,color: Colors.white,style:HeroIconStyle.solid,),
                    SizedBox(width: 10.w,),
                    Text(
                  "${Translate.translate(TranslateKeys.editCharacterSaveChanges, context)}",
                  style: GoogleFonts.quicksand(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                  ],
                )
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

  const _LanguageOption({
    required this.locale,
    required this.title,
  });
}

/// Önce ülke kodu (`jp`, `kr`, `es`…), yoksa dil kodu ile bayrak dosyası.
String _flagAssetPath(Locale locale) {
  final cc = locale.countryCode?.toLowerCase();
  if (cc != null && cc.isNotEmpty) {
    return 'assets/flags/$cc.png';
  }
  final lc = locale.languageCode.toLowerCase();
  switch (lc) {
    case 'ja':
      return 'assets/flags/jp.png';
    case 'ko':
      return 'assets/flags/kr.png';
    case 'es':
      return 'assets/flags/es.png';
    case 'en':
      return 'assets/flags/us.png';
    case 'zh':
      return 'assets/flags/cn.png';
    case 'pt':
      return 'assets/flags/pt.png';
    case 'hi':
      return 'assets/flags/in.png';
    case 'de':
      return 'assets/flags/de.png';
    case 'it':
      return 'assets/flags/it.png';
    case 'fr':
      return 'assets/flags/fr.png';
    case 'tr':
      return 'assets/flags/tr.png';
    case 'ru':
      return 'assets/flags/ru.png';
    default:
      return 'assets/flags/xx.png';
  }
}
