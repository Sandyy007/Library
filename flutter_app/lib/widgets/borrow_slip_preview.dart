import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show Printing;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../utils/hindi_pdf_helper.dart';
import 'app_toast.dart';

class BorrowSlipPreview extends StatefulWidget {
  final Map<String, dynamic> slipData;

  const BorrowSlipPreview({super.key, required this.slipData});

  @override
  State<BorrowSlipPreview> createState() => _BorrowSlipPreviewState();
}

class _BorrowSlipPreviewState extends State<BorrowSlipPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeSlide;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeSlide = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slip = widget.slipData;
    final issue = _extractIssueDataFromSlip(slip);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const statusColors = {
      'issued': Color(0xFF1565C0),
      'returned': Color(0xFF2E7D32),
      'overdue': Color(0xFFC62828),
      'lost': Color(0xFF6A1B9A),
    };
    final status = (issue['status'] ?? 'issued').toString().toLowerCase();
    final statusColor = statusColors[status] ?? colorScheme.primary;
    final statusLabel = _capitalize(status).toUpperCase();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeSlide,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(_fadeSlide),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width < 600
                  ? MediaQuery.of(context).size.width * 0.95
                  : 680,
              maxHeight: MediaQuery.of(context).size.height * 0.92,
            ),
            child: Material(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              elevation: 12,
              shadowColor: Colors.black.withValues(alpha: 0.25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ──
                  _buildHeader(colorScheme, slip, statusColor, statusLabel),
                  // ── Content ──
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: _buildSlipContent(issue, statusColor),
                    ),
                  ),
                  // ── Actions ──
                  _buildActions(slip, colorScheme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, Map<String, dynamic> slip, Color statusColor, String statusLabel) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.85),
            colorScheme.primary.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.receipt_long_rounded, size: 24, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Borrow Slip',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  slip['slip_number'] ?? 'N/A',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.85)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSlipContent(Map<String, dynamic> issue, Color statusColor) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textColor = colorScheme.onSurface;
    final subTextColor = colorScheme.onSurface.withValues(alpha: 0.55);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // ── Library Header ──
        _buildLibraryHeader(colorScheme, textColor, subTextColor),
        const SizedBox(height: 6),
        // ── Status Row ──
        _buildStatusRow(issue, statusColor, textColor, subTextColor),
        const SizedBox(height: 16),
        // ── Sections ──
        _buildSection(
          title: 'Transaction Details',
          icon: Icons.swap_horiz_rounded,
          color: colorScheme.primary,
          accentColor: colorScheme.primary.withValues(alpha: 0.12),
          children: [
            _buildInfoRow(Icons.tag_rounded, 'Issue ID', (issue['issue_id'] ?? widget.slipData['issue_id'] ?? 'N/A').toString(), textColor, subTextColor),
            _buildInfoRow(Icons.calendar_today_rounded, 'Issue Date', _formatDate(issue['issue_date'] ?? ''), textColor, subTextColor),
            _buildInfoRow(Icons.event_rounded, 'Due Date', _formatDate(issue['due_date'] ?? ''), textColor, subTextColor),
            _buildInfoRow(Icons.info_outline_rounded, 'Status', _capitalize(issue['status'] ?? 'N/A'), textColor, subTextColor),
          ],
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 10),
        _buildSection(
          title: 'Borrower Details',
          icon: Icons.person_rounded,
          color: colorScheme.tertiary,
          accentColor: colorScheme.tertiary.withValues(alpha: 0.12),
          children: [
            _buildInfoRow(Icons.badge_rounded, 'Name', _normalizeText(issue['member_name'] ?? 'N/A'), textColor, subTextColor),
            _buildInfoRow(Icons.qr_code_rounded, 'Member ID', (issue['member_id'] ?? 'N/A').toString(), textColor, subTextColor),
            _buildInfoRow(Icons.category_rounded, 'Type', _capitalize(issue['member_type'] ?? 'N/A'), textColor, subTextColor),
            _buildInfoRow(Icons.phone_rounded, 'Phone', issue['member_phone'] ?? 'N/A', textColor, subTextColor),
            _buildInfoRow(Icons.email_rounded, 'Email', issue['member_email'] ?? 'N/A', textColor, subTextColor),
          ],
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 10),
        _buildSection(
          title: 'Book Details',
          icon: Icons.menu_book_rounded,
          color: colorScheme.secondary,
          accentColor: colorScheme.secondary.withValues(alpha: 0.12),
          children: [
            _buildInfoRow(Icons.title_rounded, 'Title', _normalizeText(issue['book_title'] ?? 'N/A'), textColor, subTextColor),
            _buildInfoRow(Icons.person_outline_rounded, 'Author', _normalizeText(issue['book_author'] ?? 'N/A'), textColor, subTextColor),
            _buildInfoRow(Icons.qr_code_rounded, 'ISBN', issue['isbn'] ?? 'N/A', textColor, subTextColor),
            _buildInfoRow(Icons.book_rounded, 'Category', _normalizeText(issue['book_category'] ?? 'N/A'), textColor, subTextColor),
            _buildInfoRow(Icons.inventory_2_rounded, 'Rack #', issue['rack_number'] ?? 'N/A', textColor, subTextColor),
          ],
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 16),
        // ── Signature Section ──
        _buildSignatureSection(colorScheme, textColor, subTextColor),
        const SizedBox(height: 14),
        // ── Footer Notice ──
        _buildFooterNotice(colorScheme),
      ],
    );
  }

  Widget _buildLibraryHeader(ColorScheme colorScheme, Color textColor, Color subTextColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.08),
            colorScheme.primary.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withValues(alpha: 0.15),
                  colorScheme.primary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
            ),
            child: Icon(Icons.local_library_rounded, size: 30, color: colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Uttar Pradesh State Tax Training\nand Research Institute',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Lucknow  •  Library Management System',
                  style: TextStyle(fontSize: 11, color: subTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(Map<String, dynamic> issue, Color statusColor, Color textColor, Color subTextColor) {
    final status = (issue['status'] ?? 'issued').toString().toLowerCase();
    final statusLabel = _capitalize(status);

    final IconData statusIcon;
    switch (status) {
      case 'returned':
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'overdue':
        statusIcon = Icons.warning_amber_rounded;
        break;
      case 'lost':
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusIcon = Icons.verified_rounded;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, size: 16, color: statusColor),
              const SizedBox(width: 6),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            'Issued: ${_formatDate(issue['issue_date'] ?? '')}',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(fontSize: 11, color: subTextColor),
          ),
        ),
      ],
    );
  }

  Widget _buildSignatureSection(ColorScheme colorScheme, Color textColor, Color subTextColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.draw_rounded, size: 16, color: colorScheme.primary),
              ),
              const SizedBox(width: 10),
              Text(
                'Signatures',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildSignatureBox(
                  'Borrower',
                  colorScheme.primary,
                  colorScheme.outlineVariant,
                  textColor,
                  subTextColor,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildSignatureBox(
                  'Librarian',
                  colorScheme.tertiary,
                  colorScheme.outlineVariant,
                  textColor,
                  subTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureBox(String label, Color color, Color dividerColor, Color textColor, Color subTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 10),
        CustomPaint(
          size: const Size(double.infinity, 56),
          painter: _DottedLinePainter(color: color.withValues(alpha: 0.5)),
          child: Center(
            child: Icon(
              Icons.horizontal_rule_rounded,
              size: 28,
              color: subTextColor.withValues(alpha: 0.4),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Sign above',
          style: TextStyle(fontSize: 9, color: subTextColor.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 8),
        _buildUnderlineField('Name:', color, subTextColor),
        const SizedBox(height: 6),
        _buildUnderlineField('Date:', color, subTextColor),
      ],
    );
  }

  Widget _buildUnderlineField(String label, Color color, Color labelColor) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: labelColor)),
        const SizedBox(width: 4),
        Expanded(
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: color.withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterNotice(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: colorScheme.error.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.info_outline_rounded, size: 12, color: colorScheme.error),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Please return the book on or before the due date. Late returns may incur fines as per library policy.',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: colorScheme.onErrorContainer.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required Color accentColor,
    required List<Widget> children,
    required ColorScheme colorScheme,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData leadingIcon, String label, String value, Color textColor, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Icon(leadingIcon, size: 14, color: subTextColor.withValues(alpha: 0.6)),
          ),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: subTextColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(Map<String, dynamic> slip, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: colorScheme.outline),
              ),
              onPressed: () => _printSlip(slip),
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text('Print'),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _downloadSlip(slip),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download PDF'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty || isoDate == 'null') return 'N/A';
    // Read the calendar date directly to avoid UTC->local day shifts on
    // date-only values, then render as dd-MMM-yyyy.
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(isoDate.trim());
    if (m != null) {
      final monthIdx = int.parse(m.group(2)!) - 1;
      if (monthIdx >= 0 && monthIdx < 12) {
        return '${m.group(3)}-${months[monthIdx]}-${m.group(1)}';
      }
    }
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd-MMM-yyyy').format(date);
    } catch (e) {
      return isoDate;
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty || text == 'null') return 'N/A';
    return text[0].toUpperCase() + text.substring(1).replaceAll('_', ' ');
  }

  // ── Print & Download ──

  Future<void> _printSlip(Map<String, dynamic> slip) async {
    try {
      final doc = await _generatePdf(slip);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'BorrowSlip_${slip['slip_number'] ?? 'slip'}',
      );
    } catch (e) {
      debugPrint('Print error: $e');
      if (!mounted) return;
      AppToast.error(context, 'Print error: $e');
    }
  }

  Future<void> _downloadSlip(Map<String, dynamic> slip) async {
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Borrow Slip',
        fileName: 'BorrowSlip_${slip['slip_number'] ?? DateTime.now().millisecondsSinceEpoch}.pdf',
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (path == null || path.isEmpty) return;

      final doc = await _generatePdf(slip);
      final bytes = await doc.save();
      await File(path).writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      AppToast.showOnMessenger(messenger,
          message: 'Downloaded: $path', type: ToastType.success);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Download error: $e');
    }
  }

  // ── PDF Generation (unchanged logic, same output) ──

  Future<pw.Document> _generatePdf(Map<String, dynamic> slip) async {
    final issue = _extractIssueDataFromSlip(slip);

    debugPrint('PDF Slip - full keys: ${slip.keys.toList()}');
    debugPrint('PDF Issue - extracted: ${issue.keys.toList()}');
    debugPrint('PDF - member_name: ${issue['member_name']}');
    debugPrint('PDF - book_title: ${issue['book_title']}');

    await HindiPdfHelper.initialize();
    final baseFont = HindiPdfHelper.baseFont;
    final boldFont = HindiPdfHelper.boldFont;
    final logoBytes = await loadPdfLogo();

    final List<List<String>> transactionRows = [
      ['Issue ID', (issue['issue_id'] ?? slip['issue_id'] ?? 'N/A').toString()],
      ['Issue Date', _formatDate(issue['issue_date'] ?? '')],
      ['Due Date', _formatDate(issue['due_date'] ?? '')],
      ['Status', _capitalize(issue['status'] ?? 'N/A').toString()],
    ];
    final List<List<String>> borrowerRows = [
      ['Name', _normalizeText(issue['member_name'] ?? 'N/A').toString()],
      ['Member ID', (issue['member_id'] ?? 'N/A').toString()],
      ['Type', _capitalize(issue['member_type'] ?? 'N/A').toString()],
      ['Phone', (issue['member_phone'] ?? 'N/A').toString()],
      ['Email', (issue['member_email'] ?? 'N/A').toString()],
    ];
    final List<List<String>> bookRows = [
      ['Title', _normalizeText(issue['book_title'] ?? 'N/A').toString()],
      ['Author', _normalizeText(issue['book_author'] ?? 'N/A').toString()],
      ['ISBN', (issue['isbn'] ?? 'N/A').toString()],
      ['Category', _normalizeText(issue['book_category'] ?? 'N/A').toString()],
      ['Rack #', (issue['rack_number'] ?? 'N/A').toString()],
    ];
    final hindiCache = await HindiPdfHelper.preRenderHindiTexts(
      [
        ...transactionRows.map((row) => row[1]),
        ...borrowerRows.map((row) => row[1]),
        ...bookRows.map((row) => row[1]),
      ],
      fontSize: 9,
      fontWeight: pw.FontWeight.normal,
      color: PdfColors.black,
    );

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        build: (pw.Context context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  gradient: pw.LinearGradient(
                    colors: const [PdfColors.blue800, PdfColors.blue600],
                    begin: pw.Alignment.topLeft,
                    end: pw.Alignment.bottomRight,
                  ),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      width: 52,
                      height: 52,
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue100,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: logoBytes == null
                          ? pw.Center(
                              child: pw.Text(
                                '\u{1F4DA}',
                                style: pw.TextStyle(fontSize: 22),
                              ),
                            )
                          : pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(width: 14),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Uttar Pradesh State Tax Training\nand Research Institute',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              fontFallback: HindiPdfHelper.boldFontFallback,
                            ),
                            maxLines: 2,
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'Library Management System, Lucknow',
                            style: pw.TextStyle(
                              font: baseFont,
                              fontSize: 9,
                              color: PdfColors.blue50,
                              fontFallback: HindiPdfHelper.baseFontFallback,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue900,
                        borderRadius: pw.BorderRadius.circular(16),
                        border: pw.Border.all(color: PdfColors.blue400),
                      ),
                      child: pw.Column(
                        mainAxisSize: pw.MainAxisSize.min,
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            'BOOK BORROW SLIP',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              fontFallback: HindiPdfHelper.boldFontFallback,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            '${slip['slip_number'] ?? 'N/A'}',
                            style: pw.TextStyle(
                              font: baseFont,
                              fontSize: 7,
                              color: PdfColors.blue200,
                              fontFallback: HindiPdfHelper.baseFontFallback,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              _buildPdfSection('Transaction Details', PdfColors.blue700, transactionRows, boldFont, baseFont, hindiCache),
              pw.SizedBox(height: 10),

              _buildPdfSection('Borrower Details', PdfColors.green700, borrowerRows, boldFont, baseFont, hindiCache),
              pw.SizedBox(height: 10),

              _buildPdfSection('Book Details', PdfColors.purple700, bookRows, boldFont, baseFont, hindiCache),
              pw.SizedBox(height: 14),

              _buildPdfSignatureSection(boldFont, baseFont),
              pw.SizedBox(height: 10),

              pw.Container(
                padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.orange200),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 18,
                      height: 18,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.orange800,
                        shape: pw.BoxShape.circle,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'i',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 10,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontFallback: HindiPdfHelper.boldFontFallback,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Text(
                        'Please return the book on or before the due date. Late returns may incur fines as per library policy.',
                        style: pw.TextStyle(
                          font: baseFont,
                          fontSize: 8,
                          height: 1.4,
                          color: PdfColors.orange900,
                          fontFallback: HindiPdfHelper.baseFontFallback,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return doc;
  }

  pw.Widget _buildPdfSignatureSection(pw.Font boldFont, pw.Font baseFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 8,
                height: 8,
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue700,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                'Signatures',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  fontFallback: HindiPdfHelper.boldFontFallback,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildPdfSignatureBox('Borrower', PdfColors.blue700, boldFont, baseFont),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _buildPdfSignatureBox('Librarian', PdfColors.green700, boldFont, baseFont),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSignatureBox(
    String label,
    PdfColor accentColor,
    pw.Font boldFont,
    pw.Font baseFont,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(14),
            ),
            child: pw.Text(
              label,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: accentColor,
                fontFallback: HindiPdfHelper.boldFontFallback,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            width: double.infinity,
            height: 50,
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey400, width: 1.5),
              ),
            ),
            child: pw.Center(
              child: pw.Text(
                'Sign above',
                style: pw.TextStyle(
                  font: baseFont,
                  fontSize: 8,
                  color: PdfColors.grey400,
                  fontFallback: HindiPdfHelper.baseFontFallback,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Name:',
                style: pw.TextStyle(
                  font: baseFont,
                  fontSize: 8,
                  color: PdfColors.grey600,
                  fontFallback: HindiPdfHelper.baseFontFallback,
                ),
              ),
              pw.Expanded(
                child: pw.Container(
                  margin: const pw.EdgeInsets.only(left: 4),
                  height: 14,
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Date:',
                style: pw.TextStyle(
                  font: baseFont,
                  fontSize: 8,
                  color: PdfColors.grey600,
                  fontFallback: HindiPdfHelper.baseFontFallback,
                ),
              ),
              pw.Expanded(
                child: pw.Container(
                  margin: const pw.EdgeInsets.only(left: 4),
                  height: 14,
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSection(
    String title,
    PdfColor accentColor,
    List<List<String>> rows,
    pw.Font boldFont,
    pw.Font baseFont,
    Map<String, HindiRasterText> hindiCache,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(7),
                topRight: pw.Radius.circular(7),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 8,
                  height: 8,
                  decoration: pw.BoxDecoration(
                    color: accentColor,
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: accentColor,
                    fontFallback: HindiPdfHelper.boldFontFallback,
                  ),
                ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(10, 6, 10, 8),
            child: pw.Table(
              columnWidths: {
                0: const pw.FixedColumnWidth(100),
                1: const pw.FlexColumnWidth(1),
              },
              children: List.generate(rows.length, (i) {
                final row = rows[i];
                final isEven = i.isEven;
                final labelStyle = pw.TextStyle(
                  font: baseFont,
                  fontSize: 9,
                  color: PdfColors.grey600,
                  fontFallback: HindiPdfHelper.baseFontFallback,
                );
                final valueStyle = pw.TextStyle(
                  font: baseFont,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.normal,
                  fontFallback: HindiPdfHelper.baseFontFallback,
                );

                return pw.TableRow(
                  decoration: isEven
                      ? pw.BoxDecoration(
                          color: PdfColors.grey50,
                        )
                      : null,
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                      child: pw.Text(row[0], style: labelStyle),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                      child: HindiPdfHelper.buildCachedText(
                        row[1],
                        style: valueStyle,
                        cache: hindiCache,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  String _normalizeText(String text) {
    if (text.isEmpty || text == 'null') return 'N/A';
    return HindiPdfHelper.normalizeForPdf(text);
  }

  Map<String, dynamic> _extractIssueDataFromSlip(Map<String, dynamic> slip) {
    final issue = <String, dynamic>{};

    for (final key in [
      'issue_id', 'issue_date', 'due_date', 'return_date', 'status', 'notes',
      'book_id', 'isbn', 'book_title', 'book_author', 'rack_number', 'book_category', 'cover_image',
      'member_id', 'member_name', 'member_email', 'member_phone', 'member_type',
      'profile_photo', 'member_address', 'issued_by_name',
    ]) {
      if (slip[key] != null) {
        issue[key] = slip[key];
      }
    }

    if (issue['member_name'] == null || issue['book_title'] == null) {
      final pdfData = slip['pdf_data'];
      if (pdfData != null) {
        Map<String, dynamic>? parsedPdfData;
        if (pdfData is Map<String, dynamic>) {
          parsedPdfData = pdfData;
        } else if (pdfData is Map) {
          parsedPdfData = Map<String, dynamic>.fromEntries(
            pdfData.entries.map((e) => MapEntry(e.key.toString(), e.value)),
          );
        } else if (pdfData is String && pdfData.isNotEmpty) {
          try {
            final decoded = jsonDecode(pdfData);
            if (decoded is Map) {
              parsedPdfData = Map<String, dynamic>.fromEntries(
                decoded.entries.map((e) => MapEntry(e.key.toString(), e.value)),
              );
            }
          } catch (e) {
            debugPrint('Failed to parse pdf_data: $e');
          }
        }

        if (parsedPdfData != null) {
          for (final key in parsedPdfData.keys) {
            if (!issue.containsKey(key) || issue[key] == null) {
              issue[key] = parsedPdfData[key];
            }
          }
        }
      }
    }

    return issue;
  }
}

Future<void> showBorrowSlipPreview(BuildContext context, Map<String, dynamic> slipData) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => BorrowSlipPreview(slipData: slipData),
  );
}

class _DottedLinePainter extends CustomPainter {
  final Color color;
  _DottedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < size.width) {
      path.moveTo(startX, size.height);
      path.lineTo(math.min(startX + dashWidth, size.width), size.height);
      startX += dashWidth + dashSpace;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DottedLinePainter oldDelegate) => oldDelegate.color != color;
}
