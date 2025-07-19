import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  // Default values in case remote config fails
  static const String _defaultBaseUrl = 'https://chat-app-node-js-production.up.railway.app';
  static const String _defaultSocketUrl = 'https://chat-app-node-js-production.up.railway.app';

  String get baseUrl =>
      _remoteConfig.getString('base_url').isEmpty
          ? _defaultBaseUrl
          : _remoteConfig.getString('base_url');

  String get socketUrl =>
      _remoteConfig.getString('socket_url').isEmpty
          ? _defaultSocketUrl
          : _remoteConfig.getString('socket_url');

  Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 12),
        ),
      );

      // Set default values
      await _remoteConfig.setDefaults({
        'base_url': _defaultBaseUrl,
        'socket_url': _defaultSocketUrl,
      });

      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      print('Error initializing Remote Config: $e');
      // Continue with default values
    }
  }
}
