// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/View/AgentsScreen/agents_screen.dart';
import 'package:friendfy/View/HomeView/home_view.dart';
import 'package:friendfy/View/MessagesView/messages_view.dart';
import 'package:friendfy/View/ProfileView/profile_view.dart';

class BottomNavbarController extends StateNotifier<BottomNavbarModel> {
  BottomNavbarController() : super(BottomNavbarModel(currentIndex: 0));

  List<Widget> pages = [
    HomeView(),
    AgentsScreen(embeddedInBottomNav: true),
    MessagesView(),
    ProfileView(),
  ];

  updateIndex(int newIndex) {
    state = state.copyWith(currentIndex: newIndex);
  }

  List<PremiumCardModel> titles(BuildContext context) => [
    PremiumCardModel(
      Translate.translate("premium_advantage", context),
      Translate.translate("premium_advantage_subtitle", context),
    ),
    PremiumCardModel(
      Translate.translate("unlimited_conversation", context),
      Translate.translate("unlimited_conversation_subtitle", context),
    ),
    PremiumCardModel(
      Translate.translate("create_new_friends", context),
      Translate.translate("create_new_friends_subtitle", context),
    ),
  ];
  PageController pageController = PageController();
  int index = 0;

  nextPage(BuildContext context) async {
    if (!pageController.hasClients) {
      debugPrint("BottomNavbar pageController not attached yet");
      return;
    }

    if (index != 2) {
      index = index + 1;
      pageController.nextPage(
        duration: Duration(milliseconds: 500),
        curve: Curves.ease,
      );
    } else {
      index = 0;
      pageController.jumpToPage(0);
    }
    debugPrint("Index: $index");
  }
}

class PremiumCardModel {
  final String title;
  final String subtitle;

  PremiumCardModel(this.title, this.subtitle);
}

class BottomNavbarModel {
  final int currentIndex;
  BottomNavbarModel({required this.currentIndex});

  BottomNavbarModel copyWith({int? currentIndex}) {
    return BottomNavbarModel(currentIndex: currentIndex ?? this.currentIndex);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'currentIndex': currentIndex};
  }

  factory BottomNavbarModel.fromMap(Map<String, dynamic> map) {
    return BottomNavbarModel(currentIndex: map['currentIndex'] as int);
  }

  String toJson() => json.encode(toMap());

  factory BottomNavbarModel.fromJson(String source) =>
      BottomNavbarModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() => 'BottomNavbarModel(currentIndex: $currentIndex)';

  @override
  bool operator ==(covariant BottomNavbarModel other) {
    if (identical(this, other)) return true;

    return other.currentIndex == currentIndex;
  }

  @override
  int get hashCode => currentIndex.hashCode;
}
