import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../models/notification.dart';
import '../utils/date_formatter.dart';
import '../utils/hindi_text.dart';
import '../utils/theme.dart';
import 'premium_dialog.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _swing;
  late final Animation<double> _badgePop;

  /// Tracks the last seen unread count so we only react when it *increases*
  /// (i.e. a genuinely new notification arrived), not on every rebuild.
  int? _lastCount;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    // A decaying "ring" swing: the bell rocks back and forth and settles.
    _swing = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.32), weight: 12),
      TweenSequenceItem(tween: Tween(begin: -0.32, end: 0.28), weight: 16),
      TweenSequenceItem(tween: Tween(begin: 0.28, end: -0.22), weight: 16),
      TweenSequenceItem(tween: Tween(begin: -0.22, end: 0.16), weight: 16),
      TweenSequenceItem(tween: Tween(begin: 0.16, end: -0.08), weight: 14),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.0), weight: 14),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _badgePop = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
      TweenSequenceItem(
        tween: Tween(begin: 1.35, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Called after each build with the current unread count. Fires the ring
  /// animation + chime whenever the count grows.
  void _handleCount(int count) {
    final prev = _lastCount;
    _lastCount = count;
    if (prev != null && count > prev) {
      if (mounted) _controller.forward(from: 0);
      _playChime();
    }
  }

  Future<void> _playChime() async {
    // Lightweight, dependency-free notification sound. Uses the platform's
    // system alert sound (MessageBeep on Windows). Best-effort only.
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      // Never let a sound failure disrupt the UI.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, _) {
        final unreadCount = notificationProvider.unreadCount;
        final cs = Theme.of(context).colorScheme;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _handleCount(unreadCount);
        });

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () => _showNotificationsPanel(context),
              icon: AnimatedBuilder(
                animation: _swing,
                builder: (context, child) => Transform.rotate(
                  angle: _swing.value,
                  alignment: Alignment.topCenter,
                  child: child,
                ),
                child: Icon(
                  unreadCount > 0
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: cs.primary,
                ),
              ),
              tooltip: unreadCount > 0
                  ? 'Notifications, $unreadCount unread'
                  : 'Notifications',
            ),
            if (unreadCount > 0)
              Positioned(
                right: 4,
                top: 4,
                child: ScaleTransition(
                  scale: _badgePop,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showNotificationsPanel(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const NotificationsDialog(),
    );
  }
}

class NotificationsDialog extends StatefulWidget {
  const NotificationsDialog({super.key});

  @override
  State<NotificationsDialog> createState() => _NotificationsDialogState();
}

class _NotificationsDialogState extends State<NotificationsDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationProvider>().refresh(silent: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final cs = Theme.of(context).colorScheme;
    final unread = provider.unreadCount;
    final total = provider.notifications.length;

    return PremiumDialogShell(
      icon: Icons.notifications_rounded,
      title: 'Notifications',
      subtitle: unread > 0
          ? '$unread unread of $total'
          : (total > 0 ? "You're all caught up" : 'No notifications yet'),
      maxWidth: 480,
      scrollable: false,
      bodyPadding: EdgeInsets.zero,
      headerTrailing:
          unread > 0 ? _buildMarkAllButton(context, provider, cs) : null,
      body: _buildBody(context, provider, cs),
      actions: [
        PremiumDialogButton.secondary(
          label: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildMarkAllButton(
    BuildContext context,
    NotificationProvider provider,
    ColorScheme cs,
  ) {
    return Material(
      color: cs.surface.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => provider.markAllAsRead(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.done_all_rounded, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                'Mark all read',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    NotificationProvider provider,
    ColorScheme cs,
  ) {
    if (provider.isLoading && provider.notifications.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (provider.notifications.isEmpty) {
      return _buildEmptyState(context, cs);
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 460),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: provider.notifications.length,
        separatorBuilder: (context, index) => const SizedBox(height: 2),
        itemBuilder: (context, index) {
          final notification = provider.notifications[index];
          return NotificationTile(
            notification: notification,
            onMarkAsRead: () => provider.markAsRead(notification.id),
            onDelete: () => provider.deleteNotification(notification.id),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary.withValues(alpha: 0.15),
                  cs.primary.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Icon(
              Icons.notifications_off_rounded,
              size: 48,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No notifications',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            "You're all caught up!",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onMarkAsRead;
  final VoidCallback onDelete;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onMarkAsRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    final cs = Theme.of(context).colorScheme;
    final accent = _getNotificationColor(context, notification.type);

    return Dismissible(
      key: Key('notification_${notification.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: cs.error,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Material(
          color: isUnread ? accent.withValues(alpha: 0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: isUnread ? onMarkAsRead : null,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isUnread
                      ? accent.withValues(alpha: 0.28)
                      : cs.outlineVariant.withValues(alpha: 0.25),
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Colored left accent bar (only for unread)
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: isUnread ? accent : Colors.transparent,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getNotificationIcon(notification.type),
                                color: accent,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Builder(
                                          builder: (context) {
                                            final displayTitle =
                                                normalizeHindiForDisplay(
                                              notification.title,
                                            );
                                            return Text(
                                              displayTitle,
                                              style: hindiAwareTextStyle(
                                                context,
                                                text: displayTitle,
                                                base: TextStyle(
                                                  fontWeight: isUnread
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            );
                                          },
                                        ),
                                      ),
                                      if (isUnread)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: accent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Builder(
                                    builder: (context) {
                                      final displayMessage =
                                          normalizeHindiForDisplay(
                                        notification.message,
                                      );
                                      return Text(
                                        displayMessage,
                                        style: hindiAwareTextStyle(
                                          context,
                                          text: displayMessage,
                                          base: TextStyle(
                                            fontSize: 13,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.color,
                                          ),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.schedule_rounded,
                                        size: 12,
                                        color: cs.onSurface
                                            .withValues(alpha: 0.45),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatTimestamp(
                                          notification.createdAt,
                                        ),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurface
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert,
                                size: 18,
                                color:
                                    cs.onSurface.withValues(alpha: 0.5),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              itemBuilder: (context) => [
                                if (isUnread)
                                  const PopupMenuItem(
                                    value: 'read',
                                    child: Row(
                                      children: [
                                        Icon(Icons.check, size: 18),
                                        SizedBox(width: 8),
                                        Text('Mark as read'),
                                      ],
                                    ),
                                  ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete,
                                          size: 18, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete',
                                          style:
                                              TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'read') onMarkAsRead();
                                if (value == 'delete') onDelete();
                              },
                            ),
                          ],
                        ),
                      ),
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

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'overdue':
        return Icons.warning_amber_rounded;
      case 'due_soon':
        return Icons.access_time_rounded;
      case 'new_book':
        return Icons.menu_book_rounded;
      case 'return':
        return Icons.assignment_return_rounded;
      case 'issue':
        return Icons.assignment_rounded;
      case 'system':
        return Icons.settings_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _getNotificationColor(BuildContext context, String type) {
    final sem = context.semantic;
    switch (type) {
      case 'overdue':
        return sem.danger;
      case 'due_soon':
        return sem.warning;
      case 'new_book':
        return sem.success;
      case 'return':
        return sem.info;
      case 'issue':
        return Colors.purple; // categorical, not a status state
      case 'system':
        return Colors.grey;
      default:
        return sem.info;
    }
  }

  String _formatTimestamp(String createdAtStr) {
    if (createdAtStr.isEmpty || createdAtStr == 'null') return '';
    try {
      final parsed = DateTime.tryParse(createdAtStr);
      if (parsed == null) return createdAtStr;

      final dateTime = parsed.isUtc ? parsed.toLocal() : parsed;
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.isNegative) {
        return DateFormatter.formatDateTimeIndian(dateTime.toIso8601String());
      }

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormatter.formatDateTimeIndian(dateTime.toIso8601String());
      }
    } catch (_) {
      return createdAtStr;
    }
  }
}
