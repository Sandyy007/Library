import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Service to manage the backend Node.js server lifecycle.
/// Starts the backend automatically when the app runs and stops it on exit.
class BackendService {
  static Process? _backendProcess;
  static bool _isStarting = false;
  static bool _isRunning = false;

  /// PID of a backend we didn't spawn ourselves but adopted (it was already
  /// listening on the port when we launched). Read from the backend's PID file
  /// so we can still terminate it on exit and avoid leaving an orphan holding
  /// the port for the next launch.
  static int? _adoptedPid;

  /// Path to the PID file the backend writes on boot (see server.ts).
  static String _pidFilePath() => p.join(_getBackendPath(), '.backend.pid');

  /// Reads the backend PID from the PID file, if present and valid.
  static int? _readPidFile() {
    try {
      final f = File(_pidFilePath());
      if (!f.existsSync()) return null;
      final pid = int.tryParse(f.readAsStringSync().trim());
      return (pid != null && pid > 0) ? pid : null;
    } catch (_) {
      return null;
    }
  }

  /// Removes the PID file. On Windows a force-terminate doesn't let the backend
  /// run its own cleanup, so the app deletes the stale file after stopping.
  static void _deletePidFile() {
    try {
      final f = File(_pidFilePath());
      if (f.existsSync()) f.deleteSync();
    } catch (_) {
      // Best-effort.
    }
  }

  /// Path to the shutdown sentinel file. Creating it asks the backend to shut
  /// down gracefully — the universal trigger that works even for a backend we
  /// adopted from a previous run (which has no stdin pipe we can write to).
  static String _shutdownFilePath() =>
      p.join(_getBackendPath(), '.backend.shutdown');

  /// Ask the backend to shut down gracefully by creating the sentinel file.
  static void _writeShutdownFile() {
    try {
      File(_shutdownFilePath()).writeAsStringSync('stop');
    } catch (e) {
      debugPrint('Could not write shutdown sentinel: $e');
    }
  }

  /// Remove the shutdown sentinel. Called on startup (so a stale sentinel from
  /// a crashed run doesn't immediately kill the fresh backend) and after stop.
  static void _deleteShutdownFile() {
    try {
      final f = File(_shutdownFilePath());
      if (f.existsSync()) f.deleteSync();
    } catch (_) {
      // Best-effort.
    }
  }

  /// Check if the backend is already running on the specified port
  static Future<bool> isBackendRunning({int port = 3000}) async {
    try {
      final socket = await Socket.connect('localhost', port,
          timeout: const Duration(seconds: 2));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get the backend directory path relative to the executable
  static String _getBackendPath() {
    // In release mode, backend is bundled with the app
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final releasePath = p.join(exeDir, 'backend');
    
    // Check if backend exists in release location
    if (Directory(releasePath).existsSync()) {
      return releasePath;
    }
    
    // In debug mode, try the project structure
    final debugPath = p.normalize(p.join(Directory.current.path, '..', 'backend'));
    if (Directory(debugPath).existsSync()) {
      return debugPath;
    }
    
    // Also try current directory's parent backend folder
    final altPath = p.normalize(p.join(exeDir, '..', '..', '..', '..', '..', '..', 'backend'));
    if (Directory(altPath).existsSync()) {
      return altPath;
    }
    
    // Return release path as fallback
    return releasePath;
  }

  /// Start the backend server if not already running
  static Future<bool> startBackend() async {
    if (_isStarting) {
      debugPrint('Backend is already starting...');
      return false;
    }

    // A stale shutdown sentinel (left by a crash/hard-kill) would make a
    // freshly started backend terminate itself immediately. Clear it before we
    // start or adopt anything. (The backend also clears it on boot as a
    // belt-and-suspenders measure.)
    _deleteShutdownFile();

    // Check if backend is already running
    if (await isBackendRunning()) {
      debugPrint('Backend is already running on port 3000');
      _isRunning = true;
      // Adopt the existing instance's PID (written by the backend on boot) so
      // we can stop it on exit — otherwise a leftover process would keep
      // holding the port after the app closes.
      _adoptedPid = _readPidFile();
      if (_adoptedPid != null) {
        debugPrint('Adopted existing backend PID: $_adoptedPid');
      }
      return true;
    }

    _isStarting = true;

    try {
      final backendPath = _getBackendPath();
      final serverJsPath = p.join(backendPath, 'server.js');
      final envPath = p.join(backendPath, '.env');

      // Check if server.js exists
      if (!File(serverJsPath).existsSync()) {
        debugPrint('Backend server.js not found at: $serverJsPath');
        _isStarting = false;
        return false;
      }

      // Ensure .env file exists with proper configuration
      await _ensureEnvFile(envPath);

      debugPrint('Starting backend from: $backendPath');

      // Prefer a portable Node bundled with the app (backend/node/node.exe) so
      // the installed app doesn't require a system-wide Node.js. Falls back to
      // 'node' on PATH when no bundled runtime is shipped.
      final bundledNode = p.join(backendPath, 'node', 'node.exe');
      final nodeExecutable = File(bundledNode).existsSync() ? bundledNode : 'node';
      debugPrint('Using Node executable: $nodeExecutable');

      // Start the Node.js server
      _backendProcess = await Process.start(
        nodeExecutable,
        ['server.js'],
        workingDirectory: backendPath,
        mode: ProcessStartMode.detachedWithStdio,
        environment: {
          ...Platform.environment,
          'NODE_ENV': 'production',
        },
      );

      // Listen to stdout for debugging
      _backendProcess!.stdout.listen((data) {
        debugPrint('Backend: ${String.fromCharCodes(data).trim()}');
      });

      // Listen to stderr for errors
      _backendProcess!.stderr.listen((data) {
        debugPrint('Backend Error: ${String.fromCharCodes(data).trim()}');
      });

      // Wait a moment for the server to start
      await Future.delayed(const Duration(seconds: 2));

      // Verify the backend is running
      final running = await isBackendRunning();
      if (running) {
        debugPrint('Backend started successfully (PID: ${_backendProcess!.pid})');
        _isRunning = true;
      } else {
        debugPrint('Backend failed to start');
      }

      _isStarting = false;
      return running;
    } catch (e) {
      debugPrint('Error starting backend: $e');
      _isStarting = false;
      return false;
    }
  }

  /// Ensure .env file exists. In production, fail fast if missing or contains placeholders.
  /// The operator MUST create .env with real DB_PASSWORD and JWT_SECRET before starting.
  static Future<void> _ensureEnvFile(String envPath) async {
    final envFile = File(envPath);
    if (!envFile.existsSync()) {
      debugPrint('ERROR: Backend .env file not found at $envPath. '
          'Create it with real DB_PASSWORD and JWT_SECRET before starting.');
      throw StateError('Missing backend/.env file. Copy backend/.env.example to backend/.env and fill in real values.');
    }
    
    // Validate critical values are not placeholders
    final content = await envFile.readAsString();
    if (content.contains('DB_PASSWORD=CHANGE_ME') || 
        content.contains('JWT_SECRET=CHANGE_ME') ||
        content.contains('DB_PASSWORD=your_password') ||
        content.contains('JWT_SECRET=change_me_to_a_long_random_secret')) {
      debugPrint('ERROR: Backend .env contains placeholder values. '
          'Edit backend/.env and set real DB_PASSWORD and JWT_SECRET.');
      throw StateError('Backend .env contains placeholder values. Set real DB_PASSWORD and JWT_SECRET in backend/.env');
    }
  }

  /// How long to wait for the backend to finish its own graceful shutdown
  /// (drain in-flight requests + close the DB pool) before we force-kill it.
  /// Kept below the backend's internal 10s safety timeout so we still win the
  /// race and clean up, while giving real work time to complete.
  static const Duration _gracefulStopTimeout = Duration(seconds: 8);

  /// Stop the backend server **gracefully**, then force-kill only if needed.
  ///
  /// Ordinary `kill()` on Windows hard-terminates the process, so the backend's
  /// SIGTERM/SIGINT graceful handler never runs and in-flight database writes
  /// can be lost. Instead we:
  ///   1. Ask the backend to stop cleanly (stdin "shutdown" for a process we
  ///      spawned; a `.backend.shutdown` sentinel file for any instance,
  ///      including one adopted from a previous run; plus SIGTERM on POSIX).
  ///   2. Wait (up to [_gracefulStopTimeout]) for it to actually exit — this is
  ///      when it finishes serving open requests and closes the MySQL pool.
  ///   3. Force-kill as a last resort if it didn't stop in time.
  static Future<void> stopBackend() async {
    final spawned = _backendProcess;
    final pid = _adoptedPid ?? _readPidFile();

    // 1) Request a graceful shutdown through every available channel.
    _writeShutdownFile(); // universal trigger (spawned or adopted)
    if (spawned != null) {
      try {
        debugPrint('Requesting graceful shutdown of backend (PID: ${spawned.pid})');
        spawned.stdin.write('shutdown\n');
        await spawned.stdin.flush();
      } catch (e) {
        debugPrint('Could not write shutdown to backend stdin: $e');
      }
    } else if (pid != null && !Platform.isWindows) {
      // Adopted backend on POSIX: SIGTERM also triggers the graceful handler.
      try {
        Process.killPid(pid, ProcessSignal.sigterm);
      } catch (e) {
        debugPrint('Could not signal adopted backend (PID: $pid): $e');
      }
    }

    // 2) Wait for the backend to actually exit.
    var stoppedCleanly = false;
    if (spawned != null) {
      try {
        await spawned.exitCode.timeout(_gracefulStopTimeout);
        stoppedCleanly = true;
        debugPrint('Backend exited gracefully.');
      } on TimeoutException {
        debugPrint('Backend did not exit within '
            '${_gracefulStopTimeout.inSeconds}s; forcing termination.');
      } catch (_) {
        // exitCode may already be complete; treat as stopped.
        stoppedCleanly = true;
      }
    } else {
      final deadline = DateTime.now().add(_gracefulStopTimeout);
      while (DateTime.now().isBefore(deadline)) {
        if (!await isBackendRunning()) {
          stoppedCleanly = true;
          break;
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    // 3) Force-kill only if graceful shutdown didn't complete in time.
    if (!stoppedCleanly) {
      if (spawned != null) {
        try {
          spawned.kill(ProcessSignal.sigkill);
        } catch (e) {
          debugPrint('Force-kill of spawned backend failed: $e');
        }
      } else if (pid != null) {
        try {
          Process.killPid(pid);
        } catch (e) {
          debugPrint('Force-kill of adopted backend (PID: $pid) failed: $e');
        }
      }
    }

    _backendProcess = null;
    _deleteShutdownFile();
    _deletePidFile();
    _adoptedPid = null;
    _isRunning = false;
  }

  /// Check if the backend is currently running
  static bool get isRunning => _isRunning;
}
