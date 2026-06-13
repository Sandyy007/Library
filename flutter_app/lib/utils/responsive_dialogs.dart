import 'package:flutter/material.dart';
import 'responsive.dart';

/// Responsive dialog utilities for consistent sizing across screen sizes.
/// 
/// These helpers ensure dialogs are properly sized based on screen dimensions
/// and maintain good UX on all device types.

/// Responsive dialog wrapper with standardized sizing
class ResponsiveDialog extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final double? maxHeight;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? backgroundColor;

  const ResponsiveDialog({
    super.key,
    required this.child,
    this.maxWidth,
    this.maxHeight,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive(context);
    final effectiveMaxWidth = maxWidth ?? responsive.dialogWidth();
    final effectiveMaxHeight = maxHeight ?? (responsive.height * 0.85);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      backgroundColor: backgroundColor,
      insetAnimationDuration: const Duration(milliseconds: 300),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: effectiveMaxWidth,
          maxHeight: effectiveMaxHeight,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Responsive alert dialog with consistent sizing
class ResponsiveAlertDialog extends StatelessWidget {
  final String title;
  final Widget? content;
  final List<Widget>? actions;
  final ScrollConfiguration? scrollConfiguration;
  final EdgeInsetsGeometry contentPadding;

  const ResponsiveAlertDialog({
    super.key,
    required this.title,
    this.content,
    this.actions,
    this.scrollConfiguration,
    this.contentPadding = const EdgeInsets.fromLTRB(24, 20, 24, 0),
  });

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive(context);

    return AlertDialog(
      title: Text(title),
      content: content,
      actions: actions,
      contentPadding: contentPadding,
      insetPadding: EdgeInsets.symmetric(
        horizontal: responsive.pagePadding,
        vertical: responsive.pagePadding * 2,
      ),
    );
  }
}

/// Responsive confirmation dialog
class ResponsiveConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final Color? confirmColor;
  final bool isDestructive;

  const ResponsiveConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    required this.onConfirm,
    this.onCancel,
    this.confirmColor,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveAlertDialog(
      title: title,
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onCancel?.call();
          },
          child: Text(cancelText),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor ?? (isDestructive ? Colors.red : null),
            foregroundColor: isDestructive ? Colors.white : null,
          ),
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          child: Text(confirmText),
        ),
      ],
    );
  }
}

/// Responsive dialog content builder for custom layouts
class ResponsiveDialogContent extends StatelessWidget {
  final String? title;
  final Widget? body;
  final List<Widget>? actions;
  final bool scrollable;
  final EdgeInsetsGeometry contentPadding;
  final EdgeInsetsGeometry actionsPadding;

  const ResponsiveDialogContent({
    super.key,
    this.title,
    this.body,
    this.actions,
    this.scrollable = true,
    this.contentPadding = const EdgeInsets.all(24),
    this.actionsPadding = const EdgeInsets.fromLTRB(24, 8, 24, 16),
  });

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: responsive.pagePadding),
        ],
        if (body != null)
          Flexible(
            child: scrollable
                ? SingleChildScrollView(
                    child: Padding(
                      padding: contentPadding,
                      child: body,
                    ),
                  )
                : Padding(
                    padding: contentPadding,
                    child: body,
                  ),
          ),
        if (actions != null && actions!.isNotEmpty) ...[
          SizedBox(height: responsive.pagePadding / 2),
          Padding(
            padding: actionsPadding,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions!
                    .expand(
                      (action) => [
                        action,
                        SizedBox(width: responsive.pagePadding / 2),
                      ],
                    )
                    .toList()
                  ..removeLast(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Helper function to show responsive dialogs
Future<T?> showResponsiveDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  RouteSettings? routeSettings,
}) {
  return showDialog<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.5),
    routeSettings: routeSettings,
  );
}

/// Helper function to show responsive confirmation dialog
Future<bool> showResponsiveConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
  Color? confirmColor,
  bool isDestructive = false,
}) {
  return showResponsiveDialog<bool>(
    context: context,
    builder: (context) => ResponsiveConfirmDialog(
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      confirmColor: confirmColor,
      isDestructive: isDestructive,
      onConfirm: () {},
      onCancel: () {},
    ),
  ).then((result) => result ?? false);
}
