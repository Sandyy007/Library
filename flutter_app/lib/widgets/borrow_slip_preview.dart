import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show Printing;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../utils/hindi_pdf_helper.dart';

class BorrowSlipPreview extends StatefulWidget {
  final Map<String, dynamic> slipData;

  const BorrowSlipPreview({super.key, required this.slipData});

  @override
  State<BorrowSlipPreview> createState() => _BorrowSlipPreviewState();
}

class _BorrowSlipPreviewState extends State<BorrowSlipPreview> {
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    final slip = widget.slipData;
    final issue = _extractIssueDataFromSlip(slip);
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width < 600
              ? MediaQuery.of(context).size.width * 0.95
              : 650,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _isDarkMode
                    ? Colors.grey[850]
                    : theme.colorScheme.primaryContainer,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 24,
                    color: _isDarkMode
                        ? Colors.white
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Borrow Slip',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'Slip #: ${slip['slip_number'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isDarkMode
                                ? Colors.grey[400]
                                : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isDarkMode ? Icons.light_mode : Icons.dark_mode,
                      color: _isDarkMode ? Colors.white : Colors.black54,
                    ),
                    onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
                    tooltip: _isDarkMode ? 'Light Mode' : 'Dark Mode',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: _isDarkMode ? Colors.white : Colors.black54,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildSlipContent(issue),
              ),
            ),
            const Divider(height: 1),
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isDarkMode ? Colors.grey[850] : Colors.grey[50],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _printSlip(slip),
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('Print'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _downloadSlip(slip),
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Download PDF'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlipContent(Map<String, dynamic> issue) {
    final cardBg = _isDarkMode ? Colors.grey[800] : Colors.grey[50];
    final dividerColor = _isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;
    final textColor = _isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = _isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Library Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isDarkMode
                  ? [Colors.blueGrey[800]!, Colors.blueGrey[900]!]
                  : [Colors.blue[50]!, Colors.blue[100]!],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isDarkMode ? Colors.blueGrey[600]! : Colors.blue[200]!,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _isDarkMode
                      ? Colors.blueGrey[700]
                      : Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.local_library,
                  size: 40,
                  color: _isDarkMode ? Colors.blue[200] : Colors.blue[700],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uttar Pradesh State Tax Training and Research Institute',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _isDarkMode ? Colors.blue[200] : Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lucknow • Library Management System',
                      style: TextStyle(
                        fontSize: 11,
                        color: subTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Slip Title Badge
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              color: _isDarkMode ? Colors.blue[700] : Colors.blue[800],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'BOOK BORROW SLIP',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Slip #: ${widget.slipData['slip_number'] ?? 'N/A'}',
            style: TextStyle(fontSize: 12, color: subTextColor),
          ),
        ),
        const SizedBox(height: 20),

        // Transaction Details
        _buildSection(
          title: 'Transaction Details',
          icon: Icons.swap_horiz,
          color: Colors.blue,
          children: [
            _buildInfoRow('Issue ID', (issue['issue_id'] ?? widget.slipData['issue_id'] ?? 'N/A').toString(), textColor, subTextColor),
            _buildInfoRow('Issue Date', _formatDate(issue['issue_date'] ?? ''), textColor, subTextColor),
            _buildInfoRow('Due Date', _formatDate(issue['due_date'] ?? ''), textColor, subTextColor),
            _buildInfoRow('Status', _capitalize(issue['status'] ?? 'N/A'), textColor, subTextColor),
          ],
          cardColor: cardBg,
          dividerColor: dividerColor,
        ),
        const SizedBox(height: 12),

        // Borrower Details
        _buildSection(
          title: 'Borrower Details',
          icon: Icons.person,
          color: Colors.green,
          children: [
            _buildInfoRow('Name', _normalizeText(issue['member_name'] ?? 'N/A'), textColor, subTextColor),
            _buildInfoRow('Member ID', (issue['member_id'] ?? 'N/A').toString(), textColor, subTextColor),
            _buildInfoRow('Type', _capitalize(issue['member_type'] ?? 'N/A'), textColor, subTextColor),
            _buildInfoRow('Phone', issue['member_phone'] ?? 'N/A', textColor, subTextColor),
            _buildInfoRow('Email', issue['member_email'] ?? 'N/A', textColor, subTextColor),
          ],
          cardColor: cardBg,
          dividerColor: dividerColor,
        ),
        const SizedBox(height: 12),

        // Book Details
        _buildSection(
          title: 'Book Details',
          icon: Icons.menu_book,
          color: Colors.purple,
          children: [
            _buildInfoRow('Title', _normalizeText(issue['book_title'] ?? 'N/A'), textColor, subTextColor),
            _buildInfoRow('Author', _normalizeText(issue['book_author'] ?? 'N/A'), textColor, subTextColor),
            _buildInfoRow('ISBN', issue['isbn'] ?? 'N/A', textColor, subTextColor),
            _buildInfoRow('Category', _normalizeText(issue['book_category'] ?? 'N/A'), textColor, subTextColor),
            _buildInfoRow('Rack #', issue['rack_number'] ?? 'N/A', textColor, subTextColor),
          ],
          cardColor: cardBg,
          dividerColor: dividerColor,
        ),
        const SizedBox(height: 20),

        // Signature Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isDarkMode ? [Colors.grey[800]!, Colors.grey[850]!] : [Colors.grey[50]!, Colors.grey[100]!],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.draw_outlined, size: 18, color: subTextColor),
                  const SizedBox(width: 8),
                  Text(
                    'Signatures',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildSignatureBox('Borrower', Colors.blue, dividerColor, textColor, subTextColor)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildSignatureBox('Librarian', Colors.green, dividerColor, textColor, subTextColor)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Footer
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isDarkMode ? Colors.orange[900]!.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: _isDarkMode ? Colors.orange[300] : Colors.orange[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Please return the book on or before the due date. Late returns may incur fines.',
                  style: TextStyle(fontSize: 11, color: _isDarkMode ? Colors.orange[200] : Colors.orange[800]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignatureBox(String label, Color color, Color dividerColor, Color textColor, Color subTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 60,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: color, width: 2)),
          ),
          child: Center(child: Icon(Icons.horizontal_rule, size: 24, color: subTextColor)),
        ),
        const SizedBox(height: 4),
        Text('Sign Above', style: TextStyle(fontSize: 9, color: subTextColor)),
        const SizedBox(height: 8),
        _buildSignatureLine('Name:', dividerColor, subTextColor),
        const SizedBox(height: 6),
        _buildSignatureLine('Date:', dividerColor, subTextColor),
      ],
    );
  }

  Widget _buildSignatureLine(String label, Color lineColor, Color labelColor) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: labelColor)),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            height: 14,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: lineColor)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
    required Color? cardColor,
    required Color dividerColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
          Divider(height: 1, color: dividerColor),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color textColor, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: subTextColor),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty || isoDate == 'null') return 'N/A';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print error: $e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded: $path')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download error: $e')),
      );
    }
  }

  Future<pw.Document> _generatePdf(Map<String, dynamic> slip) async {
    // Extract issue data - prioritize all available sources
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
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.blue200),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      width: 48,
                      height: 48,
                      padding: const pw.EdgeInsets.all(4),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue100,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: logoBytes == null
                          ? pw.Center(
                              child: pw.Text(
                                '📚',
                                style: pw.TextStyle(fontSize: 22),
                              ),
                            )
                          : pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Uttar Pradesh State Tax Training and Research Institute',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              fontFallback: HindiPdfHelper.boldFontFallback,
                            ),
                            maxLines: 2,
                          ),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Expanded(
                                child: pw.Text(
                                  'Library Management System, Lucknow',
                                  style: pw.TextStyle(
                                    font: baseFont,
                                    fontSize: 9,
                                    color: PdfColors.grey600,
                                    fontFallback: HindiPdfHelper.baseFontFallback,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                              pw.SizedBox(width: 8),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.blue800,
                                  borderRadius: pw.BorderRadius.circular(12),
                                ),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                                  mainAxisSize: pw.MainAxisSize.min,
                                  children: [
                                    pw.Text(
                                      'BOOK BORROW SLIP',
                                      style: pw.TextStyle(
                                        font: boldFont,
                                        fontSize: 9,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColors.white,
                                        fontFallback: HindiPdfHelper.boldFontFallback,
                                      ),
                                    ),
                                    pw.SizedBox(height: 2),
                                    pw.Text(
                                      'Slip #: ${slip['slip_number'] ?? 'N/A'}',
                                      style: pw.TextStyle(
                                        font: baseFont,
                                        fontSize: 8,
                                        color: PdfColors.white,
                                        fontFallback: HindiPdfHelper.baseFontFallback,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Transaction Details
              _buildPdfSection(
                'Transaction Details',
                PdfColors.blue,
                transactionRows,
                boldFont,
                baseFont,
                hindiCache,
              ),
              pw.SizedBox(height: 8),

              // Borrower Details
              _buildPdfSection(
                'Borrower Details',
                PdfColors.green800,
                borrowerRows,
                boldFont,
                baseFont,
                hindiCache,
              ),
              pw.SizedBox(height: 8),

              // Book Details
              _buildPdfSection(
                'Book Details',
                PdfColors.purple800,
                bookRows,
                boldFont,
                baseFont,
                hindiCache,
              ),
              pw.SizedBox(height: 12),

              // Signature Section
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text(
                          '✍ Signatures',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            fontFallback: HindiPdfHelper.boldFontFallback,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        // Borrower Signature Box
                        pw.Expanded(
                          child: _buildPdfSignatureBox('Borrower', PdfColors.blue50, PdfColors.blue200, PdfColors.blue800, boldFont, baseFont),
                        ),
                        pw.SizedBox(width: 16),
                        // Librarian Signature Box
                        pw.Expanded(
                          child: _buildPdfSignatureBox('Librarian', PdfColors.green50, PdfColors.green200, PdfColors.green800, boldFont, baseFont),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // Footer Notice
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.orange200),
                ),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 16,
                      height: 16,
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
                        'Please return the book on or before the due date. Late returns may incur fines.',
                        style: pw.TextStyle(
                          font: baseFont,
                          fontSize: 9,
                          color: PdfColors.orange800,
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

  pw.Widget _buildPdfSignatureBox(
    String label,
    PdfColor bgColor,
    PdfColor borderColor,
    PdfColor textColor,
    pw.Font boldFont,
    pw.Font baseFont,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: borderColor),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: pw.BoxDecoration(
              color: borderColor,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Text(
              label,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: textColor,
                fontFallback: HindiPdfHelper.boldFontFallback,
              ),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            width: double.infinity,
            height: 40,
            decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: textColor, width: 2)),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Signature',
            style: pw.TextStyle(
              font: baseFont,
              fontSize: 7,
              color: PdfColors.grey500,
              fontFallback: HindiPdfHelper.baseFontFallback,
            ),
          ),
          pw.SizedBox(height: 6),
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
                  height: 12,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
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
                  height: 12,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
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
    PdfColor color,
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
            padding: const pw.EdgeInsets.all(8),
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
                  width: 6,
                  height: 6,
                  decoration: pw.BoxDecoration(
                    color: color,
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
                    color: color,
                    fontFallback: HindiPdfHelper.boldFontFallback,
                  ),
                ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Table(
              columnWidths: {
                0: const pw.FixedColumnWidth(100),
                1: const pw.FlexColumnWidth(1),
              },
              children: rows.map((row) {
                final valueStyle = pw.TextStyle(
                  font: baseFont,
                  fontSize: 9,
                  fontFallback: HindiPdfHelper.baseFontFallback,
                );

                return pw.TableRow(
                  children: [
                    pw.Text(
                      row[0],
                      style: pw.TextStyle(
                        font: baseFont,
                        fontSize: 9,
                        color: PdfColors.grey600,
                        fontFallback: HindiPdfHelper.baseFontFallback,
                      ),
                    ),
                    HindiPdfHelper.buildCachedText(
                      row[1],
                      style: valueStyle,
                      cache: hindiCache,
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Normalize text for PDF display - handles Hindi text
  String _normalizeText(String text) {
    if (text.isEmpty || text == 'null') return 'N/A';
    return HindiPdfHelper.normalizeForPdf(text);
  }

  /// Extract issue data from slip root level (primary) with pdf_data as fallback
  Map<String, dynamic> _extractIssueDataFromSlip(Map<String, dynamic> slip) {
    final issue = <String, dynamic>{};

    // First, copy root level data (from JOIN query - always has complete data)
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

    // If root level is missing key data, try pdf_data as fallback
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

        // Fill in missing keys from pdf_data
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