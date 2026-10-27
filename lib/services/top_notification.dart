import 'dart:async';

import 'package:flutter/material.dart';

/// A transient top notice. Only its optional action intercepts pointer events.
/// SnackBar is used as message data; it is never shown by ScaffoldMessenger.
TopNotificationHandle? showTopNotification(
  BuildContext context,
  SnackBar notification, {
  Key? key,
}) {
  if (!context.mounted) return null;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return null;
  _active[overlay]?.dismiss();

  final theme = Theme.of(context);
  final route = ModalRoute.of(context);
  final handle = TopNotificationHandle._();
  final action = notification.action;
  final routeAnimations = Listenable.merge([
    route?.animation,
    route?.secondaryAnimation,
  ]);
  void onRouteChanged() {
    if (!context.mounted || (route != null && !route.isCurrent)) {
      handle.dismiss();
    }
  }

  final entry = OverlayEntry(
    builder: (overlayContext) {
      final media = MediaQuery.of(overlayContext);
      return _NoticeLifetime(
        onDispose: handle.dismiss,
        child: Positioned(
          top: media.padding.top + kToolbarHeight + 8,
          left: media.padding.left + 16,
          right: media.padding.right + 16,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Theme(
                data: theme,
                child: Stack(
                  key: key ?? const ValueKey('top-notification'),
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Material(
                          elevation: 6,
                          color:
                              notification.backgroundColor ??
                              theme.snackBarTheme.backgroundColor ??
                              theme.colorScheme.inverseSurface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: IgnorePointer(
                              child: Semantics(
                                liveRegion: true,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: media.size.height * .3,
                                  ),
                                  child: SingleChildScrollView(
                                    child: DefaultTextStyle(
                                      style:
                                          theme
                                              .snackBarTheme
                                              .contentTextStyle ??
                                          TextStyle(
                                            color: theme
                                                .colorScheme
                                                .onInverseSurface,
                                            fontSize: 14,
                                          ),
                                      child: notification.content,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (action != null) ...[
                            const SizedBox(width: 8),
                            Material(
                              type: MaterialType.transparency,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor:
                                      action.textColor ??
                                      theme.colorScheme.inversePrimary,
                                ),
                                onPressed: () {
                                  handle.dismiss();
                                  action.onPressed();
                                },
                                child: Text(action.label),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  handle._cleanup = () {
    routeAnimations.removeListener(onRouteChanged);
    entry.remove();
    entry.dispose();
    if (_active[overlay] == handle) _active[overlay] = null;
  };
  _active[overlay] = handle;
  overlay.insert(entry);
  routeAnimations.addListener(onRouteChanged);
  handle._timer = Timer(notification.duration, handle.dismiss);
  return handle;
}

final _active = Expando<TopNotificationHandle>();

class TopNotificationHandle {
  TopNotificationHandle._();

  Timer? _timer;
  VoidCallback? _cleanup;

  void dismiss() {
    _timer?.cancel();
    final cleanup = _cleanup;
    _cleanup = null;
    cleanup?.call();
  }
}

class _NoticeLifetime extends StatefulWidget {
  const _NoticeLifetime({required this.onDispose, required this.child});
  final VoidCallback onDispose;
  final Widget child;

  @override
  State<_NoticeLifetime> createState() => _NoticeLifetimeState();
}

class _NoticeLifetimeState extends State<_NoticeLifetime> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
