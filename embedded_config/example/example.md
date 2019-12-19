This example showcases how to embed a multi-level JSON config into an application, additionally including the use of environment variables.

Assuming the config file is the following and is located at `lib/app_config.json`:
```json
{
    "apiUrl": "/api",
    "auth": {
        "clientId": "$AUTH_CLIENT_ID"
    }
}
```

The previous file can be represented in code using the following class:
```dart
// file: lib/app_config.dart

import 'package:embedded_config_annotations/embedded_config_annotations.dart';

part 'app_config.embedded.dart';

// Mark an *abstract* class with @EmbeddedConfig and
// assign a key to allow this class to be mapped to
// config sources.
@EmbeddedConfig('app_config')
abstract class AppConfig {
  // An example of one way to expose the generated class which
  // contains the embedded config values.
  static const AppConfig instance = _$AppConfigEmbedded();

  // Value will be set to '/api'.
  String get apiUrl;

  // Value will be set to an instance of the generated
  // embedded config class of AppAuthConfig.
  AppAuthConfig get auth;

  // Embedded config classes must declare a default
  // const constructor.
  const AppConfig();
}

// Since this class represents a sub-object in the config,
// specify a '.' separated 'path' to the object from the
// root of the config.
@EmbeddedConfig('app_config', path: 'auth')
abstract class AppAuthConfig {
  // Value will be set to the value of the environment 
  // variable 'AUTH_CLIENT_ID' as stated in the app_config.json
  // file at the time of build.
  String get clientId;

  const AppAuthConfig();
}
```

After this, the class must be mapped to at least one config source by the key defined on the class inside of any build.yaml file in the project. Use different build.yaml files (e.g. build.prod.yaml vs build.dev.yaml) to change the source of config values embedded into the application at build time. This allows you to configure your application for different environments.

```yaml
targets:
  $default:
    builders:
      embedded_config:
        # Optional, but may provide a build performance boost as
        # the builder does analyze all Dart files by default
        # generate_for:
        #   - 'lib/app_config.dart'
        options:
          app_config: 'lib/app_config.json'
          # This may also be specified with the 'source' property
          # app_config:
          #   source: 'lib/app_config.json'
          # And, additionally as a single element of a source list
          # app_config:
          #   source:
          #     - 'lib/app_config.json'
```
