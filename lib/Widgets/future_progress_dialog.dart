import 'package:flutter/material.dart';

Future<T> showFutureProgressDialog<T>({
  required BuildContext context,
  required Future<T> Function() action,
  String? message,
  bool useRootNavigator = true,
}) async {
  if (!context.mounted) {
    return action();
  }

  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final Route<void> progressRoute = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.30),
    builder: (ctx) => PopScope(
      canPop: false,
      child: Center(child: const CircularProgressIndicator.adaptive()),
    ),
  );
  navigator.push(progressRoute);

  try {
    final result = await action();
    _dismissProgressRouteSafely(navigator, progressRoute);
    return result;
  } catch (_) {
    _dismissProgressRouteSafely(navigator, progressRoute);
    rethrow;
  }
}

void _dismissProgressRouteSafely(
  NavigatorState navigator,
  Route<void> progressRoute,
) {
  if (!navigator.mounted) return;
  if (progressRoute.navigator != navigator) return;
  navigator.removeRoute(progressRoute);
}

extension FutureProgressDialogExtension on BuildContext {
  Future<T> runWithProgressDialog<T>(
    Future<T> Function() action, {
    String? message,
    bool useRootNavigator = true,
  }) {
    return showFutureProgressDialog<T>(
      context: this,
      action: action,
      message: message,
      useRootNavigator: useRootNavigator,
    );
  }
}
