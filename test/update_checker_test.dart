import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/update_checker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateChecker', () {
    test('UpdateInstallResult enum values exist', () {
      expect(UpdateInstallResult.values, contains(UpdateInstallResult.downloadFailed));
      expect(UpdateInstallResult.values, contains(UpdateInstallResult.installed));
      expect(UpdateInstallResult.values, contains(UpdateInstallResult.noUpdate));
    });

    test('instance can be created', () {
      final checker = UpdateChecker();
      expect(checker, isNotNull);
    });
  });
}
