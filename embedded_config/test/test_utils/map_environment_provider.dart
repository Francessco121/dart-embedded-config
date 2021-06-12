import 'package:embedded_config/src/environment_provider.dart';

class MapEnvironmentProvider implements EnvironmentProvider {
  @override
  final Map<String, String> environment;

  MapEnvironmentProvider(this.environment);
}
