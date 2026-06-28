import 'dart:typed_data';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/report.dart';
import 'certificate_builder.dart';

class ShareService {
  /// Share the certificate as a PDF via the system share sheet.
  static Future<void> sharePdf(Report report) async {
    final bytes = await CertificateBuilder.buildPdf(report);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/PhoneProof_${report.reportId}.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'PhoneProof Trust Certificate — ${report.build.marketName}',
      text: 'PhoneProof verified ${report.build.marketName}: '
          'Trust Score ${report.trustScore}/100 (${report.verdict.label}). '
          'Report ${report.reportId}.',
    );
  }

  /// Print / save the PDF using the OS print dialog.
  static Future<void> printPdf(Report report) async {
    await Printing.layoutPdf(onLayout: (_) => CertificateBuilder.buildPdf(report));
  }

  /// Share a pre-rendered certificate image (captured from the results card).
  static Future<void> shareImage(Uint8List png, Report report) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/PhoneProof_${report.reportId}.png');
    await file.writeAsBytes(png);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      subject: 'PhoneProof Trust Certificate',
      text: 'Trust Score ${report.trustScore}/100 — ${report.verdict.label}',
    );
  }
}
