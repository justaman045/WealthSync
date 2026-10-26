import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contract test for `.github/workflows/flutter_build.yml`.
///
/// The CI pipeline is the only place several invariants are enforced (release
/// signing, the single universal APK, the R8 launch smoke test, rules
/// validation, least-privilege tokens). A refactor that drops a `needs:` edge
/// or re-widens `permissions` fails silently — the workflow still runs, it just
/// stops protecting anything. This test pins the structure so a regression is a
/// red unit test instead of a bad release.
///
/// It asserts workflow *shape*, not YAML semantics: the file is read as text and
/// sliced by job (2-space indent). Keep job keys at two spaces.
void main() {
  final workflowFile = File('.github/workflows/flutter_build.yml');
  late String workflow;
  late List<String> jobNames;

  /// Returns the lines of one job, from `  <job>:` up to the next 2-space key.
  String job(String name) {
    final lines = workflow.split('\n');
    final start = lines.indexOf('  $name:');
    expect(start, isNot(-1), reason: 'job "$name" is missing');
    final buffer = <String>[];
    for (var i = start; i < lines.length; i++) {
      final line = lines[i];
      final isNextJob =
          i > start && RegExp(r'^  [A-Za-z0-9_-]+:$').hasMatch(line);
      final isTopLevel = i > start && RegExp(r'^[A-Za-z]').hasMatch(line);
      if (isNextJob || isTopLevel) break;
      buffer.add(line);
    }
    return buffer.join('\n');
  }

  setUpAll(() {
    expect(workflowFile.existsSync(), isTrue);
    workflow = workflowFile.readAsStringSync();
    jobNames = RegExp(r'^  ([A-Za-z0-9_-]+):$', multiLine: true)
        .allMatches(workflow)
        .map((m) => m.group(1)!)
        .toList();
  });

  group('jobs', () {
    test('all pipeline stages exist', () {
      expect(
        jobNames,
        containsAll(<String>[
          'test',
          'rules',
          'integration_test',
          'deploy_firebase',
          'build',
          'android_smoke',
          'release',
          'build_web',
        ]),
      );
    });

    test('the release only publishes after the APK smoke test passed', () {
      final release = job('release');
      expect(
        RegExp(r'needs: \[[^\]]*build[^\]]*\]').hasMatch(release),
        isTrue,
      );
      expect(release, contains('android_smoke'));
      expect(
        release,
        contains('needs.android_smoke.result == \'success\''),
        reason: 'A skipped or failed smoke test must block publishing.',
      );
    });

    test('the Android build is gated on unit + rules + E2E status', () {
      final build = job('build');
      expect(build, contains('needs.test.result == \'success\''));
      expect(build, contains('needs.rules.result == \'success\''));
      expect(
        build,
        contains('needs.integration_test.result == \'success\''),
        reason: 'An opted-in E2E run must be able to block the release.',
      );
      expect(build, contains('needs.integration_test.result == \'skipped\''));
    });

    test('the nightly schedule never publishes', () {
      expect(
        RegExp(r'cron:').hasMatch(workflow),
        isTrue,
        reason: 'A nightly E2E run keeps coverage from rotting between releases.',
      );
      for (final publishJob in ['build', 'release', 'build_web']) {
        expect(
          job(publishJob),
          contains("github.event_name != 'schedule'"),
          reason: '$publishJob must not run on the nightly schedule.',
        );
      }
    });

    test('the integration suite runs through the canonical runner', () {
      final integration = job('integration_test');
      expect(
        integration,
        contains('script: bash tool/run_integration_tests.sh'),
        reason: 'The emulator action executes `script:` one line at a time; a '
            'multi-line script silently only runs its first line.',
      );
      expect(
        File('tool/run_integration_tests.sh').existsSync(),
        isTrue,
      );
    });

    test('a master push gates the release on a critical E2E subset', () {
      final integration = job('integration_test');
      expect(
        integration,
        contains("github.event_name == 'push'"),
        reason: 'Every master push must be driven end-to-end before its APK '
            'can publish; a nightly-only suite lets a release ship untested.',
      );
      expect(integration, contains('E2E_FILES'));
      final runner =
          File('tool/run_integration_tests.sh').readAsStringSync();
      expect(
        runner,
        contains('E2E_FILES'),
        reason: 'The workflow filter is inert unless the runner honours it.',
      );
      expect(
        runner,
        contains('names a missing test file'),
        reason: 'A typo in E2E_FILES must fail the job, not run zero files and '
            'report a false green.',
      );
      // Every file named by the release gate must exist, or the gate fails
      // open on the first push that touches it.
      for (final name in <String>[
        'settings_test.dart',
        'full_backup_test.dart',
        'data_management_test.dart',
        'transaction_management_test.dart',
      ]) {
        expect(integration, contains(name));
        expect(File('integration_test/$name').existsSync(), isTrue);
      }
    });

    test('the release smoke test installs the built artifact', () {
      final smoke = job('android_smoke');
      expect(smoke, contains('bash tool/smoke_release_apk.sh'));
      expect(
        File('tool/smoke_release_apk.sh').existsSync(),
        isTrue,
        reason: 'R8 minify is ON: a release-only crash is invisible to every '
            'debug-build test.',
      );
    });

    test('publishing jobs refuse to run off master', () {
      for (final name in ['build', 'release', 'build_web']) {
        expect(
          job(name),
          contains("github.ref == 'refs/heads/master'"),
          reason: '$name must not publish from a manually dispatched feature '
              'branch.',
        );
      }
    });

    test('E2E fails fast when its credentials are missing', () {
      expect(
        job('integration_test'),
        contains('Validate E2E credentials'),
        reason: 'Empty dart-defines surface as a misleading '
            'firebase_auth/channel-error after the emulator has booted.',
      );
    });

    test('rules are validated against both emulators', () {
      final rules = job('rules');
      expect(rules, contains('bash tool/rules_tests/run.sh'));
      expect(File('tool/rules_tests/run.sh').existsSync(), isTrue);
      expect(File('tool/rules_tests/run.js').existsSync(), isTrue);
      expect(
        File('tool/rules_tests/package-lock.json').existsSync(),
        isTrue,
        reason: 'CI installs with `npm ci`, which requires a lockfile.',
      );
    });

    test('production rules deploy is dispatch-only and dry-run first', () {
      final deploy = job('deploy_firebase');
      expect(
        deploy,
        contains("github.event_name == 'workflow_dispatch'"),
        reason: 'A push must never change production security rules.',
      );
      expect(deploy, contains("github.event.inputs.deploy_firebase == 'true'"));
      expect(deploy, contains("github.ref == 'refs/heads/master'"));
      expect(deploy, contains("needs.test.result == 'success'"));
      expect(deploy, contains("needs.rules.result == 'success'"));
      expect(deploy, contains('environment: production'));
      expect(deploy, contains('--non-interactive'));
      expect(deploy, contains('moneycontroljustaman045'));
      expect(
        deploy.indexOf('--dry-run'),
        lessThan(deploy.indexOf('Deploy Firestore rules')),
        reason: 'The dry run must compile the rules before anything is written.',
      );
      // This project stays on the Spark plan, where Cloud Storage cannot be
      // provisioned: `--only storage` always aborts with "Firebase Storage has
      // not been set up" and would prevent the Firestore rules — the ones that
      // actually guard user data — from deploying at all.
      expect(
        deploy,
        isNot(contains(',storage')),
        reason: 'No Storage bucket exists on Spark; adding the target aborts '
            'the whole deploy.',
      );
      expect(deploy, contains('Deploy Firestore rules and indexes'));
      expect(
        deploy,
        contains(
          r'FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}',
        ),
        reason: 'The deploy token is read from the environment, never a script.',
      );
    });

    test('Android jobs share one google-services/NDK setup action', () {
      expect(
        File('.github/actions/android-setup/action.yml').existsSync(),
        isTrue,
      );
      for (final name in ['build', 'integration_test']) {
        expect(
          job(name),
          contains('uses: ./.github/actions/android-setup'),
          reason: '$name must not carry its own copy of the secret/NDK steps.',
        );
      }
    });

    test('the web build compiles on every event, not just at deploy time', () {
      expect(
        job('test'),
        contains('flutter build web --release'),
        reason: 'dart2js rejects types the analyzer accepts; that error must '
            'fail the PR, not the post-merge deploy.',
      );
      expect(job('build_web'), contains('flutter build web --release'));
    });

    test('the CI gate itself stays in place', () {
      final test = job('test');
      expect(test, contains('flutter analyze --no-fatal-infos'));
      expect(test, contains('bash tool/check_ui_strings.sh --strict'));
      expect(test, contains('flutter test'));
    });
  });

  group('security', () {
    test('the workflow token is read-only by default', () {
      final permissions = workflow.split('\npermissions:\n')[1].split(
            RegExp(r'^[A-Za-z]', multiLine: true),
          )[0];
      expect(permissions, contains('contents: read'));
      expect(
        workflow,
        isNot(contains('pages: write')),
        reason: 'peaceiris/actions-gh-pages pushes a branch; it never uses the '
            'Pages API.',
      );
      expect(workflow, isNot(contains('id-token: write')));
    });

    test('only the pushing jobs get contents: write', () {
      expect(job('test'), contains('contents: read'));
      expect(job('build'), contains('contents: read'));
      expect(job('deploy_firebase'), contains('contents: read'));
      expect(job('release'), contains('contents: write'));
      expect(job('build_web'), contains('contents: write'));
    });

    test('dependabot cannot re-redden CI for unfixable harness deps', () {
      final config = File('.github/dependabot.yml');
      expect(config.existsSync(), isTrue);
      final yaml = config.readAsStringSync();
      // YAML requires quoting for scoped names (`@grpc/grpc-js` starts with a
      // reserved indicator), so compare without quotes.
      final normalized = yaml.replaceAll('"', '');
      expect(yaml, contains('package-ecosystem: npm'));
      expect(yaml, contains('directory: /tool/rules_tests'));
      // These three are firebase-tools' transitive dependencies (CI-only, never
      // shipped). Their only "fix" downgrades firebase-tools, so Dependabot
      // security jobs fail with `security_update_not_possible` and paint every
      // push red. Removing an ignore re-breaks the default branch.
      for (final dep in <String>[
        'uuid',
        '@grpc/grpc-js',
        '@opentelemetry/core',
      ]) {
        expect(normalized, contains('dependency-name: $dep'));
      }
      expect(yaml, contains('package-ecosystem: github-actions'));
    });

    test('secrets are passed through env, never interpolated into a script', () {
      expect(
        workflow,
        isNot(contains("echo '\${{ secrets.")),
        reason: 'A secret interpolated into `run:` is rendered into the script '
            'and breaks on quotes.',
      );
      expect(workflow, isNot(contains('echo "\${{ secrets.')));
      expect(workflow, contains(r'$UPLOAD_KEYSTORE'));
      expect(workflow, contains('UPLOAD_KEYSTORE: \${{ secrets.UPLOAD_KEYSTORE }}'));
      // The google-services secret is forwarded as a composite-action input,
      // where it is read from the environment (`$GS_JSON`).
      final setupAction =
          File('.github/actions/android-setup/action.yml').readAsStringSync();
      expect(setupAction, contains(r'$GS_JSON'));
      // action.yml is itself a template — every `${{ … }}` in it is evaluated,
      // including inside `description:`. A `secrets.` reference there fails the
      // job at manifest-load time ("Unrecognized named-value: 'secrets'"), so
      // the secret must reach this action as an input only.
      expect(
        setupAction,
        isNot(contains('secrets.')),
        reason: 'Secrets are not available in a composite action manifest.',
      );
      expect(
        setupAction,
        contains('GS_JSON: \${{ inputs.google_services_json }}'),
      );
      expect(
        workflow,
        contains('google_services_json: \${{ secrets.GOOGLE_SERVICES_JSON }}'),
      );

      // The jobs that never build an Android artifact must not touch the
      // Android Firebase config at all.
      expect(job('test'), isNot(contains('google-services.json')));
      expect(job('build_web'), isNot(contains('google-services.json')));
    });

    test('the CI version commit cannot re-trigger the workflow', () {
      final onBlock = workflow.split('\non:\n')[1].split('\njobs:\n')[0];
      expect(onBlock, contains('- "pubspec.yaml"'));
      expect(onBlock, contains('- "app_version.json"'));
    });

    test('the release-commit guard does not parse the commit message', () {
      // Actions' `contains()`/`startsWith()` are case-insensitive, so a guard
      // like `!contains(head_commit.message, 'CI:')` is false for every commit
      // titled "ci: …" — the version bump is then silently skipped even though
      // the release was published.
      expect(
        workflow,
        isNot(contains('contains(github.event.head_commit.message')),
      );
      expect(
        job('release'),
        contains(
          "github.event.head_commit.committer.name != 'GitHub Actions'",
        ),
        reason: 'The loop guard must key on the committer identity, not on a '
            'case-insensitive message match.',
      );
    });
  });
}
