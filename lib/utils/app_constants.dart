import 'package:flutter/material.dart';
import 'package:friendfy/View/AccountCreatedView/account_created_view.dart';
import 'package:friendfy/View/AccountDeletedView/account_deleted_view.dart';
import 'package:friendfy/View/AgentProfileView/agent_profile_view.dart';
import 'package:friendfy/View/AgentsScreen/agents_screen.dart';
import 'package:friendfy/View/BottomNavBarView/bottom_navbar_view.dart';
import 'package:friendfy/View/ChatView/chat_view.dart';
import 'package:friendfy/View/EditAgentView/edit_agent_view.dart';
import 'package:friendfy/View/FaqView/faq_view.dart';
import 'package:friendfy/View/LoginView/login_view.dart';
import 'package:friendfy/View/NotificationsView/notifications_view.dart';
import 'package:friendfy/View/OnboardView/onboard_view.dart';
import 'package:friendfy/View/ProfileSettings/profile_settings.dart';
import 'package:friendfy/View/RegisterView/register_view.dart';
import 'package:friendfy/View/ServerErrorPage/server_error_view.dart';
import 'package:friendfy/View/StartView/start_view.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:friendfy/AppLocalizations/app_localizations.dart';


class AppConstants {
  static const String appName = "friendfy";
// 10.0.2.2:
 
  static const String baseURL = "http://localhost:3000";
  // "http://localhost:3000";
  // "https://friendfy.fly-work.com"
  static const String configURL = "/server/config"; 
  static const String loginURL = "/auth/login"; 
  static const String signupURL = "/auth/signup"; 
  static const String verifyTokenURL = "/auth/verify-token"; 
  static const String checkMailURL = "/auth/check-mail";
  static const String updateProfileURL = "/auth/update-profile";
  static const String deleteAccountURL = "/auth/delete-account"; 
  static const String guestLoginURL = "/auth/guest-login"; // Misafir giriş
  static const String verifyReceiptURL = "/purchases/verify-receipt"; // Apple Receipt Validation
  static const String updatePremiumURL = "/auth/update-premium"; // Premium güncelleme


  // middleware
  static const String systemAgents = "/agent/get-system-agents"; 
  static const String recentAgents = "/agent/get-recent-bots"; 
  static const String userAgents = "/agent/get-user-agents"; 
  static const String getAgent = "/agent/get-agent-data"; 
  static const String createCustomAgent = "/agent/create-custom-agent"; 
  static const String updateAgent = "/agent/update-agent";
  static const String deleteAgent = "/agent/delete-agent"; 
  static const String createChat = "/chat/create-chat"; 
  static const String sendMessage = "/chat/send-message"; 
  static const String sendAudioMessage = "/chat/send-audio-message"; 
  static const String sendImageMessage = "/chat/send-image-message"; 
  static const String getMessage = "/chat/get-messages"; 
  static const String getConversations = "/chat/get-conversations"; 
  static const String searchConversations = "/chat/search-conversations"; 
  static const String listenMessage = "/chat/listen-messages"; 
  static const String reportConversation = "/chat/report-conversation"; 
  static const String deleteConversation = "/chat/delete-conversation"; 

  /// İlgi alanları (herkese açık, kimlik gerekmez)
  static const String interestsListLocalized = "/interests/list-localized";


static List<Locale> supportedLocales = const[
  Locale('en','US'),
  Locale('tr','TR'),
];


 static Iterable<LocalizationsDelegate<dynamic>>  localizationsDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
];



static Map<String, Widget Function(BuildContext)> routes = {
'/onboard' : (_) => OnboardView(),
'/start': (_)=> StartView(),
'/login': (_) => LoginView(),
'/register': (_) => RegisterView(),
'/bottomNavbar': (_) => BottomNavbarView(),
'/agentsView': (_) => AgentsScreen(),
'/agentDetails': (_)=> AgentProfileView(),
'/editAgentView': (_)=> EditAgentView(),
'/chatView': (_)=> ChatView(),
'/serverError': (_)=> ServerErrorView(),
'/profileSettings': (_)=> ProfileSettings(),
'/faqView': (_)=> FaqView(),
'/accountDeletedView': (_) => AccountDeletedView(),
'/accountCreatedView': (_) => const AccountCreatedView(),
'/notificationsView': (_) => NotificationsView(),
};


}


class NavigationKey{
  static String onboard = "/onboard";

}