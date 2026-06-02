import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';

class InvoiceSharePrintService {
  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  static final _dateFmt = DateFormat('dd MMM yyyy - HH:mm');

  /// Formats the invoice as a beautiful text message with emojis.
  static String formatTransactionText(TransactionModel tx, List<TransactionItem> items) {
    final isHutang = tx.status == 'hutang';
    final buffer = StringBuffer();

    buffer.writeln('=========================');
    buffer.writeln('       🏪 *WARUNGKAS*    ');
    buffer.writeln('      🧾 Bukti Transaksi  ');
    buffer.writeln('=========================');
    buffer.writeln('📅 Tanggal   : ${_dateFmt.format(tx.createdAt ?? DateTime.now())}');
    buffer.writeln('👤 Pembeli   : ${tx.customerName?.trim().isNotEmpty == true ? tx.customerName!.trim() : "Tanpa Nama"}');
    buffer.writeln('⚡ Status    : ${isHutang ? "🔴 HUTANG" : "🟢 LUNAS"}');
    
    if (tx.paymentMethod == 'hutang' && tx.status == 'lunas') {
      buffer.writeln('💳 Tipe      : Pelunasan Hutang');
    } else {
      buffer.writeln('💳 Tipe      : ${tx.paymentMethod == "hutang" ? "Catatan Hutang" : "Tunai"}');
    }
    buffer.writeln('=========================');
    buffer.writeln('🛒 *Rincian Belanja:*');

    for (final item in items) {
      final subtotal = item.quantity * item.price;
      buffer.writeln('- ${item.productName}');
      buffer.writeln('  ${item.quantity} x ${_currency.format(item.price)} = ${_currency.format(subtotal)}');
    }

    buffer.writeln('-------------------------');
    buffer.writeln('💰 *Total     : ${_currency.format(tx.totalAmount)}*');

    if (isHutang) {
      buffer.writeln('💵 Dibayar   : ${_currency.format(tx.paidAmount)}');
      buffer.writeln('⚠️ Sisa Hutang: ${_currency.format(tx.totalAmount - tx.paidAmount)}');
    } else {
      if (tx.paidAmount > 0) {
        buffer.writeln('💵 Dibayar   : ${_currency.format(tx.paidAmount)}');
        buffer.writeln('🔄 Kembalian : ${_currency.format(tx.changeAmount)}');
      }
    }
    
    buffer.writeln('=========================');
    if (isHutang) {
      buffer.writeln('  ⚠️ JANGAN LUPA LUNASI   ');
      buffer.writeln('        HUTANG!!! ⚠️       ');
    } else {
      buffer.writeln(' Terima kasih telah berbelanja ');
      buffer.writeln('   di toko kami! Semoga harimu ');
      buffer.writeln('        menyenangkan! ✨        ');
    }
    buffer.writeln('=========================');

    return buffer.toString();
  }

  /// Generates the receipt PDF document with custom tailored dimensions.
  static Future<pw.Document> _buildPdfDocument(PdfPageFormat format, TransactionModel tx, List<TransactionItem> items) async {
    final pdf = pw.Document();

    // Load custom shop name from SharedPreferences
    String shopName = 'WARUNGKAS';
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('shop_name');
      if (savedName != null && savedName.trim().isNotEmpty) {
        shopName = savedName.trim().toUpperCase();
      }
    } catch (e) {
      debugPrint('Gagal membaca nama toko: $e');
    }

    // Prefix with "WARUNG" if it doesn't already start with it
    if (!shopName.startsWith('WARUNG')) {
      shopName = 'WARUNG $shopName';
    }

    // Try loading the logo image from assets
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/warungkas-logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('Gagal memuat logo: $e');
    }

    pdf.addPage(
      pw.Page(
        pageFormat: format.copyWith(
          marginTop: 0,
          marginBottom: 0,
          marginLeft: 0,
          marginRight: 0,
        ),
        build: (pw.Context context) {
          final isHutang = tx.status == 'hutang';
          
          return pw.Container(
            color: PdfColors.white,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 5 * PdfPageFormat.mm,
              vertical: 6 * PdfPageFormat.mm,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Shop Logo Header
                if (logoImage != null) ...[
                  pw.Center(
                    child: pw.Image(
                      logoImage,
                      width: 48,
                      height: 48,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                ],

                // Shop Name (H3 bold style - Loaded Dynamically)
                pw.Center(
                  child: pw.Text(
                    shopName,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                
                pw.SizedBox(height: 6),
                
                // Dashed divider
                _dashedDivider(),
                pw.SizedBox(height: 4),

                // Metadata Info
                _pdfInfoRow('Tanggal:', _dateFmt.format(tx.createdAt ?? DateTime.now())),
                _pdfInfoRow('Pembeli:', tx.customerName?.trim().isNotEmpty == true ? tx.customerName!.trim() : "Tanpa Nama"),
                _pdfInfoRow('Status:', isHutang ? 'HUTANG' : 'LUNAS'),
                _pdfInfoRow(
                  'Tipe:',
                  tx.paymentMethod == 'hutang'
                      ? (tx.status == 'lunas' ? 'Pelunasan Hutang' : 'Catatan Hutang')
                      : 'Tunai',
                ),
                pw.SizedBox(height: 4),

                _dashedDivider(),
                pw.SizedBox(height: 6),

                // Rincian Belanja title
                pw.Text(
                  'Rincian Belanja:',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),

                // Shopping items
                pw.Column(
                  children: items.map((item) {
                    final subtotal = item.quantity * item.price;
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            item.productName,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                '  ${item.quantity} x ${_currency.format(item.price)}',
                                style: const pw.TextStyle(fontSize: 9),
                              ),
                              pw.Text(
                                _currency.format(subtotal),
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                
                pw.SizedBox(height: 4),
                _dashedDivider(),
                pw.SizedBox(height: 6),

                // Total & Summary Rows
                _pdfTotalRow('TOTAL:', _currency.format(tx.totalAmount)),
                
                if (isHutang) ...[
                  _pdfInfoRow('Dibayar:', _currency.format(tx.paidAmount)),
                  _pdfInfoRow('Sisa Hutang:', _currency.format(tx.totalAmount - tx.paidAmount), isBold: true),
                ] else ...[
                  if (tx.paidAmount > 0) ...[
                    _pdfInfoRow('Dibayar:', _currency.format(tx.paidAmount)),
                    _pdfInfoRow('Kembalian:', _currency.format(tx.changeAmount), isBold: true),
                  ],
                ],

                pw.SizedBox(height: 8),
                _dashedDivider(),
                pw.SizedBox(height: 8),

                // Footer Greetings
                pw.Center(
                  child: pw.Text(
                    isHutang ? '⚠️ JANGAN LUPA LUNASI HUTANG!!! ⚠️' : 'Terima kasih telah berbelanja!',
                    style: pw.TextStyle(
                      fontSize: isHutang ? 9 : 8,
                      fontWeight: isHutang ? pw.FontWeight.bold : pw.FontWeight.normal,
                      color: isHutang ? PdfColors.red800 : PdfColors.black,
                      fontStyle: isHutang ? pw.FontStyle.normal : pw.FontStyle.italic,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                if (!isHutang)
                  pw.Center(
                    child: pw.Text(
                      'Semoga harimu menyenangkan. ✨',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontStyle: pw.FontStyle.italic,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }

  /// Converts the receipt PDF to a high-resolution PNG image and opens the native OS Share Sheet to share it as a file.
  static Future<void> shareInvoice(TransactionModel tx, List<TransactionItem> items) async {
    final isHutang = tx.status == 'hutang';
    
    // 1. Calculate optimal page height in points based on item count to avoid extra white spaces.
    // We add 56 points to accommodate the new logo + app highlight spacing at the top!
    final double logoHeight = 60.0;
    final double itemRowsHeight = items.length * 28.0;
    final double summaryHeight = isHutang ? 45.0 : (tx.paidAmount > 0 ? 45.0 : 25.0);
    final double calculatedHeight = 175.0 + itemRowsHeight + summaryHeight + logoHeight;
    final double pageHeight = calculatedHeight.clamp(280.0, 1600.0);

    final shareFormat = PdfPageFormat(
      76 * PdfPageFormat.mm, // standard paper width
      pageHeight,
    );

    // 2. Generate PDF document asynchronously
    final pdf = await _buildPdfDocument(shareFormat, tx, items);
    final pdfBytes = await pdf.save();

    // 3. Rasterize the PDF page to a crisp PNG image (300 DPI for premium quality)
    Uint8List? pngBytes;
    await for (final page in Printing.raster(pdfBytes, pages: [0], dpi: 300)) {
      pngBytes = await page.toPng();
      break; // Only need the first page
    }

    if (pngBytes == null) {
      throw Exception('Gagal membuat gambar struk kasir.');
    }

    // 4. Save PNG to a secure temporary directory
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${tempDir.path}/Struk_WarungKas_$timestamp.png');
    await file.writeAsBytes(pngBytes);

    // 5. Open the native Share Sheet sending the XFile image directly to WhatsApp/other apps
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      subject: 'Bukti Transaksi - ${tx.customerName ?? "Pelanggan"}',
    );
  }

  /// Prints the invoice using a beautiful thermal-compatible PDF document.
  static Future<void> printReceipt(TransactionModel tx, List<TransactionItem> items) async {
    await Printing.layoutPdf(
      name: 'Struk_WarungKas_${tx.id ?? "tx"}',
      onLayout: (PdfPageFormat format) async {
        final pdf = await _buildPdfDocument(format, tx, items);
        return pdf.save();
      },
    );
  }

  // --- Helper Methods ---

  static pw.Widget _dashedDivider() {
    return pw.Container(
      height: 1,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: PdfColors.grey500,
            width: 0.8,
            style: pw.BorderStyle.dashed,
          ),
        ),
      ),
    );
  }

  static pw.Widget _pdfInfoRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey800,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pdfTotalRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
