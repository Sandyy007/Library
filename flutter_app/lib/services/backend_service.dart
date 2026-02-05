import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Service to manage the backend Node.js server lifecycle.
/// Starts the backend automatically when the app runs and stops it on exit.
class BackendService {
  static Process? _backendProcess;
  static bool _isStarting = false;
  static bool _isRunning = false;

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

    // Check if backend is already running
    if (await isBackendRunning()) {
      debugPrint('Backend is already running on port 3000');
      _isRunning = true;
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

      // Start the Node.js server
      _backendProcess = await Process.start(
        'node',
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

  /// Ensure .env file exists with default values
  static Future<void> _ensureEnvFile(String envPath) async {
    final envFile = File(envPath);
    if (!envFile.existsSync()) {
      debugPrint('Creating default .env file at: $envPath');
      await envFile.writeAsString('''
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=admin
DB_NAME=library_management
JWT_SECRET=7fc548b2b0e471ff19ed22a8085d6b24634d3295
PORT=3000
NODE_ENV=production
''');
    }
  }

  /// Stop the backend server
  static Future<void> stopBackend() async {
    if (_backendProcess != null) {
      debugPrint('Stopping backend (PID: ${_backendProcess!.pid})');
      _backendProcess!.kill();
      _backendProcess = null;
      _isRunning = false;
    }
  }

  /// Check if the backend is currently running
  static bool get isRunning => _isRunning;
}
