import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Store-submission settings (2026-10-22) that a stray edit in Xcode or
/// Gradle could silently undo. See RELEASE.md for why each one matters.
void main() {
  String read(String path) => File(path).readAsStringSync();

  group('Android', () {
    final gradle = read('android/app/build.gradle.kts');
    final manifest = read('android/app/src/main/AndroidManifest.xml');

    test('store identity is mn.uziy.viewer; debug installs beside it', () {
      expect(gradle, contains('namespace = "mn.uziy.viewer"'));
      expect(gradle, contains('applicationId = "mn.uziy.viewer"'));
      expect(gradle, contains('applicationIdSuffix = ".dev"'));
      expect(
        File('android/app/src/main/kotlin/mn/uziy/viewer/MainActivity.kt')
            .readAsStringSync(),
        startsWith('package mn.uziy.viewer'),
      );
      expect('$gradle$manifest', isNot(contains('com.example')));
      expect(manifest, contains('android:label="Uziy"'));
    });

    test('release signing comes from the git-ignored key.properties', () {
      expect(gradle, contains('rootProject.file("key.properties")'));
      expect(read('android/.gitignore'), contains('key.properties'));
      expect(File('android/key.properties.example').existsSync(), isTrue);
      // A Play bundle without the upload key fails instead of shipping
      // debug-signed.
      expect(gradle, contains('bundleRelease'));
      expect(gradle, contains('throw GradleException'));
    });

    test('asks only for the permissions the app uses', () {
      final permissions = RegExp(r'uses-permission android:name="([^"]+)"')
          .allMatches(manifest)
          .map((m) => m.group(1))
          .toSet();
      expect(permissions, {
        'android.permission.INTERNET',
        'android.permission.POST_NOTIFICATIONS',
      });
    });

    test('has an adaptive (and themed) launcher icon', () {
      final adaptive =
          read('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml');
      expect(adaptive, contains('ic_launcher_foreground'));
      expect(adaptive, contains('<monochrome>'));
    });
  });

  group('iOS', () {
    final project = read('ios/Runner.xcodeproj/project.pbxproj');
    final info = read('ios/Runner/Info.plist');

    /// The Runner target's build settings for [config] (the block that sets
    /// INFOPLIST_FILE, i.e. not the project-level or test-target ones).
    String runnerConfig(String config) {
      final blocks = project.split('isa = XCBuildConfiguration;');
      return blocks.firstWhere((b) =>
          b.contains('INFOPLIST_FILE = Runner/Info.plist;') &&
          b.contains('name = $config;'));
    }

    test('Release and Profile ship as mn.uziy.viewer, Debug as .dev', () {
      expect(runnerConfig('Release'),
          contains('PRODUCT_BUNDLE_IDENTIFIER = mn.uziy.viewer;'));
      expect(runnerConfig('Profile'),
          contains('PRODUCT_BUNDLE_IDENTIFIER = mn.uziy.viewer;'));
      expect(runnerConfig('Debug'),
          contains('PRODUCT_BUNDLE_IDENTIFIER = mn.uziy.viewer.dev;'));
      expect(project, isNot(contains('com.example')));
    });

    test(
        'push: production for Release, development for Profile, none in '
        'Debug', () {
      expect(runnerConfig('Release'),
          contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'));
      expect(
          runnerConfig('Profile'),
          contains(
              'CODE_SIGN_ENTITLEMENTS = Runner/RunnerProfile.entitlements;'));
      expect(
          runnerConfig('Debug'),
          contains(
              'CODE_SIGN_ENTITLEMENTS = Runner/RunnerDebug.entitlements;'));
      expect(read('ios/Runner/Runner.entitlements'),
          contains('<string>production</string>'));
      expect(read('ios/Runner/RunnerProfile.entitlements'),
          contains('<string>development</string>'));
      expect(read('ios/Runner/RunnerDebug.entitlements'),
          isNot(contains('<key>aps-environment</key>')));
    });

    test('release builds carry no ATS exception; Debug adds it at build time',
        () {
      expect(info, isNot(contains('NSAppTransportSecurity')));
      expect(info, isNot(contains('NSAllowsArbitraryLoads')));
      final script = read('ios/scripts/allow_local_networking_in_debug.sh');
      expect(script, contains('[ "\${CONFIGURATION}" = "Debug" ] || exit 0'));
      expect(script, contains('NSAllowsLocalNetworking bool true'));
      expect(project, contains('scripts/allow_local_networking_in_debug.sh'));
    });

    test('declares HTTPS-only encryption and no unused permission prompts', () {
      expect(
          info,
          matches(
              RegExp(r'<key>ITSAppUsesNonExemptEncryption</key>\s*<false/>')));
      expect(info, isNot(contains('UsageDescription')));
      expect(info, contains('<string>Uziy</string>'));
    });

    test('the privacy manifest is in the app bundle and lists what we collect',
        () {
      expect(project, contains('PrivacyInfo.xcprivacy in Resources'));
      final manifest = read('ios/Runner/PrivacyInfo.xcprivacy');
      expect(manifest,
          matches(RegExp(r'<key>NSPrivacyTracking</key>\s*<false/>')));
      for (final type in [
        'PhoneNumber',
        'Name',
        'CoarseLocation',
        'OtherFinancialInfo',
        'OtherUserContent',
        'DeviceID',
        'UserID',
      ]) {
        expect(manifest, contains('NSPrivacyCollectedDataType$type<'),
            reason: type);
      }
    });

    test('iPhone only (the app is laid out for phones)', () {
      expect(project, isNot(contains('TARGETED_DEVICE_FAMILY = "1,2";')));
      expect(project, contains('TARGETED_DEVICE_FAMILY = 1;'));
    });
  });
}
