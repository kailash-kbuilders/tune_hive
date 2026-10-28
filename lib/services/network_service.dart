import 'dart:io';

/// Tiny network probe — no plugin needed. A DNS lookup is enough to know
/// whether the app should show online songs or fall back to the device.
class NetworkService {
  static Future<bool> isOnline() async {
    try {
      final result = await InternetAddress.lookup('archive.org')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
