import 'package:flutter/material.dart';
import 'package:friendfy/View/VideoCallView/videocall_view.dart';
import 'package:friendfy/View/VoiceCallView/voice_call_view.dart';
import 'package:friendfy/main.dart';

/// Arama ekranlarına animasyonsuz, anında geçiş.
Future<T?> pushInstantVideoCall<T>() {
  final navigator = navigatorKey.currentState;
  if (navigator == null) return Future.value(null);
  return navigator.push<T>(_instantRoute(const VideocallView()));
}

Future<T?> pushInstantVoiceCall<T>({int? consultantId}) {
  final navigator = navigatorKey.currentState;
  if (navigator == null) return Future.value(null);
  return navigator.push<T>(
    _instantRoute(VoiceCallView(consultantId: consultantId)),
  );
}

PageRouteBuilder<T> _instantRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    transitionsBuilder: (_, __, ___, child) => child,
  );
}
