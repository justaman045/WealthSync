// lib/Services/backup_cipher.dart

import 'dart:convert';
import 'dart:math' show Random;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-GCM envelope for the on-device transaction mirror.
///
/// The device mirror is a complete copy of the user's transaction history. It
/// used to sit in the app sandbox as plain JSON, which is where a rooted
/// device, an `adb backup`, or a stolen unlocked phone finds it — while the
/// privacy policy promised "industry-standard encryption".
///
/// The key is generated on the device and kept in the platform keystore
/// (`flutter_secure_storage`: Android Keystore-wrapped, iOS/macOS Keychain), so
/// the ciphertext and the key never live in the same file. Only the *live
/// mirror* and its preserved pre-deletion copy are sealed; a file the user
/// downloads themselves (`FullBackupService.download`, the backup and the
/// privacy-screen data export) is deliberately plaintext, because it leaves the
/// sandbox and they are expected to open it.
///
/// Failure policy, in both directions:
/// - If the key cannot be read or created, [seal] returns `null` and the caller
///   writes plaintext. A backup that cannot be read back is the one failure
///   this whole file exists to avoid, so degraded storage beats no backup.
/// - [open] returns `null` for a payload it cannot authenticate (corrupted,
///   truncated, or sealed with a key this install no longer has) — a backup
///   written on another install is unrecoverable by design, and the Firestore
///   copy is the authoritative one.
/// - A payload without the [prefix] is legacy plaintext and is returned as-is,
///   so an existing mirror keeps restoring (and is re-sealed on the next write).
class BackupCipher {
  BackupCipher._();

  /// Envelope marker. Versioned because the format may have to change, and a
  /// later version must be able to tell that it is looking at an `enc1:` blob.
  static const String prefix = 'enc1:';

  static const String _keyName = 'local_backup_aes_key_v1';
  static const int _keyBytes = 32; // AES-256
  static const int _nonceBytes = 12; // GCM standard
  static const int _macBytes = 16;

  static final AesGcm _aes = AesGcm.with256bits();
  static final Random _random = Random.secure();

  /// Cached so the keystore is read once per process, not once per backup (a
  /// backup runs after every transaction write).
  static Future<SecretKey?>? _cachedKey;

  /// Test seam: replaces the keystore-backed key.
  @visibleForTesting
  static void useKeyForTest(List<int> bytes) {
    _cachedKey = Future.value(SecretKey(bytes));
  }

  @visibleForTesting
  static void resetForTest() {
    _cachedKey = null;
  }

  static Future<SecretKey?> _key() {
    return _cachedKey ??= _loadKey();
  }

  @visibleForTesting
  static Future<SecretKey?> loadKeyForTest() => _loadKey();

  static Future<SecretKey?> _loadKey() async {
    try {
      const storage = FlutterSecureStorage();
      final stored = await storage.read(key: _keyName);
      if (stored != null) {
        final bytes = base64Decode(stored);
        if (bytes.length == _keyBytes) return SecretKey(bytes);
        // A key of the wrong length cannot decrypt anything; fall through and
        // create a new one rather than failing every backup forever.
        debugPrint('[BackupCipher] stored key has the wrong length, replacing');
      }
      final fresh = _randomBytes(_keyBytes);
      await storage.write(key: _keyName, value: base64Encode(fresh));
      return SecretKey(fresh);
    } catch (e) {
      // No keystore (test host, Linux without libsecret, broken keystore after
      // a device restore). Do not cache the failure — the next run retries.
      debugPrint('[BackupCipher] secure storage unavailable: $e');
      _cachedKey = null;
      return null;
    }
  }

  static List<int> _randomBytes(int length) {
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = _random.nextInt(256);
    }
    return out;
  }

  /// Seals [plaintext], or returns `null` when no key is available.
  ///
  /// A fresh random nonce per call is what makes two backups of identical data
  /// produce different ciphertexts (GCM nonce reuse under one key is fatal).
  static Future<String?> seal(String plaintext) async {
    try {
      final key = await _key();
      if (key == null) return null;
      final box = await _aes.encrypt(utf8.encode(plaintext), secretKey: key);
      final out = Uint8List(
        _nonceBytes + box.cipherText.length + _macBytes,
      );
      out.setRange(0, _nonceBytes, box.nonce);
      out.setRange(
        _nonceBytes,
        _nonceBytes + box.cipherText.length,
        box.cipherText,
      );
      out.setRange(
        _nonceBytes + box.cipherText.length,
        out.length,
        box.mac.bytes,
      );
      return '$prefix${base64Encode(out)}';
    } catch (e) {
      debugPrint('[BackupCipher] seal failed: $e');
      return null;
    }
  }

  /// Opens [stored]: a sealed payload, or legacy plaintext passed through.
  ///
  /// Returns `null` when the payload cannot be authenticated.
  static Future<String?> open(String stored) async {
    if (!stored.startsWith(prefix)) return stored;
    try {
      final key = await _key();
      if (key == null) return null;
      final raw = base64Decode(stored.substring(prefix.length));
      if (raw.length <= _nonceBytes + _macBytes) return null;
      final nonce = raw.sublist(0, _nonceBytes);
      final cipherText = raw.sublist(_nonceBytes, raw.length - _macBytes);
      final mac = Mac(raw.sublist(raw.length - _macBytes));
      final clear = await _aes.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: mac),
        secretKey: key,
      );
      return utf8.decode(clear);
    } catch (e) {
      debugPrint('[BackupCipher] open failed: $e');
      return null;
    }
  }

  /// Whether [stored] is a sealed payload (rather than legacy plaintext).
  static bool isSealed(String stored) => stored.startsWith(prefix);
}
