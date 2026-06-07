import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Banner that appears at the top of the dashboard when the JWT is about
/// to expire (within 5 minutes). Tapping it logs the user out so the
/// login screen appears with a fresh token.
class SessionExpiringBanner extends StatelessWidget {
  const SessionExpiringBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final remaining = auth.sessionRemaining;
        if (remaining == null) return const SizedBox.shrink();
        final mins = remaining.inMinutes;
        final label = mins <= 0
            ? 'Session expired in <1 minute'
            : mins == 1
                ? 'Session expires in 1 minute'
                : 'Session expires in $mins minutes';
        final scheme = Theme.of(context).colorScheme;
        return Material(
          color: scheme.errorContainer,
          child: InkWell(
            onTap: () async {
              // Best-effort: clear the session-expired flag and let the
              // existing logout flow run. The login screen will appear
              // automatically via AuthWrapper once the user is null.
              auth.clearSessionRemaining();
              await auth.logout();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please log in again to continue.'),
                  ),
                );
              }
            },
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, color: scheme.onErrorContainer, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: scheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      'Re-login',
                      style: TextStyle(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: scheme.onErrorContainer, size: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Re-export for tests that want to construct an auth provider with the
// session-expiring stream mocked in.
@visibleForTesting
typedef AuthProviderFactory = AuthProvider Function();
