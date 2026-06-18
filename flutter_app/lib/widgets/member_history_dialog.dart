import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import '../models/issue.dart';
import '../services/api_service.dart';
import '../utils/date_formatter.dart';
import '../utils/hindi_text.dart';
import '../utils/hindi_pdf_helper.dart';

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
                                  const Color(0xFF3B82F6),
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
                                  const Color(0xFFF59E0B),
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
                                  const Color(0xFF10B981),
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
                                  const Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Flexible(child: _buildStatItem(
                              'Total Borrowed',
                              _history.length.toString(),
                              Icons.book,
                              const Color(0xFF3B82F6),
                            )),
                            const SizedBox(width: 8),
                            Flexible(child: _buildStatItem(
                              'Currently Borrowed',
                              _history
                                  .where((i) => i.status == 'issued')
                                  .length
                                  .toString(),
                              Icons.bookmark,
                              const Color(0xFFF59E0B),
                            )),
                            const SizedBox(width: 8),
                            Flexible(child: _buildStatItem(
                              'Returned',
                              _history
                                  .where((i) => i.status == 'returned')
                                  .length
                                  .toString(),
                              Icons.check_circle,
                              const Color(0xFF10B981),
                            )),
                            const SizedBox(width: 8),
                            Flexible(child: _buildStatItem(
                              'Overdue',
                              _history
                                  .where((i) => i.status == 'overdue')
                                  .length
                                  .toString(),
                              Icons.warning,
                              const Color(0xFFEF4444),
                            )),
                          ],
                        ),
                ),
              // Content
              Flexible(child: _buildContent()),
              const Divider(height: 1),
              // Footer
              Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: _history.isEmpty ? null : _exportToPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Download PDF'),
                      ),
                      const SizedBox(width: 8),
                      Row(
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportToPdf() async {
    if (_history.isEmpty) return;

    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Borrowing History PDF',
        fileName: 'member_history_${widget.memberName.replaceAll(' ', '_')}_${DateTime.now().toIso8601String().split('T')[0]}.pdf',
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );

      if (path == null || path.isEmpty) return;

      // Initialize Hindi PDF helper for font support
      await HindiPdfHelper.initialize();
      final baseFont = HindiPdfHelper.baseFont;
      final boldFont = HindiPdfHelper.boldFont;

      final memberLine =
          'Member: ${HindiPdfHelper.normalizeForPdf(widget.memberName)}';
      final memberCache = await HindiPdfHelper.preRenderHindiTexts(
        [memberLine],
        fontSize: 12,
        fontWeight: pw.FontWeight.normal,
        color: PdfColors.black,
      );

      final tableRows = _history.map((issue) {
        return [
          HindiPdfHelper.normalizeForPdf(issue.bookTitle),
          HindiPdfHelper.normalizeForPdf(issue.bookAuthor),
          DateFormatter.formatDateIndian(issue.issueDate),
          DateFormatter.formatDateIndian(issue.dueDate),
          issue.returnDate != null
              ? DateFormatter.formatDateIndian(issue.returnDate!)
              : '-',
          issue.status[0].toUpperCase() + issue.status.substring(1),
        ];
      }).toList();
      final hindiCache = await HindiPdfHelper.preRenderHindiTexts(
        tableRows.expand((row) => row),
        fontSize: 9,
        fontWeight: pw.FontWeight.normal,
        color: PdfColors.black,
      );

      // Load organization logo
      final logoBytes = await _loadPdfLogo();

      final doc = pw.Document();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
          build: (context) {
            final cellStyle = pw.TextStyle(
              font: baseFont,
              fontSize: 9,
              fontFallback: HindiPdfHelper.baseFontFallback,
            );
            final headerStyle = pw.TextStyle(
              font: boldFont,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              fontFallback: HindiPdfHelper.boldFontFallback,
            );

            return [
              // Organization Header
              _buildOrgHeader(logoBytes, boldFont, baseFont),
              pw.SizedBox(height: 16),

              // Document Title
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue800,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'Member Borrowing History',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      fontFallback: HindiPdfHelper.boldFontFallback,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              HindiPdfHelper.buildCachedText(
                memberLine,
                style: pw.TextStyle(
                  font: baseFont,
                  fontSize: 12,
                  fontFallback: HindiPdfHelper.baseFontFallback,
                ),
                cache: memberCache,
              ),
              pw.Text(
                'Generated: ${DateFormatter.formatDateTimeIndian(DateTime.now().toIso8601String())}',
                style: pw.TextStyle(
                  font: baseFont,
                  fontSize: 10,
                  color: PdfColors.grey700,
                  fontFallback: HindiPdfHelper.baseFontFallback,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'Total Borrowed',
                            style: pw.TextStyle(
                              font: baseFont,
                              fontSize: 10,
                              fontFallback: HindiPdfHelper.baseFontFallback,
                            ),
                          ),
                          pw.Text(
                            '${_history.length}',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              fontFallback: HindiPdfHelper.boldFontFallback,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.orange50,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'Issued',
                            style: pw.TextStyle(
                              font: baseFont,
                              fontSize: 10,
                              fontFallback: HindiPdfHelper.baseFontFallback,
                            ),
                          ),
                          pw.Text(
                            '${_history.where((i) => i.status == 'issued').length}',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              fontFallback: HindiPdfHelper.boldFontFallback,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green50,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'Returned',
                            style: pw.TextStyle(
                              font: baseFont,
                              fontSize: 10,
                              fontFallback: HindiPdfHelper.baseFontFallback,
                            ),
                          ),
                          pw.Text(
                            '${_history.where((i) => i.status == 'returned').length}',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              fontFallback: HindiPdfHelper.boldFontFallback,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.red50,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'Overdue',
                            style: pw.TextStyle(
                              font: baseFont,
                              fontSize: 10,
                              fontFallback: HindiPdfHelper.baseFontFallback,
                            ),
                          ),
                          pw.Text(
                            '${_history.where((i) => i.status == 'overdue').length}',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              fontFallback: HindiPdfHelper.boldFontFallback,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.TableHelper.fromTextArray(
                headers: ['Book Title', 'Author', 'Issue Date', 'Due Date', 'Return Date', 'Status'],
                data: tableRows,
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                headerStyle: headerStyle,
                cellStyle: cellStyle,
                cellBuilder: (index, data, rowNum) {
                  return HindiPdfHelper.buildCachedText(
                    data.toString(),
                    style: cellStyle,
                    cache: hindiCache,
                  );
                },
                cellAlignment: pw.Alignment.centerLeft,
                cellHeight: 20,
                headerHeight: 22,
              ),
            ];
          },
        ),
      );

      final bytes = await doc.save();
      await File(path).writeAsBytes(bytes, flush: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF exported to: $path'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting PDF: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
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
              Icon(Icons.error_outline, size: 48, color: const Color(0xFFEF4444)),
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
      final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_outlined, size: 64, color: muted),
              const SizedBox(height: 16),
              Text(
                'No borrowing history',
                style: TextStyle(fontSize: 16, color: muted),
              ),
              const SizedBox(height: 8),
              Text(
                'This member hasn\'t borrowed any books yet',
                style: TextStyle(fontSize: 14, color: muted),
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
                Builder(
                  builder: (context) {
                    final displayTitle = normalizeHindiForDisplay(
                      issue.bookTitle,
                    );
                    return Text(
                      displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: hindiAwareTextStyle(
                        context,
                        text: displayTitle,
                        base: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 2),
                Builder(
                  builder: (context) {
                    final displayAuthor = normalizeHindiForDisplay(
                      issue.bookAuthor,
                    );
                    return Text(
                      displayAuthor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: hindiAwareTextStyle(
                        context,
                        text: displayAuthor,
                        base: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildDateChip(
                        'Issued: ${_formatDate(issue.issueDate)}',
                        Icons.calendar_today,
                        const Color(0xFF3B82F6),
                      ),
                      const SizedBox(width: 8),
                      _buildDateChip(
                        'Due: ${_formatDate(issue.dueDate)}',
                        Icons.event,
                        const Color(0xFFF59E0B),
                      ),
                      if (issue.returnDate != null) ...[
                        const SizedBox(width: 8),
                        _buildDateChip(
                          'Returned: ${_formatDate(issue.returnDate!)}',
                          Icons.check,
                          const Color(0xFF10B981),
                        ),
                      ],
                    ],
                  ),
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
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'issued':
        return const Color(0xFF3B82F6);
      case 'returned':
        return const Color(0xFF10B981);
      case 'overdue':
        return const Color(0xFFEF4444);
      default:
        return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    }
  }

  String _formatDate(String dateStr) {
    return DateFormatter.formatDateIndian(dateStr);
  }

  Future<Uint8List?> _loadPdfLogo() async {
    try {
      final logoData = await rootBundle.load('assets/images/Office_Logo.png');
      return logoData.buffer.asUint8List();
    } catch (e) {
      debugPrint('Could not load logo: $e');
    }
    return null;
  }

  pw.Widget _buildOrgHeader(Uint8List? logoBytes, pw.Font boldFont, pw.Font baseFont) {
    if (logoBytes != null) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          children: [
            pw.Image(pw.MemoryImage(logoBytes), width: 70, height: 70),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'Uttar Pradesh State Tax Training',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      font: boldFont,
                      fontFallback: HindiPdfHelper.boldFontFallback,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    'and Research Institute',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      font: boldFont,
                      fontFallback: HindiPdfHelper.boldFontFallback,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Lucknow',
                    style: pw.TextStyle(
                      fontSize: 11,
                      font: baseFont,
                      color: PdfColors.grey600,
                      fontFallback: HindiPdfHelper.baseFontFallback,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
          ],
        ),
      );
    } else {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                'Uttar Pradesh State Tax Training',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  fontFallback: HindiPdfHelper.boldFontFallback,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'and Research Institute',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  fontFallback: HindiPdfHelper.boldFontFallback,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
  }
}
