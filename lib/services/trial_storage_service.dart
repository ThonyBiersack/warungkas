import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persists trial marker data to a location that **survives app uninstallation**,
/// so each physical device only ever gets one trial period regardless of how many
/// times the app is reinstalled.
///
/// Storage paths (in priority order):
///   Windows  → %APPDATA%\WarungKas\trial.dat  (user roaming AppData, never wiped by uninstaller)
///   Android  → /sdcard/Download/.WarungKas/trial.dat  (public storage, survives uninstall)
///              falls back to app-specific external storage if public path is not writable
///   Others   → getApplicationSupportDirectory()  (best-effort fallback)
class TrialStorageService {
  static const _appFolder = 'WarungKas';
  static const _fileName = 'trial.dat';

  static TrialStorageService? _instance;
  static TrialStorageService get instance =>
      _instance ??= TrialStorageService._();

  TrialStorageService._();

  // ── Path resolution ────────────────────────────────────────────────────────

  Future<File> _resolveFile() async {
    final dir = await _resolvePersistentDir();
    if (!await dir.exists()) await dir.create(recursive: true);
    return File(p.join(dir.path, _fileName));
  }

  Future<Directory> _resolvePersistentDir() async {
    // ── Windows ──────────────────────────────────────────────────────────────
    if (!kIsWeb && Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return Directory(p.join(appData, _appFolder));
      }
    }

    // ── Android ──────────────────────────────────────────────────────────────
    if (!kIsWeb && Platform.isAndroid) {
      // Try public Download folder variants — NOT deleted on app uninstall
      for (final candidate in [
        '/storage/emulated/0/Download/.$_appFolder',
        '/sdcard/Download/.$_appFolder',
        '/storage/emulated/0/.$_appFolder',
        '/sdcard/.$_appFolder',
      ]) {
        try {
          final dir = Directory(candidate);
          await dir.create(recursive: true);
          // Quick write-test to verify we actually have permission
          final test = File(p.join(dir.path, '.probe'));
          await test.writeAsString('ok');
          await test.delete();
          return dir;
        } catch (_) {
          continue;
        }
      }
      // Fallback: app-specific external storage (IS deleted on uninstall,
      // but better than internal which has no chance on Android 11+ scoped storage)
      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) return Directory(p.join(ext.path, _appFolder));
      } catch (_) {}
    }

    // ── Universal fallback ────────────────────────────────────────────────────
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, _appFolder));
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Reads persisted trial data. Returns an empty map if the file does not
  /// exist yet (i.e. this is the very first install on this device).
  Future<Map<String, String>> read() async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) return {};
      final raw = await file.readAsString();
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) {
      debugPrint('[TrialStorage] read error: $e');
      return {};
    }
  }

  /// Merges [data] into the existing persisted trial file and saves it.
  /// Existing keys not present in [data] are preserved.
  Future<void> write(Map<String, String> data) async {
    try {
      final file = await _resolveFile();
      final existing = await read();
      existing.addAll(data);
      await file.writeAsString(json.encode(existing));
    } catch (e) {
      debugPrint('[TrialStorage] write error: $e');
    }
  }

  // ── Stable device code ─────────────────────────────────────────────────────

  /// Derives a stable device code from the machine hostname.
  ///
  /// This acts as a secondary source of truth: if trial.dat is accidentally
  /// deleted (e.g. user clears AppData manually), re-deriving from the hostname
  /// produces the same code so existing license keys remain valid.
  static String deriveDeviceCode() {
    try {
      final hostname = Platform.localHostname.trim();
      if (hostname.isNotEmpty) {
        final hmac = Hmac(sha256, utf8.encode('WARUNGKAS_DEVICE_SEED_2026'));
        final digest = hmac.convert(utf8.encode(hostname));
        return 'WAK-${digest.toString().substring(0, 6).toUpperCase()}';
      }
    } catch (_) {}
    // Absolute last resort — random per-run (should never reach here in practice)
    return 'WAK-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase().substring(0, 6)}';
  }
}
