import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Severity levels, ordered so filtering by minimum level is a simple compare.
enum LogLevel { debug, info, warn, error }

/// A single captured log record.
class LogRecord {
  LogRecord(this.level, this.message, {this.error, this.stackTrace})
      : time = DateTime.now();

  final DateTime time;
  final LogLevel level;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  String format() {
    final ts = time.toIso8601String();
    final lvl = level.name.toUpperCase().padRight(5);
    final buffer = StringBuffer('[$ts] $lvl $message');
    if (error != null) buffer.write('\n    error: $error');
    if (stackTrace != null) buffer.write('\n$stackTrace');
    return buffer.toString();
  }
}

/// Lightweight app-wide logger with a rolling on-disk file, so field issues
/// are diagnosable even in release builds (where `debugPrint` is stripped).
///
/// Design goals:
///  - Never throw from a log call (best-effort; failures are swallowed).
///  - Keep a capped in-memory ring buffer for an in-app diagnostics view.
///  - Persist WARN/ERROR to a rotating file under the app support directory.
///  - Serialize writes so concurrent logs don't interleave or race the roll.
class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  static const int _maxBufferEntries = 500;
  static const int _maxFileBytes = 512 * 1024; // 512 KB before rotating
  static const String _logFileName = 'app.log';

  final Queue<LogRecord> _buffer = Queue<LogRecord>();
  File? _logFile;
  bool _initialized = false;
  // Chains file writes so they run one-at-a-time in order.
  Future<void> _writeChain = Future<void>.value();

  /// Snapshot of recent log records (newest last) for an in-app viewer.
  List<LogRecord> get recent => List.unmodifiable(_buffer);

  /// Resolve the log file location. Safe to call multiple times. On web (no
  /// filesystem) the logger stays in-memory only.
  Future<void> init() async {
    if (_initialized || kIsWeb) {
      _initialized = true;
      return;
    }
    _initialized = true;
    try {
      final dir = await getApplicationSupportDirectory();
      final logsDir = Directory(p.join(dir.path, 'logs'));
      if (!logsDir.existsSync()) logsDir.createSync(recursive: true);
      _logFile = File(p.join(logsDir.path, _logFileName));
    } catch (_) {
      // Filesystem unavailable — degrade to in-memory only.
      _logFile = null;
    }
  }

  void debug(String message) => _add(LogLevel.debug, message);
  void info(String message) => _add(LogLevel.info, message);
  void warn(String message, {Object? error, StackTrace? stackTrace}) =>
      _add(LogLevel.warn, message, error: error, stackTrace: stackTrace);
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _add(LogLevel.error, message, error: error, stackTrace: stackTrace);

  void _add(LogLevel level, String message,
      {Object? error, StackTrace? stackTrace}) {
    final record =
        LogRecord(level, message, error: error, stackTrace: stackTrace);

    _buffer.addLast(record);
    while (_buffer.length > _maxBufferEntries) {
      _buffer.removeFirst();
    }

    // Mirror to the console in debug for the usual dev workflow.
    if (kDebugMode) debugPrint(record.format());

    // Persist WARN/ERROR (the diagnostically useful ones) to disk.
    if (level == LogLevel.warn || level == LogLevel.error) {
      _persist(record);
    }
  }

  void _persist(LogRecord record) {
    _writeChain = _writeChain.then((_) async {
      final file = _logFile;
      if (file == null) return;
      try {
        // Rotate when the current file grows past the cap: keep one prior
        // generation as app.log.1 so we never grow unbounded.
        if (file.existsSync() && await file.length() > _maxFileBytes) {
          final rolled = File('${file.path}.1');
          if (rolled.existsSync()) rolled.deleteSync();
          file.renameSync(rolled.path);
        }
        await file.writeAsString('${record.format()}\n',
            mode: FileMode.append, flush: false);
      } catch (_) {
        // Best-effort: never let logging failures surface to the app.
      }
    });
  }
}
