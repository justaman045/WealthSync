import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/backup_cipher.dart';

/// The device mirror is a full copy of the user's transaction history. These
/// tests pin the envelope contract the storage layer depends on: a sealed
/// payload round-trips, an unauthentic one is reported as "no backup" rather
/// than thrown, and legacy plaintext keeps restoring.
void main() {
  final key = List<int>.generate(32, (i) => i * 7 % 256);

  setUp(() => BackupCipher.useKeyForTest(key));
  tearDown(BackupCipher.resetForTest);

  test('seals and opens a payload', () async {
    const plaintext = '[{"id":"tx-1","amount":-125.5,"note":"coffee ☕"}]';
    final sealed = await BackupCipher.seal(plaintext);
    expect(sealed, isNotNull);
    expect(sealed, isNot(contains('coffee')));
    expect(BackupCipher.isSealed(sealed!), isTrue);
    expect(await BackupCipher.open(sealed), plaintext);
  });

  test('uses a fresh nonce for every seal', () async {
    // GCM nonce reuse under one key is a catastrophic failure, not a style
    // issue: identical ciphertexts would leak that the history did not change.
    final a = await BackupCipher.seal('[]');
    final b = await BackupCipher.seal('[]');
    expect(a, isNot(b));
    expect(await BackupCipher.open(a!), '[]');
    expect(await BackupCipher.open(b!), '[]');
  });

  test('rejects a tampered payload', () async {
    final sealed = (await BackupCipher.seal('[{"id":"tx-1"}]'))!;
    // Flip one base64 character in the middle of the ciphertext.
    final body = sealed.substring(BackupCipher.prefix.length);
    final index = body.length ~/ 2;
    final char = body[index] == 'A' ? 'B' : 'A';
    final tampered = BackupCipher.prefix +
        body.replaceRange(index, index + 1, char);
    expect(await BackupCipher.open(tampered), isNull);
  });

  test('rejects a truncated payload', () async {
    final sealed = (await BackupCipher.seal('[]'))!;
    final body = sealed.substring(BackupCipher.prefix.length);
    final truncated = BackupCipher.prefix + body.substring(0, 8);
    expect(await BackupCipher.open(truncated), isNull);
  });

  test('a payload sealed with another key cannot be opened', () async {
    final sealed = (await BackupCipher.seal('[{"id":"tx-1"}]'))!;
    // A different install (or a wiped keystore) has a different key.
    BackupCipher.useKeyForTest(List<int>.generate(32, (i) => 255 - i));
    expect(await BackupCipher.open(sealed), isNull);
  });

  test('legacy plaintext passes through untouched', () async {
    const legacy = '[{"id":"tx-1","amount":-10}]';
    expect(BackupCipher.isSealed(legacy), isFalse);
    expect(await BackupCipher.open(legacy), legacy);
  });

  test('a missing key makes seal report failure instead of throwing', () async {
    // No keystore in the test host: the caller writes plaintext rather than
    // losing the backup entirely.
    BackupCipher.resetForTest();
    final sealed = await BackupCipher.seal('[]');
    expect(sealed, isNull);
    // And reading a sealed payload without the key is "no backup", not a crash.
    BackupCipher.useKeyForTest(key);
    final withKey = (await BackupCipher.seal('[]'))!;
    BackupCipher.resetForTest();
    expect(await BackupCipher.open(withKey), isNull);
  });
}
