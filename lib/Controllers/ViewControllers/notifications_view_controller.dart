// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:friendfy/Models/notification_model.dart';

class NotificationsViewController extends StateNotifier<NotificationsViewModel>{
  Ref? ref;
  NotificationsViewController(this.ref) : super(NotificationsViewModel(notifications: []));
}



class NotificationsViewModel {
  final List<NotificationModel>? notifications;
  final ScreenState screenState;

  NotificationsViewModel({this.notifications, this.screenState = ScreenState.normal});
  

  NotificationsViewModel copyWith({
    List<NotificationModel>? notifications,
    ScreenState? screenState,
  }) {
    return NotificationsViewModel(
      notifications:  notifications ?? this.notifications,
      screenState:  screenState ?? this.screenState,
    );
  }
}


enum ScreenState{
  loading,
  normal
}