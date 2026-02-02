import 'package:flutter/material.dart';
import '../models/issue.dart';
import '../services/api_service.dart';
import '../utils/date_formatter.dart';

class MemberHistoryDialog extends StatefulWidget {
  final int memberId;
  final String memberName;

  const MemberHistoryDialog({
    super.key,
    required this.memberId,
    required this.memberName,
  });

  @override
  State<MemberHistoryDialog> createState() => _MemberHistoryDialogState();
}

class _MemberHistoryDialogState extends State<MemberHistoryDialog> {
  List<Issue> _history = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final history = await ApiService.getMemberHistory(widget.memberId);

      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 800;
    final maxWidth = (isSmallScreen ? screenSize.width * 0.95 : 900).toDouble();
    final maxHeight = (isSmallScreen ? screenSize.height * 0.95 : 800)
        .toDouble();

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Borrowing History',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.memberName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Stats summary
              if (!_isLoading && _error == null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: isSmallScreen
                      ? SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 90,
                                child: _buildStatItem(
                                  'Total Borrowed',
                                  _history.length.toString(),
                                  Icons.book,
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 90,
                                child: _buildStatItem(
                                  'Currently Borrowed',
                                  _history
                                      .where((i) => i.status == 'issued')
                                      .length
                                      .toString(),
                                  Icons.bookmark,
                                  Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 90,
                                child: _buildStatItem(
                                  'Returned',
                                  _history
                                      .where((i) => i.status == 'returned')
                                      .length
                                      .toString(),
                                  Icons.check_circle,
                                  Colors.green,
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 90,
                                child: _buildStatItem(
                                  'Overdue',
                                  _history
                                      .where((i) => i.status == 'overdue')
                                      .length
                                      .toString(),
                                  Icons.warning,
                                  Colors.red,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatItem(
                              'Total Borrowed',
                              _history.length.toString(),
                              Icons.book,
                              Colors.blue,
                            ),
                            _buildStatItem(
                              'Currently Borrowed',
                              _history
                                  .where((i) => i.status == 'issued')
                                  .length
                                  .toString(),
                              Icons.bookmark,
                              Colors.orange,
                            ),
                            _buildStatItem(
                              'Returned',
                              _history
                                  .where((i) => i.status == 'returned')
                                  .length
                                  .toString(),
                              Icons.check_circle,
                              Colors.green,
                            ),
                            _buildStatItem(
                              'Overdue',
                              _history
                                  .where((i) => i.status == 'overdue')
                                  .length
                                  .toString(),
                              Icons.warning,
                              Colors.red,
                            ),
                          ],
                        ),
                ),
              // Content
              Flexible(child: _buildContent()),
              const Divider(height: 1),
              // Footer
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _loadHistory,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadHistory,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_history.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No borrowing history',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text(
                'This member hasn\'t borrowed any books yet',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _history.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
      ),
      itemBuilder: (context, index) {
        final issue = _history[index];
        return _buildHistoryTile(issue);
      },
    );
  }

  Widget _buildHistoryTile(Issue issue) {
    final statusColor = _getStatusColor(issue.status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Book cover
          Container(
            width: 50,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            clipBehavior: Clip.antiAlias,
            child: issue.coverImage != null && issue.coverImage!.isNotEmpty
                ? Image.network(
                    ApiService.resolvePublicUrl(issue.coverImage!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildBookPlaceholder(),
                  )
                : _buildBookPlaceholder(),
          ),
          const SizedBox(width: 12),
          // Book details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.bookTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  issue.bookAuthor,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildDateChip(
                      'Issued: ${_formatDate(issue.issueDate)}',
                      Icons.calendar_today,
                      Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _buildDateChip(
                      'Due: ${_formatDate(issue.dueDate)}',
                      Icons.event,
                      Colors.orange,
                    ),
                    if (issue.returnDate != null) ...[
                      const SizedBox(width: 8),
                      _buildDateChip(
                        'Returned: ${_formatDate(issue.returnDate!)}',
                        Icons.check,
                        Colors.green,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              issue.status.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookPlaceholder() {
    return Center(
      child: Icon(
        Icons.book,
        size: 24,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }

  Widget _buildDateChip(String text, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'issued':
        return Colors.blue;
      case 'returned':
        return Colors.green;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String dateStr) {
    return DateFormatter.formatDateIndian(dateStr);
  }
}
