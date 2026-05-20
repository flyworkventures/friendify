
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/Services/device_trial_eligibility_service.dart';
import 'package:friendfy/Services/notification_service.dart';
import 'package:friendfy/Services/revenuecat_service.dart';
import 'package:friendfy/View/SplashView/splash_view.dart';
import 'package:friendfy/locale_provider.dart';
import 'package:friendfy/utils/app_constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("ELEVENLABS_API_KEY: ${AppConstants.baseURL}");

  await DeviceTrialEligibilityService.applyStoredTrialLockToPremiumService();

  // Initialize notification service
  await NotificationService.initialize();
  await initializeRevenueCat();
  runApp(ProviderScope(child: MyApp()));
}


Future<void> initializeRevenueCat() async {
  try {
    String apiKey;
    if (Platform.isIOS) {
      // appl_pOEGBUSRqhfvvHeqqhIwBImdKlO
      apiKey = 'appl_pOEGBUSRqhfvvHeqqhIwBImdKlO';
    } else if (Platform.isAndroid) {
      apiKey = 'goog_NCAHgzxDCWJNpMDMBLXdpfTwwgh';
    } else {
      throw UnsupportedError('Platform not supported');
    }
    debugPrint(apiKey);
    await Purchases.setLogLevel(LogLevel.info);
    await Purchases.configure(PurchasesConfiguration(apiKey));
    debugPrint("✅ RevenueCat initialized successfully");
  } catch (e) {
    // Hatayı logla ama uygulamayı çökerme
    debugPrint("⚠️ RevenueCat initialization failed: $e");
    debugPrint("App will continue without premium features");
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => ref.read(appProvider).initLang());
    // RevenueCat purchase listener ekle (satın alma sonrası premium tanımlama için)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RevenueCatService.addPurchaseListener(ref.container);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // Uygulama arka plana alındı veya kapatıldı
        NotificationService.startPeriodicNotifications();
        break;
      case AppLifecycleState.resumed:
        // Uygulama ön plana getirildi
        NotificationService.stopPeriodicNotifications();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appPrv = ref.watch(appProvider);
    
    return ScreenUtilInit(
      designSize: Size(430, 852),
      child: MaterialApp(
        supportedLocales: AppConstants.supportedLocales,
            localizationsDelegates: AppConstants.localizationsDelegates,
            locale: appPrv.currentLang,
        navigatorKey: navigatorKey,
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            textTheme: TextTheme(bodyLarge: GoogleFonts.quicksand()),
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          ),
          home: SplashView(),
          routes: AppConstants.routes,
        ),
      
    );
  }
}




