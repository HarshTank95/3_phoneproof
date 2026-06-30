import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/models/report.dart';
import '../../core/models/test_result.dart';

/// Builds the shareable Trust Certificate as a PDF. The SHA-256 payload hash is
/// embedded as a QR code for tamper-evidence.
class CertificateBuilder {
  static Future<Uint8List> buildPdf(Report report) async {
    final doc = pw.Document();
    final dark = PdfColor.fromInt(0xFF0E1218);
    final accentDeep = PdfColor.fromInt(0xFF1C8C7E);

    PdfColor verdictColor() {
      switch (report.verdict) {
        case Verdict.genuine:
          return PdfColor.fromInt(0xFF2FA85F);
        case Verdict.caution:
          return PdfColor.fromInt(0xFFD79A20);
        case Verdict.highRisk:
          return PdfColor.fromInt(0xFFD64545);
      }
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(28),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text('PhoneProof',
                          style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: dark)),
                      pw.Text('Trust Certificate', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ]),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: report.payloadHash,
                      width: 84,
                      height: 84,
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Divider(color: PdfColors.grey400),
                pw.SizedBox(height: 8),

                // Device + score
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text(report.build.marketName,
                            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('Android ${report.build.release} • Forensic scan',
                            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                        if (report.imei != null && report.imei!.isNotEmpty)
                          pw.Text('IMEI (entered, unverifiable): ${report.imei}',
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                      ]),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: pw.BoxDecoration(
                        color: verdictColor(),
                        borderRadius: pw.BorderRadius.circular(12),
                      ),
                      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                        pw.Text('${report.trustScore}',
                            style: pw.TextStyle(fontSize: 34, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        pw.Text(report.verdict.label,
                            style: const pw.TextStyle(fontSize: 11, color: PdfColors.white)),
                      ]),
                    ),
                  ],
                ),

                pw.SizedBox(height: 16),

                // Mismatches
                if (report.mismatches.isNotEmpty) ...[
                  pw.Text('Claimed vs Real',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                  pw.SizedBox(height: 6),
                  ...report.mismatches.map((m) => pw.Bullet(
                        text: '${m.label}: claimed "${m.claimed}" vs real "${m.real}" — ${m.note}',
                        style: const pw.TextStyle(fontSize: 10),
                      )),
                  pw.SizedBox(height: 12),
                ],

                // Top reasons
                pw.Text('Why this score',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                ...report.reasons.take(6).map((r) => pw.Bullet(
                      text: '${r.text}${r.delta != 0 ? ' (${r.delta})' : ''}',
                      style: const pw.TextStyle(fontSize: 10),
                    )),

                pw.SizedBox(height: 12),

                // Groups table
                ...report.groups.map((g) => pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(height: 6),
                        pw.Text(g.title,
                            style: pw.TextStyle(
                                fontSize: 12, fontWeight: pw.FontWeight.bold, color: accentDeep)),
                        pw.SizedBox(height: 2),
                        ...g.checks.map((c) => pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 1),
                              child: pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.SizedBox(
                                      width: 150,
                                      child: pw.Text(c.title, style: const pw.TextStyle(fontSize: 9))),
                                  pw.SizedBox(
                                      width: 70,
                                      child: pw.Text(c.status.label,
                                          style: pw.TextStyle(
                                              fontSize: 9, fontWeight: pw.FontWeight.bold))),
                                  pw.Expanded(
                                      child: pw.Text(c.detail,
                                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
                                ],
                              ),
                            )),
                      ],
                    )),

                pw.Spacer(),
                pw.Divider(color: PdfColors.grey400),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Report ID: ${report.reportId}',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.Text(report.timestamp.toString().split('.').first,
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Text('SHA-256: ${report.payloadHash}',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                pw.SizedBox(height: 2),
                pw.Text(
                    'Battery-truth fields are hardware-protected and resilient to spoofing. Play Integrity is a strong signal, not absolute proof. IMEI cannot be verified by third-party apps on Android 10+. Some values depend on the device and may be unavailable.',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }
}
