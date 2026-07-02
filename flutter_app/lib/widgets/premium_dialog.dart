import 'package:flutter/material.dart';
import '../utils/responsive.dart';

/// A reusable, premium-styled dialog shell used across the app for
/// create/edit/detail dialogs (books, members, issues, etc.).
///
/// Features:
///  - Smooth scale + fade entrance animation for a polished feel.
///  - A gradient header with an icon badge, title, optional subtitle,
///    optional trailing widget, and a consistent close button.
///  - A scrollable body that flexes to the available height.
///  - A sticky footer for actions (use [PremiumDialogButton] helpers).
///  - Fully responsive width/height/padding via the shared [Responsive].
///
/// Wrap the dialog content like so:
/// ```dart
/// showDialog(
///   context: context,
///   builder: (_) => PremiumDialogShell(
///     icon: Icons.person_add,
///     title: 'Add Member',
///     subtitle: 'Register a new library member',
///     body: MyForm(),
///     actions: [
///       PremiumDialogButton.secondary(label: 'Cancel', onPressed: ...),
///       PremiumDialogButton.primary(label: 'Add', icon: Icons.add, onPressed: ...),
///     ],
///   ),
/// );
/// ```
class PremiumDialogShell extends StatefulWidget {
  const PremiumDialogShell({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.subtitle,
    this.headerTrailing,
    this.actions = const [],
    this.maxWidth = 900,
    this.heightFactor = 0.92,
    this.bodyPadding,
    this.scrollable = true,
    this.onClose,
    this.accentColor,
  });

  /// Icon shown inside the header badge.
  final IconData icon;

  /// Dialog title.
  final String title;

  /// Optional one-line subtitle under the title.
  final String? subtitle;

  /// Optional widget shown on the trailing edge of the header
  /// (before the close button), e.g. a status switch or badge.
  final Widget? headerTrailing;

  /// Main dialog content.
  final Widget body;

  /// Footer action buttons.
  final List<Widget> actions;

  /// Maximum desktop width (clamped responsively for smaller screens).
  final double maxWidth;

  /// Fraction of the available height the dialog may occupy.
  final double heightFactor;

  /// Padding around [body]. Defaults to responsive page padding.
  final EdgeInsetsGeometry? bodyPadding;

  /// Whether the body should be wrapped in a scroll view.
  final bool scrollable;

  /// Called when the close button is tapped. Defaults to popping the route.
  final VoidCallback? onClose;

  /// Optional accent colour for the header gradient/icon. Defaults to the
  /// theme primary.
  final Color? accentColor;

  @override
  State<PremiumDialogShell> createState() => _PremiumDialogShellState();
}

class _PremiumDialogShellState extends State<PremiumDialogShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 260),
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final r = Responsive(context);
    final maxWidth = r.dialogWidth(maxDesktop: widget.maxWidth);
    final maxHeight = r.height * widget.heightFactor;
    final accent = widget.accentColor ?? colorScheme.primary;

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.center,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.symmetric(
            horizontal: r.pagePadding,
            vertical: r.pagePadding * 2,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.18),
                    blurRadius: 40,
                    spreadRadius: -4,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Header(
                    icon: widget.icon,
                    title: widget.title,
                    subtitle: widget.subtitle,
                    trailing: widget.headerTrailing,
                    accent: accent,
                    onClose: widget.onClose ?? () => Navigator.of(context).pop(),
                  ),
                  Flexible(
                    child: widget.scrollable
                        ? SingleChildScrollView(
                            padding: widget.bodyPadding ??
                                EdgeInsets.all(r.pagePadding),
                            child: widget.body,
                          )
                        : Padding(
                            padding: widget.bodyPadding ??
                                EdgeInsets.all(r.pagePadding),
                            child: widget.body,
                          ),
                  ),
                  if (widget.actions.isNotEmpty)
                    _Footer(actions: widget.actions),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.accent,
    required this.onClose,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color accent;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.of(context).size.width < 480;

    return Container(
      padding: EdgeInsets.fromLTRB(
        isCompact ? 16 : 24,
        isCompact ? 14 : 20,
        isCompact ? 8 : 16,
        isCompact ? 14 : 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              accent.withValues(alpha: 0.18),
              colorScheme.surface,
            ),
            Color.alphaBlend(
              accent.withValues(alpha: 0.06),
              colorScheme.surface,
            ),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          bottom: BorderSide(color: accent.withValues(alpha: 0.16)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isCompact ? 10 : 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, Color.lerp(accent, Colors.black, 0.18)!],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: colorScheme.onPrimary,
              size: isCompact ? 20 : 25,
            ),
          ),
          SizedBox(width: isCompact ? 12 : 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                        fontSize: isCompact ? 17 : null,
                        letterSpacing: 0.2,
                      ),
                ),
                if (subtitle != null && !isCompact) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: isCompact ? 6 : 12),
            trailing!,
          ],
          SizedBox(width: isCompact ? 4 : 10),
          _CloseButton(onClose: onClose),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Close',
      child: Material(
        color: colorScheme.surface.withValues(alpha: 0.6),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onClose,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.close_rounded,
              size: 20,
              color: colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.actions});
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.of(context).size.width < 480;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isCompact ? 16 : 24,
        isCompact ? 12 : 16,
        isCompact ? 16 : 24,
        isCompact ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            actions[i],
          ],
        ],
      ),
    );
  }
}

/// Shared premium input decoration so every field/dropdown across all dialogs
/// looks and behaves consistently: soft surface fill, subtle idle border, an
/// accent focus ring, and clear error states.
///
/// Use for `TextFormField`, `TextField`, and `DropdownButtonFormField`.
InputDecoration premiumInputDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  IconData? icon,
  Widget? prefixIcon,
  Widget? suffixIcon,
  Color? accent,
}) {
  final cs = Theme.of(context).colorScheme;
  final a = accent ?? cs.primary;
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefixIcon ??
        (icon != null
            ? Icon(icon, size: 20, color: a.withValues(alpha: 0.75))
            : null),
    suffixIcon: suffixIcon,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    filled: true,
    fillColor: cs.surface,
    border: border(cs.outlineVariant.withValues(alpha: 0.5), 1),
    enabledBorder: border(cs.outlineVariant.withValues(alpha: 0.5), 1),
    focusedBorder: border(a, 1.6),
    errorBorder: border(cs.error.withValues(alpha: 0.6), 1),
    focusedErrorBorder: border(cs.error, 1.6),
    floatingLabelStyle: TextStyle(color: a, fontWeight: FontWeight.w600),
  );
}

/// A soft, slightly-elevated card used to group a form section inside a
/// [PremiumDialogShell], giving dialogs clear visual structure.
class PremiumSectionCard extends StatelessWidget {
  const PremiumSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A consistent section header (icon badge + title) for use inside dialogs.
class PremiumSectionTitle extends StatelessWidget {
  const PremiumSectionTitle({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.primaryContainer,
                cs.primaryContainer.withValues(alpha: 0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: cs.primary),
        ),
        const SizedBox(width: 14),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
        ),
      ],
    );
  }
}

/// Premium footer button used inside [PremiumDialogShell].
class PremiumDialogButton extends StatelessWidget {
  const PremiumDialogButton._({
    required this.label,
    required this.onPressed,
    required this.isPrimary,
    this.icon,
    this.loading = false,
    this.destructive = false,
  });

  /// A filled, gradient primary action button.
  factory PremiumDialogButton.primary({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool loading = false,
    bool destructive = false,
  }) =>
      PremiumDialogButton._(
        label: label,
        onPressed: onPressed,
        isPrimary: true,
        icon: icon,
        loading: loading,
        destructive: destructive,
      );

  /// A subtle, outlined secondary action button.
  factory PremiumDialogButton.secondary({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
  }) =>
      PremiumDialogButton._(
        label: label,
        onPressed: onPressed,
        isPrimary: false,
        icon: icon,
      );

  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final IconData? icon;
  final bool loading;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

    if (!isPrimary) {
      return OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: shape,
          side: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.5),
          ),
          foregroundColor: colorScheme.onSurface,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
        child: _content(colorScheme.onSurface),
      );
    }

    final accent = destructive ? colorScheme.error : colorScheme.primary;
    final enabled = onPressed != null && !loading;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: enabled
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, Color.lerp(accent, Colors.black, 0.18)!],
              )
            : null,
        color: enabled ? null : colorScheme.onSurface.withValues(alpha: 0.12),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
          shape: shape,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : _content(colorScheme.onPrimary),
      ),
    );
  }

  Widget _content(Color color) {
    if (icon == null) {
      return Text(label);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

/// A compact, premium-styled confirmation dialog with an icon badge,
/// title, message, and primary/secondary actions. Use [showPremiumConfirm]
/// for a consistent confirm/cancel experience across the app.
class PremiumConfirmDialog extends StatefulWidget {
  const PremiumConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.help_outline_rounded,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.confirmIcon,
    this.destructive = false,
    this.accentColor,
  });

  final String title;
  final String message;
  final IconData icon;
  final String confirmLabel;
  final String cancelLabel;
  final IconData? confirmIcon;
  final bool destructive;
  final Color? accentColor;

  @override
  State<PremiumConfirmDialog> createState() => _PremiumConfirmDialogState();
}

class _PremiumConfirmDialogState extends State<PremiumConfirmDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 240),
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final r = Responsive(context);
    final accent = widget.accentColor ??
        (widget.destructive ? colorScheme.error : colorScheme.primary);
    final maxWidth = r.dialogWidth(maxDesktop: 420);

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.symmetric(
            horizontal: r.pagePadding,
            vertical: r.pagePadding * 2,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.18),
                    blurRadius: 40,
                    spreadRadius: -4,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accent.withValues(alpha: 0.18),
                            accent.withValues(alpha: 0.06),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(widget.icon, size: 30, color: accent),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              side: BorderSide(
                                color:
                                    colorScheme.outline.withValues(alpha: 0.5),
                              ),
                              foregroundColor: colorScheme.onSurface,
                              textStyle: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                            child: Text(widget.cancelLabel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PremiumDialogButton.primary(
                            label: widget.confirmLabel,
                            icon: widget.confirmIcon,
                            destructive: widget.destructive,
                            onPressed: () =>
                                Navigator.of(context).pop(true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a [PremiumConfirmDialog] and resolves to `true` when confirmed.
Future<bool> showPremiumConfirm({
  required BuildContext context,
  required String title,
  required String message,
  IconData icon = Icons.help_outline_rounded,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  IconData? confirmIcon,
  bool destructive = false,
  Color? accentColor,
  bool barrierDismissible = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => PremiumConfirmDialog(
      title: title,
      message: message,
      icon: icon,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      confirmIcon: confirmIcon,
      destructive: destructive,
      accentColor: accentColor,
    ),
  );
  return result ?? false;
}
