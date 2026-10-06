import '../viewer_service.dart';
import 'push_message.dart';

/// Where device tokens are stored (the backend). Abstracted for tests.
abstract class DeviceRegistry {
  Future<void> register(String token, PushPlatform platform);
  Future<void> unregister(String token);
}

/// [DeviceRegistry] over the existing [ViewerService] HTTP client.
class ViewerDeviceRegistry implements DeviceRegistry {
  ViewerDeviceRegistry([ViewerService? service])
      : _service = service ?? ViewerService.instance;

  final ViewerService _service;

  @override
  Future<void> register(String token, PushPlatform platform) =>
      _service.registerDevice(token: token, platform: platform.wire);

  @override
  Future<void> unregister(String token) =>
      _service.unregisterDevice(token: token);
}
