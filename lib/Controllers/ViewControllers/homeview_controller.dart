// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'package:flutter/cupertino.dart';
import 'package:riverpod/legacy.dart';

class HomeviewController extends StateNotifier<HomeViewModel>{
  HomeviewController()
      : super(
          HomeViewModel(
            moods: const [
              Mood(title: "😌 Relaxed", code: "relaxed"),
              Mood(title: "😂 Fun", code: "fun"),
              Mood(title: "💭 Deep", code: "deep"),
              Mood(title: "💪 Bold", code: "bold"),
            ],
            selectedMood: "",
          ),
        );

  void selectMood(String mood){
    state = state.copyWith(selectedMood: mood);
    debugPrint("Selected Mood ${state.selectedMood}");
  }



}


class Mood {
  final String title;
  final String code;
  const Mood({
    required this.title,
    required this.code,
  });

  }

class HomeViewModel {
  final List<Mood> moods;
  final String selectedMood;

  const HomeViewModel({
    required this.moods,
    required this.selectedMood,
  });

  HomeViewModel copyWith({
    List<Mood>? moods,
    String? selectedMood,
  }) {
    return HomeViewModel(
      moods: moods ?? this.moods,
      selectedMood: selectedMood ?? this.selectedMood,
    );
  }
}
