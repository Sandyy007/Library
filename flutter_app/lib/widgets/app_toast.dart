import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// The kind of toast, which drives its accent color and icon.
enum ToastType { success, error, warning, info }

/// A branded, app-wide toast/snackbar system.
///
/// Replaces the default `ScaffoldMessenger.showSnackBar(SnackBar(content:...))`
/// pattern with a consistent, premium-looking notification: a rounded elevated
/// card with a colored left accent bar, a tinted icon badge, an optional title,
/// the message, and a dismiss button. Colors adapt to light/dark via the
/// app's semantic color tokens.
///
/// Usage:
/// ```dart
/// AppToast.success(context, 'Book added successfully');
/// AppToast.error(context, 'Could not save member');
/// ```
class AppToast {
  const AppToast._();

  static void success(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
  }) =>
      show(context,
          message: message,
          type: ToastType.success,
          title: title,
          duration: duration);

  static void error(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
  }) =>
      show(context,
          message: message,
          type: ToastType.error,
          title: title,
          duration: duration);

  static void warning(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
  }) =>
      show(context,
          message: message,
          type: ToastType.warning,
          title: title,
          duration: duration);

  static void info(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
  }) =>
      show(context,
          message: message,
          type: ToastType.info,
          title: title,
          duration: duration);

  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    String? title,
    Duration? duration,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    showOnMessenger(
      messenger,
      message: message,
      type: type,
      title: title,
      duration: duration,
    );
  }

  /// Show a toast using a previously captured [ScaffoldMessengerState].
  ///
  /// Useful when the originating widget (e.g. a dialog) is popped before the
  /// toast is shown: capture the messenger *before* the `await`, then call
  /// this so the toast still appears on the parent scaffold.
  static void showOnMessenger(
    ScaffoldMessengerState messenger, {
    required String message,
    ToastType type = ToastType.info,
    String? title,
    Duration? duration,
  }) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        width: 460,
        padding: EdgeInsets.zero,
        duration: duration ??
            (type == ToastType.error
                ? const Duration(seconds: 5)
                : const Duration(seconds: 3)),
        content: _ToastCard(
          message: message,
          title: title,
          type: type,
          onClose: messenger.hideCurrentSnackBar,
        ),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({
    required this.message,
    required this.title,
    required this.type,
    required this.onClose,
  });

  final String message;
  final String? title;
  final ToastType type;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sem = context.semantic;
    final (accent, icon) = switch (type) {
      ToastType.success => (sem.success, Icons.check_circle_rounded),
      ToastType.error => (sem.danger, Icons.error_rounded),
      ToastType.warning => (sem.warning, Icons.warning_amber_rounded),
      ToastType.info => (sem.info, Icons.info_rounded),
    };
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        isDark ? const Color(0xFF262836) : Colors.white;

    return TweenAnimationBuilder<double>(
      duration: AppDurations.normal,
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 12),
          child: child,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: isDark ? 0.4 : 0.18),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: accent),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accent, size: 22),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null && title!.isNotEmpty) ...[
                          Text(
                            title!,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          message,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.8),
                              ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: onClose,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
