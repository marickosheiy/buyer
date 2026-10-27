import 'top_notification.dart';

import 'package:flutter/material.dart';

Future<bool> runBuyerAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } catch (e) {
    if (context.mounted) {
      showTopNotification(context, SnackBar(content: Text(e.toString())));
    }
    return false;
  }
}
