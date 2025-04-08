import 'package:chat_app/core/remote_config_service.dart';

class AppConfig {
  static final String baseUrl = RemoteConfigService().baseUrl;
  static final String socketUrl = RemoteConfigService().socketUrl;
}
