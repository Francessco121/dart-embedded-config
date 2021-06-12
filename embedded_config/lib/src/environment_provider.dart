import 'dart:io';

/// An implementation of [EnvironmentProvider] using
/// `dart:io` [Platform.environment].
class PlatformEnvironmentProvider implements EnvironmentProvider {
  @override
  Map<String, String> get environment => Platform.environment;

  const PlatformEnvironmentProvider();
}

/// Provides environment variables for the configuration generator.
abstract class EnvironmentProvider {
  /// A map of environment variables.
  Map<String, String> get environment;
}
