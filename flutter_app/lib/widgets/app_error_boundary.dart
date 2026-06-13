import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Wraps the app so that any uncaught Flutter framework error and any
/// unhandled async error shows a friendly error screen instead of crashing
/// the app. Reports the error to the [FlutterError.onError] handler for
/// normal logging in debug mode.
class AppErrorBoundary extends StatefulWidget {
  const AppErrorBoundary({super.key, required this.child});

  final Widget child;

  @override
  State<AppErrorBoundary> createState() => _AppErrorBoundaryState();
}

class _AppErrorBoundaryState extends State<AppErrorBoundary> {
  Object? _error;
  StackTrace? _stack;

  @override
  void initState() {
    super.initState();
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      if (!mounted || !kDebugMode) return;
      // Defer the setState to a post-frame callback. Calling it inside
      // the onError handler fires while a build/layout pass is in
      // progress, which the framework treats as
      // "setState() or markNeedsBuild() called during build". The
      // error boundary's own rebuild then cascades and triggers
      // more mouse-tracker / RenderBox errors. Deferring lets the
      // current frame finish cleanly.
      final ex = details.exception;
      final st = details.stack;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _error = ex;
          _stack = st;
        });
      });
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _ErrorScreen(
        error: _error!,
        stack: _stack,
        onRetry: () => setState(() {
          _error = null;
          _stack = null;
        }),
      );
    }
    return widget.child;
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({
    required this.error,
    required this.stack,
    required this.onRetry,
  });

  final Object error;
  final StackTrace? stack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
