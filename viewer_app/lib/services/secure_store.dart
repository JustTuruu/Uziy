import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// iOS keychain rules for everything the app keeps (the JWT first of all).
///
/// `first_unlock_this_device`: readable after the first unlock since boot
/// (push and background refresh may need the token while the phone is
/// locked), and — the reason for "this device" — never copied into an
/// iCloud/iTunes backup, so a restored or second phone does not inherit a
/// signed-in session. Not synchronizable, for the same reason.
const IOSOptions kSecureStoreIOSOptions = IOSOptions(
  accessibility: KeychainAccessibility.first_unlock_this_device,
);

/// Android: values are encrypted with a Keystore key (EncryptedSharedPreferences)
/// instead of the plugin's legacy RSA wrapping; existing values are migrated by
/// the plugin on first read.
const AndroidOptions kSecureStoreAndroidOptions = AndroidOptions(
  encryptedSharedPreferences: true,
);

/// The ONE secure-storage handle of the app. Every key (auth token,
/// appearance mode) goes through it so they all share the options above —
/// never build a `FlutterSecureStorage()` with the defaults elsewhere.
const FlutterSecureStorage appSecureStorage = FlutterSecureStorage(
  iOptions: kSecureStoreIOSOptions,
  aOptions: kSecureStoreAndroidOptions,
);
