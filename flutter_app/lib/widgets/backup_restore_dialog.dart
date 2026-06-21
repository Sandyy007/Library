import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../services/api_service.dart';
import 'premium_dialog.dart';

class BackupRestoreDialog extends StatefulWidget {
  const BackupRestoreDialog({super.key});

  @override
  State<BackupRestoreDialog> createState() => _BackupRestoreDialogState();
}

class _BackupRestoreDialogState extends State<BackupRestoreDialog> {
  bool _isLoading = false;
  String? _statusMessage;
  bool _isError = false;

  @override
  Widget build(BuildContext context) {
    return PremiumDialogShell(
      icon: Icons.backup_rounded,
      title: 'Backup & Restore',
      subtitle: 'Manage your library data',
      maxWidth: 600,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSection(
            title: 'Create Backup',
            description:
                'Export all library data including books, members, and issue records to a JSON file.',
            icon: Icons.cloud_download_rounded,
            color: Colors.blue,
            buttonText: 'Create Backup',
            onPressed: _isLoading ? null : _createBackup,
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Restore from Backup',
            description:
                'Import data from a previously created backup file. This will replace existing data.',
            icon: Icons.cloud_upload_rounded,
            color: Colors.orange,
            buttonText: 'Restore Backup',
            onPressed: _isLoading ? null : _restoreBackup,
            isWarning: true,
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isError
                    ? Colors.red.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isError
                      ? Colors.red.withValues(alpha: 0.3)
                      : Colors.green.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isError
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    color: _isError ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 3,
                      style: TextStyle(
                        color: _isError ? Colors.red[800] : Colors.green[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_isLoading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
        ],
      ),
      actions: [
        PremiumDialogButton.secondary(
          label: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String buttonText,
    required VoidCallback? onPressed,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: isWarning
            ? Border.all(color: Colors.orange.withValues(alpha: 0.5))
            : null,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 400;
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    if (isWarning) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 14, color: Colors.orange[700]),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Warning: Overwrites existing data',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (isNarrow) ...[
                const SizedBox(height: 12),
              ] else ...[
                const SizedBox(width: 16),
              ],
              SizedBox(
                height: 36,
                child: ElevatedButton.icon(
                  onPressed: onPressed,
                  icon: Icon(icon, size: 16),
                  label: Text(isNarrow ? '' : buttonText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 16),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createBackup() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final backupData = await ApiService.getBackup();
      
      // Pick save location, then write file explicitly (Windows doesn't always auto-save bytes)
      final fileName = 'library_backup_${DateTime.now().toIso8601String().split('T')[0]}.json';
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup File',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
        await File(result).writeAsString(jsonString, flush: true);

        setState(() {
          _statusMessage = 'Backup created successfully! Saved to: $result';
          _isError = false;
        });
      } else {
        setState(() {
          _statusMessage = 'Backup cancelled';
          _isError = true;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to create backup: $e';
        _isError = true;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreBackup() async {
    // First confirm with user
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Confirm Restore'),
          ],
        ),
        content: const Text(
          'This will replace all existing data with the backup data. '
          'This action cannot be undone.\n\n'
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Pick backup file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final picked = result.files.first;
      String fileContent;

      if (picked.bytes != null) {
        fileContent = utf8.decode(picked.bytes!);
      } else if (picked.path != null) {
        fileContent = await File(picked.path!).readAsString();
      } else {
        throw Exception('Unable to read selected file');
      }

      final backupData = jsonDecode(fileContent) as Map<String, dynamic>;

      await ApiService.restoreBackup(backupData, clearExisting: true);

      setState(() {
        _statusMessage = 'Backup restored successfully! Please refresh the application.';
        _isError = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to restore backup: $e';
        _isError = true;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
