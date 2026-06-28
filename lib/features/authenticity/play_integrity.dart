import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/models/spec_truth.dart';

/// Play Integrity certified-genuine check.
///
/// The real flow is: request a hardware-backed integrity token on-device, then
/// forward it to a free serverless verifier (Cloudflare Worker / cloud function
/// linked to a free Google Cloud project) that returns the `deviceIntegrity`
/// verdict. Until that backend is configured here, the badge degrades to
/// "Not checked" — and nothing else breaks. If the network is down we also
/// return notChecked.
class PlayIntegrity {
  /// Configure these two to enable the certified-genuine badge.
  /// Leave [verifierEndpoint] empty to keep the feature in "Not checked" mode.
  static const String verifierEndpoint = ''; // e.g. https://your-worker.workers.dev/verify
  static const int cloudProjectNumber = 0; // your Google Cloud project number

  static bool get isConfigured => verifierEndpoint.isNotEmpty && cloudProjectNumber != 0;

  static Future<IntegrityVerdict> check() async {
    if (!isConfigured) return IntegrityVerdict.notChecked;

    // Network gate — offline => not checked, gracefully.
    final conn = await Connectivity().checkConnectivity();
    if (conn.contains(ConnectivityResult.none) || conn.isEmpty) {
      return IntegrityVerdict.notChecked;
    }

    try {
      // NOTE: obtaining the on-device integrity token requires the native
      // com.google.android.play:integrity SDK wired through a platform channel.
      // When that token is available, POST it here and parse the verdict.
      final client = HttpClient();
      final req = await client.postUrl(Uri.parse(verifierEndpoint));
      req.headers.set('content-type', 'application/json');
      req.add(utf8.encode(jsonEncode({'projectNumber': cloudProjectNumber})));
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      client.close();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final verdict = (json['deviceIntegrity'] ?? '').toString().toUpperCase();
      if (verdict.contains('MEETS_DEVICE_INTEGRITY') || verdict.contains('MEETS_STRONG')) {
        return IntegrityVerdict.meets;
      }
      return IntegrityVerdict.fails;
    } catch (_) {
      return IntegrityVerdict.error;
    }
  }
}
