import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/date_formatter.dart';

class BorrowedBooksDialog extends StatefulWidget {
  final int memberId;
  final String memberName;
  final int borrowCount;

  const BorrowedBooksDialog({
    super.key,
    required this.memberId,
    required this.memberName,
    required this.borrowCount,
  });

  @override
  State<BorrowedBooksDialog> createState() => _BorrowedBooksDialogState();
}

class _BorrowedBooksDialogState extends State<BorrowedBooksDialog> {
  List<dynamic> _borrowedBooks = [];
  bool _isLoading = true;
  String? _error;
  int _maxAllowed = 5;

  @override
  void initState() {
    super.initState();
    _loadBorrowedBooks();
  }

  Future<void> _loadBorrowedBooks() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final data = await ApiService.getMemberBorrowedBooks(widget.memberId);
      setState(() {
        _borrowedBooks = data['borrowed_books'] as List<dynamic>? ?? [];
        _maxAllowed = data['max_allowed'] ?? 5;
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
    final maxWidth = (isSmallScreen ? screenSize.width * 0.95 : 750).toDouble();
    final maxHeight =
        (isSmallScreen ? screenSize.height * 0.9 : 600).toDouble();

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
                    Icon(
                      Icons.menu_book_rounded,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Currently Borrowed Books',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.memberName,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimary
                                  .withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Borrow limit indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimary
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.borrowCount} / $_maxAllowed',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.close,
                          color: Theme.of(context).colorScheme.onPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Limit indicator bar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                widget.borrowCount >= _maxAllowed
                                    ? Icons.warning_amber_rounded
                                    : Icons.info_outline,
                                size: 16,
                                color: widget.borrowCount >= _maxAllowed
                                    ? Colors.orange
                                    : Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.borrowCount >= _maxAllowed
                                    ? 'Borrowing limit reached! Must return books before borrowing more.'
                                    : 'Can borrow ${_maxAllowed - widget.borrowCount} more book(s)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: widget.borrowCount >= _maxAllowed
                                      ? Colors.orange
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _maxAllowed > 0
                                  ? widget.borrowCount / _maxAllowed
                                  : 0,
                              minHeight: 6,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                widget.borrowCount >= _maxAllowed
                                    ? Colors.red
                                    : widget.borrowCount >= _maxAllowed - 1
                                        ? Colors.orange
                                        : Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: _isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.error_outline,
                                      size: 48, color: Colors.red[300]),
                                  const SizedBox(height: 16),
                                  Text('Error: $_error'),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadBorrowedBooks,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _borrowedBooks.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.book_outlined,
                                        size: 64,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.3),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No books currently borrowed',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.5),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _borrowedBooks.length,
                                separatorBuilder: (c, i) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final book = _borrowedBooks[index]
                                      as Map<String, dynamic>;
                                  return _buildBookTile(book);
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookTile(Map<String, dynamic> book) {
    final title = book['title'] ?? 'Unknown';
    final author = book['author'] ?? 'Unknown';
    final isbn = book['isbn'] ?? '';
    final category = book['category'] ?? '';
    final issueDate = book['issue_date'] ?? '';
    final dueDate = book['due_date'] ?? '';
    final status = book['status'] ?? 'issued';
    final coverImage = book['cover_image'];

    final isOverdue = status == 'overdue' ||
        (dueDate.isNotEmpty &&
            DateTime.tryParse(dueDate)?.isBefore(DateTime.now()) == true);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      leading: Container(
        width: 45,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        clipBehavior: Clip.antiAlias,
        child: coverImage != null && coverImage.toString().isNotEmpty
            ? Image.network(
                ApiService.resolvePublicUrl(coverImage.toString()),
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const Center(
                  child: Icon(Icons.book, size: 24),
                ),
              )
            : const Center(child: Icon(Icons.book, size: 24)),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'by $author',
            style: TextStyle(
              fontSize: 12,
              color:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (isbn.isNotEmpty) ...[
                _infoChip('ISBN: $isbn', Icons.qr_code, Colors.grey),
                const SizedBox(width: 8),
              ],
              if (category.isNotEmpty)
                _infoChip(category, Icons.category, Colors.blue),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _infoChip(
                'Issued: ${DateFormatter.formatDateIndian(issueDate)}',
                Icons.calendar_today,
                Colors.green,
              ),
              const SizedBox(width: 8),
              _infoChip(
                'Due: ${DateFormatter.formatDateIndian(dueDate)}',
                Icons.event,
                isOverdue ? Colors.red : Colors.orange,
              ),
            ],
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isOverdue
              ? Colors.red.withValues(alpha: 0.1)
              : Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOverdue
                ? Colors.red.withValues(alpha: 0.3)
                : Colors.blue.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          isOverdue ? 'OVERDUE' : 'ISSUED',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isOverdue ? Colors.red : Colors.blue,
          ),
        ),
      ),
    );
  }

  Widget _infoChip(String text, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: color.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
