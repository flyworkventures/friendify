import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';
import 'package:friendfy/Controllers/ViewControllers/chat_screen_view_controller.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Models/agent_model.dart';
import 'package:friendfy/Models/user_model.dart';
import 'package:friendfy/Themes/colors.dart';
import 'package:friendfy/Widgets/HomeWidgets/feel_widget.dart';
import 'package:friendfy/Widgets/HomeWidgets/your_matches.dart';

import 'package:friendfy/main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gradient_borders/gradient_borders.dart';
import 'package:heroicons/heroicons.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:friendfy/Services/revenuecat_service.dart';
import 'package:friendfy/Services/premium_service.dart';
import 'package:friendfy/View/EditAgentView/edit_agent_view.dart';
import 'package:friendfy/View/PremiumScreen/premium_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  Timer? timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      timer = Timer.periodic(Duration(seconds: 4), (a) {
        if (!mounted) return;
        ref
            .read(AllControllers.bottomNavbarController.notifier)
            .nextPage(context);
      });
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  pushPremium() async {
    try {
      // Misafir kullanıcı kontrolü
      UserModel? user = ref.read(AllControllers.userController);
      if (user?.credential == "guest") {
        // Misafir kullanıcı için uyarı dialog göster
        showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              title: Text(
                Translate.translate("login_required_title", context),
                style: GoogleFonts.quicksand(
                  fontWeight: FontWeight.w700,
                  fontSize: 18.sp,
                ),
              ),
              content: Text(
                Translate.translate("login_required_message", context),
                style: GoogleFonts.quicksand(fontSize: 14.sp),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    // Oturum açma sayfasına yönlendir
                    navigatorKey.currentState?.pushNamed('/onboard');
                  },
                  child: Text(
                    Translate.translate("ok", context),
                    style: GoogleFonts.quicksand(
                      color: MyColors.purple,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ],
            );
          },
        );
        return;
      }

      // Abonelik aktifse paywall acma.
      final hasActiveRevenueCatPremium =
          await RevenueCatService.hasActiveEntitlement();
      if (hasActiveRevenueCatPremium || PremiumService.isPremiumActive(user)) {
        debugPrint("✅ Kullanici zaten abone, paywall acilmadi");
        return;
      }

      debugPrint("💰 Premium paywall açılıyor...");
      // Android'de close butonu gözükmediği için PremiumScreen kullanıyoruz
      if (Platform.isAndroid) {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => PremiumScreen()));
      } else {
        await RevenueCatUI.presentPaywall(displayCloseButton: true);
      }
      debugPrint(
        "💰 Premium paywall kapandı, customerInfo kontrol ediliyor...",
      );

      // Paywall kapandıktan sonra biraz bekle (RevenueCat'in güncellemesi için)
      await Future.delayed(Duration(seconds: 2));

      // Paywall kapandıktan sonra customerInfo'yu manuel kontrol et
      await RevenueCatService.syncCustomerInfo(ref.container);

      // Tekrar kontrol et (bazen gecikme olabilir)
      await Future.delayed(Duration(seconds: 1));
      await RevenueCatService.syncCustomerInfo(ref.container);

      debugPrint("✅ Premium kontrolü tamamlandı");
      /*  Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) => PremiumScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0); // alttan başla
          const end = Offset.zero;         // ekrana gelsin
          const curve = Curves.easeOutCubic;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
    */
    } catch (e) {
      debugPrint("⚠️ Failed to fetch offerings: $e");
      debugPrint("Continuing without premium screen");
      // Hata durumunda premium ekranı gösterme, sadece devam et
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(AllControllers.userController);
    final isPremiumUser = PremiumService.isPremiumActive(user);
    List<ConversationModel> conversations =
        ref.watch(AllControllers.chatViewController).conversations ?? [];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 40.h,top: 40.r).r,
          child: Column(
            children: [
              
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                  ).copyWith(right: 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      appBar(isPremiumUser),
                      SizedBox(height: 15.h),
                      // premium ise öbür card
                      FeelWidget(),
                      SizedBox(height: 15.h),
                      Text(
                        Translate.translate("home_your_matches_title", context),
                        style: GoogleFonts.quicksand(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16.sp,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      YourMatches(),
                      SizedBox(height: 20.h),
          
                      Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: Row(
                          children: [
                            Expanded(child: createCharacterWidget()),
                            SizedBox(width: 10.w),
                            Expanded(child: editCharacterWidget()),
                          ],
                        ),
                      ),
                      SizedBox(height: 20.h),
                      chatWithCyra(conversations),
                      
          
                      if (!isPremiumUser) ...[
                        premiumCard(),
                      ],
          
                      SizedBox(height: 20.h),
          
                      recentagent(),
                    ],
                  ),
                ),
              ),
              if (Platform.isAndroid) ...[SizedBox(height: 20.h)],
          
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget premiumCard() {
    return GestureDetector(
      onTap: () => pushPremium(),
      child: Container(
        
        height: 178.h,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 148.h,
                padding: EdgeInsets.symmetric(horizontal: 15).r,
                margin: EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/premium-bckg.png"),
                    fit: BoxFit.cover,
                  ),
                           border: GradientBoxBorder(
            gradient: LinearGradient(
              colors: [
                Color(0xff3E0951).withValues(alpha: 0.1),
                Color(0xffFFC107),
              ],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
          ),
                  borderRadius: BorderRadius.circular(16).r,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Translate.translate("premium_plan", context),
                            style: GoogleFonts.quicksand(
                              color: Colors.white,
                              fontSize: 24.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          Text(
                            Translate.translate(
                              "home_premium_card_subtitle",
                              context,
                            ),
                            style: GoogleFonts.quicksand(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Container(
                            width: 143.w,
                            height: 32.h,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xffE1A903), Color(0xffC67A00)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(40),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 5.w),
                            child: Center(
                              child: Row(
                                children: [
                                  HeroIcon(
                                    HeroIcons.bolt,
                                    style: HeroIconStyle.solid,
                                    color: Colors.white,
                                    size: 20.w,
                                  ),
                                  SizedBox(width: 7.w),
                                  Text(
                                    Translate.translate(
                                      "upgrade_plan",
                                      context,
                                    ),
                                    style: GoogleFonts.quicksand(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: SizedBox()),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 30).r,
                child: Image.asset(
                  "assets/premium_model.png",
                  height: 300.h,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget editCharacterWidget() {
    return GestureDetector(
      onTap: () {
        navigatorKey.currentState?.pushNamed(
          '/agentsView',
          arguments: {'editFlow': true},
        );
      },
      child: Container(
        height: 120.h,
        padding: EdgeInsets.all(15).r,

        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(16).r,
          color: Colors.black.withValues(alpha: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SvgPicture.asset("assets/icons/edit.svg"),

            Text(
              Translate.translate("home_edit_character_title", context),
              style: GoogleFonts.quicksand(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              Translate.translate("home_edit_character_subtitle", context),
              style: GoogleFonts.quicksand(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget createCharacterWidget() {
    return GestureDetector(
      onTap: () {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const EditAgentView(createFlow: true)),
        );
      },
      child: Container(
        height: 120.h,
        padding: EdgeInsets.all(15).r,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(16).r,
          color: Colors.black.withValues(alpha: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SvgPicture.asset("assets/icons/create-user.svg"),

            Text(
              Translate.translate("home_create_character_title", context),
              style: GoogleFonts.quicksand(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              Translate.translate("home_create_character_subtitle", context),
              style: GoogleFonts.quicksand(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget premiumBuyedCard() {
    return Container(
      height: 153.h,
      padding: EdgeInsets.symmetric(horizontal: 20),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        border: GradientBoxBorder(
          width: 2,
          gradient: LinearGradient(
            colors: [Color(0xffFFD666), Color(0xffFFB200)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        borderRadius: BorderRadius.circular(35),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 20.h, top: 10.h),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: PageView(
                      pageSnapping: false,
                      physics: NeverScrollableScrollPhysics(),
                      allowImplicitScrolling: true,
                      controller: ref
                          .watch(AllControllers.bottomNavbarController.notifier)
                          .pageController,
                      children: ref
                          .read(AllControllers.bottomNavbarController.notifier)
                          .titles(context)
                          .map(
                            (e) => Column(
                              children: [
                                Flexible(
                                  child: Text(
                                    Translate.translate(e.title, context),
                                    style: GoogleFonts.quicksand(
                                      color: Colors.white,
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                  ),
                                ),
                                Text(
                                  Translate.translate(e.subtitle, context),
                                  style: GoogleFonts.quicksand(
                                    color: Colors.white,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),

                  SmoothPageIndicator(
                    controller: ref
                        .watch(AllControllers.bottomNavbarController.notifier)
                        .pageController, // PageController
                    count: ref
                        .read(AllControllers.bottomNavbarController.notifier)
                        .titles(context)
                        .length,
                    axisDirection: Axis.horizontal,
                    effect: ExpandingDotsEffect(
                      dotColor: Colors.white.withValues(alpha: 0.4),
                      activeDotColor: Colors.white,
                      dotWidth: 10.w,
                      dotHeight: 5.h,
                      spacing: 5.w,
                      offset: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Flexible(child: Image.asset("assets/premiumWomen.png")),
        ],
      ),
    );
  }

  String lastMessageConverter(String? value) {
    if (value == null) {
      return Translate.translate("say_hi", context);
    } else if (value == "voice_message") {
      return Translate.translate("voice_message", context);
    } else {
      return value;
    }
  }

  Widget history() {
    List<ConversationModel> conversations =
        ref.watch(AllControllers.chatViewController).conversations ?? [];
    return Padding(
      padding: EdgeInsetsGeometry.symmetric(horizontal: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Translate.translate("history", context),
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontSize: 17.sp,
              fontWeight: FontWeight.w600,
            ),
          ),

          SizedBox(
            width: MediaQuery.sizeOf(context).width,

            child: ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              padding: EdgeInsets.only(top: 20, bottom: 100).r,

              itemCount: conversations.length,
              itemBuilder: (context, index) {
                ConversationModel conversationModel = conversations[index];
                return GestureDetector(
                  onTap: () {
                    // Konuşmaya tıklandığında chat view'a yönlendir
                    if (conversationModel.chatModel != null &&
                        conversationModel.agentModel != null) {
                      ref
                          .read(AllControllers.chatViewController.notifier)
                          .pushFromMessages(
                            conversationModel.chatModel!,
                            conversationModel.agentModel!,
                          );
                    }
                  },
                  child: Container(
                    margin: EdgeInsets.only(bottom: 10),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    width: MediaQuery.sizeOf(context).width,

                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.grey, blurRadius: 1)],
                      borderRadius: BorderRadius.circular(30.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl:
                                        conversationModel
                                            .agentModel
                                            ?.photoURL ??
                                        "https://fakefriend.b-cdn.net/profile.png",
                                    width: 30.w,
                                    height: 30.h,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        Shimmer.fromColors(
                                          baseColor: Colors.grey[300]!,
                                          highlightColor: Colors.grey[100]!,
                                          child: Container(
                                            width: 30.w,
                                            height: 30.h,
                                            color: Colors.white,
                                          ),
                                        ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          width: 30.w,
                                          height: 30.h,
                                          color: Colors.grey[300],
                                          child: Icon(Icons.person, size: 20),
                                        ),
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Text(
                                  conversationModel.agentModel?.name ??
                                      Translate.translate(
                                        "home_agent_fallback_name",
                                        context,
                                      ),
                                  style: GoogleFonts.quicksand(
                                    color: Colors.black,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            /*     GestureDetector(
                        onTap: (){},
                        child: HeroIcon(HeroIcons.ellipsisHorizontal),
                      ) */
                          ],
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          lastMessageConverter(
                            conversationModel.chatModel?.lastMessage,
                          ),
                          style: GoogleFonts.quicksand(
                            color: Colors.black,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (conversationModel.chatModel?.startedAt != null)
                          Text(
                            "${Translate.translate("created_on", context)} ${DateTime.parse(conversationModel.chatModel!.startedAt).day}/${DateTime.parse(conversationModel.chatModel!.startedAt).month}/${DateTime.parse(conversationModel.chatModel!.startedAt).year}",
                            style: GoogleFonts.quicksand(
                              color: Colors.grey,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget chatWithCyra(List<ConversationModel> conversations) {
    return GestureDetector(
      onTap: () {
        final conversations = ref
            .read(AllControllers.chatViewController)
            .conversations;
        final agents = ref.read(AllControllers.agentsViewController).agents;

        if (conversations != null &&
            conversations.isNotEmpty &&
            conversations.first.agentModel != null) {
          ref
              .read(AllControllers.agentsProfileViewController.notifier)
              .startChat(conversations.first.agentModel!);
        } else if (agents != null && agents.isNotEmpty) {
          ref
              .read(AllControllers.agentsProfileViewController.notifier)
              .startChat(agents.last);
        }
      },
      child: Container(
        width: MediaQuery.sizeOf(context).width,
        height: 128.h,
        padding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ).copyWith(left: 20),
        margin: EdgeInsets.only(right: 20).r,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          image: DecorationImage(
            image: AssetImage("assets/premium_bckg.png"),
            fit: BoxFit.cover,
          ),
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16).r,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Builder(
                      builder: (context) {
                        // Konuşma geçmişi kontrolü
                        final conversationsList = ref
                            .watch(AllControllers.chatViewController)
                            .conversations;
                        final hasConversations =
                            conversationsList != null &&
                            conversationsList.isNotEmpty;

                        // Agent adı
                        final agents = ref
                            .watch(AllControllers.agentsViewController)
                            .agents;
                        final agentName =
                            hasConversations &&
                                conversationsList.isNotEmpty &&
                                conversationsList.first.agentModel != null
                            ? conversationsList.first.agentModel!.name
                            : (agents != null && agents.isNotEmpty)
                            ? agents.last.name
                            : Translate.translate(
                                "home_agent_fallback_name",
                                context,
                              );

                        // Doğru key seçimi
                        final translationKey = hasConversations
                            ? "keep_talking_to" // Devam konuşması
                            : TranslateKeys.chatWithName; // İlk konuşma

                        return Text(
                          Translate.translate(
                            translationKey,
                            context,
                          ).replaceAll('%%name%%', agentName),
                          style: GoogleFonts.quicksand(
                            color: Colors.white,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Container(
                    height: 32.h,
                    width: 145.w,
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(40).r,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          "assets/icons/messages-2.svg",
                          width: 16.w,
                        ),
                        SizedBox(width: 5.w,),
                        Text(
                          Translate.translate("home_start_chat_cta", context),
                          style: GoogleFonts.quicksand(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Builder(
              builder: (context) {
                final agents = ref
                    .watch(AllControllers.agentsViewController)
                    .agents;
                final hasAgents = agents != null && agents.isNotEmpty;

                String photoURL = "";
                if (conversations.isNotEmpty &&
                    conversations.first.agentModel != null) {
                  photoURL = conversations.first.agentModel!.photoURL;
                } else if (hasAgents && agents.isNotEmpty) {
                  photoURL = agents.last.photoURL;
                }

                if (photoURL.isEmpty) {
                  return SizedBox(width: 109.w, height: 109.h);
                }

                return Container(
                  width: 86.w,
                  height: 86.h,
                  decoration: BoxDecoration(
                    border: Border.all(width: 2, color: MyColors.purple),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: CachedNetworkImage(
                      imageUrl: photoURL,
                      alignment: Alignment(0, -1),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(color: Colors.white),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: Icon(Icons.person, size: 50),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget historyPlace() {
    final Shader linearGradient = LinearGradient(
      colors: <Color>[Color(0xffDA44bb), Color(0xff8921aa)],
    ).createShader(Rect.fromLTWH(0.0, 0.0, 200.0, 70.0));

    return Container(
      width: MediaQuery.sizeOf(context).width,
      height: 88.h,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(blurRadius: 10, color: Colors.grey.withValues(alpha: 0.4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 10.0),
            width: 37.w,
            height: 37.h,
            decoration: BoxDecoration(
              color: MyColors.purple,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Center(
              child: HeroIcon(
                HeroIcons.bookOpen,
                style: HeroIconStyle.solid,
                color: Colors.white,
              ),
            ),
          ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  Translate.translate("history", context),
                  style: GoogleFonts.quicksand(
                    foreground: Paint()..shader = linearGradient,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  Translate.translate("view_history", context),
                  style: GoogleFonts.quicksand(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: Color(0xffA1A1A1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget newChatPlace() {
    final Shader linearGradient = LinearGradient(
      colors: <Color>[Color(0xffDA44bb), Color(0xff8921aa)],
    ).createShader(Rect.fromLTWH(0.0, 0.0, 200.0, 70.0));

    return GestureDetector(
      onTap: () {
        navigatorKey.currentState?.pushNamed('/agentsView');
      },
      child: Container(
        width: MediaQuery.sizeOf(context).width,
        margin: EdgeInsets.only(right: 10),
        height: 88.h,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(21),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              color: Colors.grey.withValues(alpha: 0.4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              margin: const EdgeInsets.only(right: 10.0),
              width: 37.w,
              height: 37.h,
              decoration: BoxDecoration(
                color: MyColors.purple,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Center(
                child: HeroIcon(
                  HeroIcons.chatBubbleOvalLeft,
                  style: HeroIconStyle.solid,
                  color: Colors.white,
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Translate.translate("new_chat", context),
                      style: GoogleFonts.quicksand(
                        foreground: Paint()..shader = linearGradient,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      Translate.translate("start_new_chat", context),
                      style: GoogleFonts.quicksand(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w500,
                        color: Color(0xffA1A1A1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget characterEdit() {
    final Shader linearGradient = LinearGradient(
      colors: <Color>[Color(0xffDA44bb), Color(0xff8921aa)],
    ).createShader(Rect.fromLTWH(0.0, 0.0, 200.0, 70.0));

    return GestureDetector(
      onTap: () {
        navigatorKey.currentState?.pushNamed(
          '/agentsView',
          arguments: {'editFlow': true},
        );
      },
      child: Container(
        width: MediaQuery.sizeOf(context).width,

        height: 88.h,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(35).r,
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              color: Colors.grey.withValues(alpha: 0.4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 10.0),
                    width: 37.w,
                    height: 37.h,
                    decoration: BoxDecoration(
                      color: MyColors.purple,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Center(
                      child: HeroIcon(
                        HeroIcons.pencil,
                        style: HeroIconStyle.solid,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Translate.translate("characterEdit", context),
                            style: GoogleFonts.quicksand(
                              foreground: Paint()..shader = linearGradient,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            Translate.translate(
                              "edit_character_subtext",
                              context,
                            ),
                            style: GoogleFonts.quicksand(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: Color(0xffA1A1A1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              margin: const EdgeInsets.only(right: 10.0),
              width: 30.w,
              height: 30.h,
              decoration: BoxDecoration(
                color: MyColors.purple,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Center(
                child: HeroIcon(
                  HeroIcons.arrowRight,
                  style: HeroIconStyle.solid,
                  color: Colors.white,
                  size: 15.w,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget recentagent() {
    final recentAgents = ref
        .watch(AllControllers.agentsViewController)
        .recentAgents;
    final isLoading = ref
        .watch(AllControllers.agentsViewController.notifier)
        .loading;

    // Veriler yüklenmemişse veya boşsa kartı gösterme
    if (isLoading || recentAgents == null) {
      return SizedBox.shrink(); // Loading durumunda kartı gösterme
    }

    // Recent agents boşsa kartı gösterme
    if (recentAgents.isEmpty) {
      return SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        //   navigatorKey.currentState?.pushNamed('/agentsView');
      },
      child: Container(
        width: MediaQuery.sizeOf(context).width,

        height: 170.h,
        padding: EdgeInsets.only(top: 10, bottom: 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(35).r,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Translate.translate("recently_added_characters", context),
              style: GoogleFonts.quicksand(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                height: 0,
              ),
            ),

            SizedBox(height: 10.h),

            SizedBox(
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width,
                height: 102.h,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  padding: EdgeInsets.symmetric(
                    horizontal: 30,
                  ).copyWith(left: 0),
                  itemCount: recentAgents.length,
                  separatorBuilder: (context, index) => SizedBox(width: 16.w),
                  itemBuilder: (context, index) {
                    if (index >= recentAgents.length) {
                      return SizedBox.shrink();
                    }
                    AgentModel agent = recentAgents[index];
                    return GestureDetector(
                      onTap: () => ref
                          .read(
                            AllControllers
                                .agentsProfileViewController
                                .notifier,
                          )
                          .startChat(agent),
                      child: SizedBox(
                        height: 120.h,
                        width: 66.w,
                        child: Column(
                          children: [
                            SizedBox(
                              height: 66.h,
                              width: 66.w,
                              child: Stack(
                                children: [
                                  Center(
                                    child: Container(
                                      width: 66.w,
                                      height: 66.h,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          width: 2,
                                          color: MyColors.purple,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          50.r,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: agent.photoURL,
                                          fit: BoxFit.cover,
                                          alignment: Alignment(0, -1),
                                          placeholder: (context, url) =>
                                              Shimmer.fromColors(
                                                baseColor: Colors.grey[300]!,
                                                highlightColor:
                                                    Colors.grey[100]!,
                                                child: Container(
                                                  color: Colors.white,
                                                ),
                                              ),
                                          errorWidget:
                                              (context, url, error) =>
                                                  Container(
                                                    color: Colors.grey[300],
                                                    child: Icon(
                                                      Icons.person,
                                                      size: 30,
                                                    ),
                                                  ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  Align(
                                    alignment: Alignment.topRight,
                                    child: Container(
                                      width: 18.w,
                                      height: 18.h,
                                      padding: EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          40,
                                        ),
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xffAB10E2),
                                            Color(0xff2D30FF),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                      child: Center(
                                        child: FittedBox(
                                          child: Text(
                                            Translate.translate(
                                              "new",
                                              context,
                                            ).toLowerCase(),
                                            style: GoogleFonts.quicksand(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Text(
                              agent.name,
                              style: GoogleFonts.quicksand(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget appBar(isPremiumUser) {
    return Padding(
      padding: const EdgeInsets.only(right: 20).r,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                Translate.translate("home_welcome_user", context).replaceAll(
                  '%%name%%',
                  ref.watch(AllControllers.userController)?.username ??
                      Translate.translate(
                        "home_welcome_fallback_name",
                        context,
                      ),
                ),
                style: GoogleFonts.quicksand(
                  color: Colors.white,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                Translate.translate("home_how_feeling_today", context),
                style: GoogleFonts.quicksand(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

       Row(
        children: [
           if(isPremiumUser)...[
                  GestureDetector(
            onTap: () async {
             
            },
            child: Container(
              width: 32.r,
              height: 32.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Color(0xffDC7AFF)),
                color: Color(0xffDC7AFF).withValues(alpha: 0.2),
              ),
              child: Center(child: Image.asset("assets/icons/king.png",width: 20.w,)),
            ),
          ),

          SizedBox(width: 10.w,),
           ],



          GestureDetector(
            onTap: () async {
              await navigatorKey.currentState?.pushNamed('/notificationsView');
            },
            child: Container(
              width: 32.r,
              height: 32.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                color: Colors.white.withValues(alpha: 0.2),
              ),
              child: Center(child: SvgPicture.asset("assets/icons/bell.svg")),
            ),
          ),
        ],
       )
        ],
      ),
    );
  }
}
