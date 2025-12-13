import 'package:flutter_riverpod/legacy.dart';
import 'package:friendfy/Controllers/ViewControllers/agent_profile_view_controller.dart';
import 'package:friendfy/Controllers/ViewControllers/agents_view_controller.dart';
import 'package:friendfy/Controllers/ViewControllers/bottom_navbar_controller.dart';
import 'package:friendfy/Controllers/ViewControllers/chat_screen_view_controller.dart';
import 'package:friendfy/Controllers/ViewControllers/login_view_controller.dart';
import 'package:friendfy/Controllers/ViewControllers/notifications_view_controller.dart';
import 'package:friendfy/Controllers/ViewControllers/onboard_view_controller.dart';
import 'package:friendfy/Controllers/ViewControllers/profile_settings_view_controller.dart';
import 'package:friendfy/Controllers/ViewControllers/register_view_controller.dart';
import 'package:friendfy/Controllers/ViewControllers/splash_view_controller.dart';
import 'package:friendfy/Controllers/user_controller.dart';
import 'package:friendfy/Models/user_model.dart';


class AllControllers {
  static final splashViewController = StateNotifierProvider<SplashViewController,void>((ref)=> SplashViewController(ref));
  static final loginViewController = StateNotifierProvider<LoginViewController,LoginState>((ref)=> LoginViewController());
  static final onboardViewController = StateNotifierProvider<OnboardViewController,OnboardViewModel>((ref)=> OnboardViewController(ref));
  static final registerViewController = StateNotifierProvider<RegisterViewController,RegisterModel>((ref)=> RegisterViewController(ref));
  static final bottomNavbarController = StateNotifierProvider<BottomNavbarController,BottomNavbarModel>((ref)=> BottomNavbarController());
  static final userController = StateNotifierProvider<UserController,UserModel?>((ref)=> UserController());
  static final agentsViewController = StateNotifierProvider<AgentsViewController,AgentsViewModel>((ref)=> AgentsViewController(ref));
  static final agentsProfileViewController = StateNotifierProvider<AgentProfileViewController,AgentProfileViewModel>((ref)=> AgentProfileViewController(ref));
  static final chatViewController = StateNotifierProvider<ChatScreenViewController,ChatScreenViewModel>((ref)=> ChatScreenViewController(ref));
  static final profileSettingsViewController = StateNotifierProvider<ProfileSettingsViewController,ProfileSettingsViewModel>((ref)=> ProfileSettingsViewController(ref));
  static final notificationsViewController = StateNotifierProvider<NotificationsViewController,NotificationsViewModel>((ref)=> NotificationsViewController(ref));
}