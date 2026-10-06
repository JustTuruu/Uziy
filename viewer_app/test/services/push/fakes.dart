import 'dart:async';

import 'package:viewer_app/models/campaign.dart';
import 'package:viewer_app/services/push/device_registry.dart';
import 'package:viewer_app/services/push/foreground_notifier.dart';
import 'package:viewer_app/services/push/push_client.dart';
import 'package:viewer_app/services/push/push_message.dart';
import 'package:viewer_app/services/push/push_navigator.dart';

class FakePushClient implements PushClient {
  FakePushClient({
    this.available = true,
    this.permission = PushPermission.granted,
    this.token = 'tok-1',
    this.initial,
  });

  bool available;
  PushPermission permission;
  String? token;
  PushMessage? initial;
  int permissionCalls = 0;

  final refresh = StreamController<String>.broadcast();
  final messages = StreamController<PushMessage>.broadcast();
  final opened = StreamController<PushMessage>.broadcast();

  @override
  bool get isAvailable => available;
  @override
  Future<PushPermission> requestPermission() async {
    permissionCalls++;
    return permission;
  }

  @override
  Future<String?> getToken() async => token;
  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  Stream<PushMessage> get onMessage => messages.stream;
  @override
  Stream<PushMessage> get onMessageOpenedApp => opened.stream;
  @override
  Future<PushMessage?> getInitialMessage() async => initial;
}

class FakeRegistry implements DeviceRegistry {
  final registered = <(String, PushPlatform)>[];
  final unregistered = <String>[];
  bool failRegister = false;
  bool failUnregister = false;

  @override
  Future<void> register(String token, PushPlatform platform) async {
    if (failRegister) throw Exception('boom');
    registered.add((token, platform));
  }

  @override
  Future<void> unregister(String token) async {
    if (failUnregister) throw Exception('boom');
    unregistered.add(token);
  }
}

class FakeNotifier implements ForegroundNotifier {
  final shown = <PushMessage>[];
  final tapController = StreamController<Map<String, String>>.broadcast();

  @override
  Future<void> init() async {}
  @override
  Future<void> show(PushMessage message) async => shown.add(message);
  @override
  Stream<Map<String, String>> get taps => tapController.stream;
}

class FakeTarget implements PushNavigationTarget {
  final pushed = <(String, Object?)>[];
  int homes = 0;
  final messages = <String>[];

  @override
  void push(String location, {Object? extra}) => pushed.add((location, extra));
  @override
  void goHome() => homes++;
  @override
  void showMessage(String text) => messages.add(text);
}

Campaign campaign(int id, {bool hasVideo = true}) => Campaign(
      id: id,
      companyName: 'Co',
      videoUrl: '',
      title: 'T$id',
      durationSeconds: 30,
      rewardPerUser: 500,
      hasVideo: hasVideo,
    );
