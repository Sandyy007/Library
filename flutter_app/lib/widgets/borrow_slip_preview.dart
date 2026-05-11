import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show Printing;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../utils/hindi_pdf_helper.dart';
import '../utils/hindi_text.dart';

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
    final issue = slip['pdf_data'] ?? slip;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width < 600
              ? MediaQuery.of(context).size.width * 0.95
              : 600,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Borrow Slip',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Slip #: ${slip['slip_number'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isDarkMode
                        ? Icons.light_mode
                        : Icons.dark_mode),
                    onPressed: () {
                      setState(() {
                        _isDarkMode = !_isDarkMode;
                      });
                    },
                    tooltip: _isDarkMode ? 'Light Mode' : 'Dark Mode',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildSlipContent(issue),
              ),
            ),
            const Divider(height: 1),
            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
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
    final theme = Theme.of(context);
    final cardColor = _isDarkMode ? Colors.grey[850] : Colors.grey[50];
    final dividerColor = _isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Library Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.local_library,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Library Management System',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Date: ${_formatSlipDate(widget.slipData['generated_at'])}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Transaction Details
        _buildSection(
          title: 'Transaction Details',
          icon: Icons.swap_horiz,
          children: [
            _buildInfoRow('Slip Number', widget.slipData['slip_number'] ?? 'N/A'),
            _buildInfoRow(
                'Issue ID', (issue['issue_id'] ?? widget.slipData['issue_id'] ?? 'N/A').toString()),
            _buildInfoRow('Issue Date', _formatDate(issue['issue_date'] ?? '')),
            _buildInfoRow('Due Date', _formatDate(issue['due_date'] ?? '')),
            _buildInfoRow('Status', issue['status'] ?? 'N/A'),
          ],
          cardColor: cardColor,
          dividerColor: dividerColor,
        ),

        const SizedBox(height: 16),

        // Borrower Details
        _buildSection(
          title: 'Borrower Details',
          icon: Icons.person,
          children: [
            _buildInfoRow('Name', issue['member_name'] ?? 'N/A'),
            _buildInfoRow('ID', (issue['member_id'] ?? 'N/A').toString()),
            _buildInfoRow('Type', _capitalize(issue['member_type'] ?? 'N/A')),
            _buildInfoRow('Phone', issue['member_phone'] ?? 'N/A'),
            _buildInfoRow('Email', issue['member_email'] ?? 'N/A'),
          ],
          cardColor: cardColor,
          dividerColor: dividerColor,
        ),

        const SizedBox(height: 16),

        // Book Details
        _buildSection(
          title: 'Book Details',
          icon: Icons.menu_book,
          children: [
            _buildInfoRow('Title', issue['book_title'] ?? 'N/A'),
            _buildInfoRow('Author', issue['book_author'] ?? 'N/A'),
            _buildInfoRow('ISBN', issue['isbn'] ?? 'N/A'),
            _buildInfoRow('Category', issue['book_category'] ?? 'N/A'),
            _buildInfoRow('Rack #', issue['rack_number'] ?? 'N/A'),
          ],
          cardColor: cardColor,
          dividerColor: dividerColor,
        ),

        const SizedBox(height: 16),

        // Staff Details
        _buildSection(
          title: 'Staff Details',
          icon: Icons.badge,
          children: [
            _buildInfoRow('Issued By', ''),  // Left blank for handwritten signature
          ],
          cardColor: cardColor,
          dividerColor: dividerColor,
        ),

        const SizedBox(height: 20),

        // Signature Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: dividerColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Borrower Signature',
                      style: TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 40),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: dividerColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Librarian Signature',
                      style: TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Footer note
        Text(
          'This slip serves as a temporary record. Please return the book on or before the due date.',
          style: TextStyle(
            fontSize: 10,
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
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
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd-MMM-yyyy').format(date);
    } catch (e) {
      return isoDate;
    }
  }

  String _formatSlipDate(String? isoDate) {
    final date = isoDate ?? DateTime.now().toIso8601String();
    return _formatDate(date);
  }

  String _formatDateTime(String isoDate) {
    if (isoDate.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd-MMM-yyyy hh:mm a').format(date);
    } catch (e) {
      return isoDate;
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return 'N/A';
    return text[0].toUpperCase() + text.substring(1);
  }

  Future<void> _printSlip(Map<String, dynamic> slip) async {
    try {
      final doc = await _generatePdf(slip);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'BorrowSlip_${slip['slip_number'] ?? 'slip'}.pdf',
      );
    } catch (e) {
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
    final issue = slip['pdf_data'] ?? slip;

    // Initialize Hindi PDF helper for font support
    await HindiPdfHelper.initialize();
    final baseFont = HindiPdfHelper.baseFont;
    final boldFont = HindiPdfHelper.boldFont;

    // Load organization logo
    final logoBytes = await _loadLogo();

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(30),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Organization Header
                if (logoBytes != null)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Image(pw.MemoryImage(logoBytes), width: 70, height: 70),
                        pw.SizedBox(width: 20),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Text(
                                'Uttar Pradesh State Tax Training and Research Institute',
                                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, font: boldFont),
                                textAlign: pw.TextAlign.center,
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                'Lucknow',
                                style: pw.TextStyle(fontSize: 11, font: baseFont, color: PdfColors.grey600),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 90),
                      ],
                    ),
                  )
                else
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'Uttar Pradesh State Tax Training and Research Institute',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ),

                pw.SizedBox(height: 16),

                // Title
                pw.Center(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue800,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      'BOOK BORROW SLIP',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ),

                pw.SizedBox(height: 16),

                // Slip Number
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text('Slip #: ', style: pw.TextStyle(fontSize: 11)),
                    pw.Text(
                      slip['slip_number'] ?? 'N/A',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),

                pw.SizedBox(height: 12),

                // Transaction Details Box
                _buildPdfSection(
                  'Transaction Details',
                  [
                    ['Issue ID', (issue['issue_id'] ?? slip['issue_id'] ?? 'N/A').toString()],
                    ['Issue Date', _formatDate(issue['issue_date'] ?? '')],
                    ['Due Date', _formatDate(issue['due_date'] ?? '')],
                    ['Status', _capitalize(issue['status'] ?? 'N/A')],
                  ],
                  boldFont,
                  baseFont,
                ),

                pw.SizedBox(height: 10),

                // Borrower Details Box
                _buildPdfSection(
                  'Borrower Details',
                  [
                    ['Name', normalizeHindiForDisplay(issue['member_name'] ?? 'N/A')],
                    ['ID', (issue['member_id'] ?? 'N/A').toString()],
                    ['Type', _capitalize(issue['member_type'] ?? 'N/A')],
                    ['Phone', issue['member_phone'] ?? 'N/A'],
                    ['Email', issue['member_email'] ?? 'N/A'],
                  ],
                  boldFont,
                  baseFont,
                ),

                pw.SizedBox(height: 10),

                // Book Details Box
                _buildPdfSection(
                  'Book Details',
                  [
                    ['Title', normalizeHindiForDisplay(issue['book_title'] ?? 'N/A')],
                    ['Author', normalizeHindiForDisplay(issue['book_author'] ?? 'N/A')],
                    ['ISBN', issue['isbn'] ?? 'N/A'],
                    ['Category', normalizeHindiForDisplay(issue['book_category'] ?? 'N/A')],
                    ['Rack #', issue['rack_number'] ?? 'N/A'],
                  ],
                  boldFont,
                  baseFont,
                ),

                pw.SizedBox(height: 10),

                // Issued By Box - leave blank for handwritten signature
                _buildPdfSection(
                  'Issued By',
                  [
                    ['Name', ''],  // Left blank for handwritten signature
                    ['Date & Time', _formatDateTime(issue['issue_date'] ?? '')],
                  ],
                  boldFont,
                  baseFont,
                ),

                pw.SizedBox(height: 16),

                // Signature Section with boxes
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Title
                      pw.Text(
                        'Signatures',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Borrower Signature Box
                          pw.Expanded(
                            child: pw.Container(
                              padding: const pw.EdgeInsets.all(10),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.grey400),
                                borderRadius: pw.BorderRadius.circular(6),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.center,
                                children: [
                                  // Signature space label
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                    decoration: pw.BoxDecoration(
                                      color: PdfColors.grey100,
                                      borderRadius: pw.BorderRadius.circular(4),
                                    ),
                                    child: pw.Text(
                                      'Borrower',
                                      style: pw.TextStyle(
                                        fontSize: 9,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColors.grey700,
                                      ),
                                    ),
                                  ),
                                  pw.SizedBox(height: 8),
                                  // Signature line box
                                  pw.Container(
                                    height: 50,
                                    decoration: pw.BoxDecoration(
                                      border: pw.Border(
                                        bottom: pw.BorderSide(color: PdfColors.grey500, width: 1.5),
                                      ),
                                    ),
                                  ),
                                  pw.SizedBox(height: 6),
                                  pw.Text(
                                    'Signature',
                                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                                  ),
                                  pw.SizedBox(height: 8),
                                  // Name & Date fields
                                  pw.Container(
                                    padding: const pw.EdgeInsets.all(6),
                                    decoration: pw.BoxDecoration(
                                      border: pw.Border.all(color: PdfColors.grey300),
                                      borderRadius: pw.BorderRadius.circular(4),
                                    ),
                                    child: pw.Column(
                                      children: [
                                        pw.Row(
                                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                          children: [
                                            pw.Text('Name:', style: pw.TextStyle(fontSize: 8)),
                                            pw.Container(
                                              width: 80,
                                              height: 12,
                                              decoration: const pw.BoxDecoration(
                                                border: pw.Border(
                                                  bottom: pw.BorderSide(color: PdfColors.grey400),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        pw.SizedBox(height: 4),
                                        pw.Row(
                                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                          children: [
                                            pw.Text('Date:', style: pw.TextStyle(fontSize: 8)),
                                            pw.Container(
                                              width: 80,
                                              height: 12,
                                              decoration: const pw.BoxDecoration(
                                                border: pw.Border(
                                                  bottom: pw.BorderSide(color: PdfColors.grey400),
                                                ),
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
                          ),
                          pw.SizedBox(width: 20),
                          // Librarian Signature Box
                          pw.Expanded(
                            child: pw.Container(
                              padding: const pw.EdgeInsets.all(10),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.grey400),
                                borderRadius: pw.BorderRadius.circular(6),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.center,
                                children: [
                                  // Signature space label
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                    decoration: pw.BoxDecoration(
                                      color: PdfColors.blue100,
                                      borderRadius: pw.BorderRadius.circular(4),
                                    ),
                                    child: pw.Text(
                                      'Librarian',
                                      style: pw.TextStyle(
                                        fontSize: 9,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColors.blue800,
                                      ),
                                    ),
                                  ),
                                  pw.SizedBox(height: 8),
                                  // Signature line box
                                  pw.Container(
                                    height: 50,
                                    decoration: pw.BoxDecoration(
                                      border: pw.Border(
                                        bottom: pw.BorderSide(color: PdfColors.grey500, width: 1.5),
                                      ),
                                    ),
                                  ),
                                  pw.SizedBox(height: 6),
                                  pw.Text(
                                    'Signature',
                                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                                  ),
                                  pw.SizedBox(height: 8),
                                  // Name & Date fields
                                  pw.Container(
                                    padding: const pw.EdgeInsets.all(6),
                                    decoration: pw.BoxDecoration(
                                      border: pw.Border.all(color: PdfColors.grey300),
                                      borderRadius: pw.BorderRadius.circular(4),
                                    ),
                                    child: pw.Column(
                                      children: [
                                        pw.Row(
                                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                          children: [
                                            pw.Text('Name:', style: pw.TextStyle(fontSize: 8)),
                                            pw.Container(
                                              width: 80,
                                              height: 12,
                                              decoration: const pw.BoxDecoration(
                                                border: pw.Border(
                                                  bottom: pw.BorderSide(color: PdfColors.grey400),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        pw.SizedBox(height: 4),
                                        pw.Row(
                                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                          children: [
                                            pw.Text('Date:', style: pw.TextStyle(fontSize: 8)),
                                            pw.Container(
                                              width: 80,
                                              height: 12,
                                              decoration: const pw.BoxDecoration(
                                                border: pw.Border(
                                                  bottom: pw.BorderSide(color: PdfColors.grey400),
                                                ),
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
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 12),

                // Bottom Signature Section
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Signatures',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.SizedBox(height: 16),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          // Borrower Signature
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'Borrower Signature',
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.grey700,
                                  ),
                                ),
                                pw.SizedBox(height: 40),
                                pw.Container(
                                  width: double.infinity,
                                  decoration: const pw.BoxDecoration(
                                    border: pw.Border(
                                      bottom: pw.BorderSide(color: PdfColors.grey500, width: 1),
                                    ),
                                  ),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  'Sign here',
                                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(width: 40),
                          // Librarian Signature
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'Librarian Signature',
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.grey700,
                                  ),
                                ),
                                pw.SizedBox(height: 40),
                                pw.Container(
                                  width: double.infinity,
                                  decoration: const pw.BoxDecoration(
                                    border: pw.Border(
                                      bottom: pw.BorderSide(color: PdfColors.grey500, width: 1),
                                    ),
                                  ),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  'Sign here',
                                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 12),

                // Footer
                pw.Center(
                  child: pw.Text(
                    'Please return the book on or before the due date. Late returns may incur fines.',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return doc;
  }

  Future<Uint8List?> _loadLogo() async {
    try {
      final file = File('assets/images/Office_Logo.png');
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('Could not load logo: $e');
    }
    return null;
  }

  pw.Widget _buildPdfSection(
    String title,
    List<List<String>> rows,
    pw.Font boldFont,
    pw.Font baseFont, {
    bool emptyRightColumn = false,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(5),
                topRight: pw.Radius.circular(5),
              ),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
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
                return pw.TableRow(
                  children: [
                    pw.Text(
                      row[0],
                      style: pw.TextStyle(fontSize: 10, font: baseFont),
                    ),
                    pw.Text(
                      emptyRightColumn ? '' : row[1],
                      style: pw.TextStyle(fontSize: 10, font: boldFont),
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
}

/// Shows the borrow slip preview dialog
Future<void> showBorrowSlipPreview(BuildContext context, Map<String, dynamic> slipData) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => BorrowSlipPreview(slipData: slipData),
  );
}