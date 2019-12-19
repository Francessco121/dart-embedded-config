This example showcases how to make use of the embedded config annotations to represent a multi-level config file.

Assuming the config file is the following and is located at `lib/app_config.json`:
```json
{
    "apiUrl": "/api",
    "auth": {
        "clientId": "abcd1234",
        "policies": {
          "loginSignUp": "POLICY_LOGIN_SIGN_UP",
          "passwordReset": "POLICY_PASSWORD_RESET"
        }
    }
}
```

The previous file can be represented in code using the following classes:
```dart
// file: lib/app_config.dart

import 'package:embedded_config_annotations/embedded_config_annotations.dart';

part 'app_config.embedded.dart';

// Create a class for the top-level of the config file.
//
// The string given to the annotation is a key which allows the
// application's build.yaml file to map various config sources
// to this class. In this case, we choose `app_config` as the key.
@EmbeddedConfig('app_config')
abstract class AppConfig {
  // An example of one way to expose the generated class which
  // contains the embedded config values.
  static const AppConfig instance = _$AppConfigEmbedded();

  String get apiUrl;

  // Here we can reference another embedded config class as
  // a getter to provide a nicer interface for code utilizing
  // this top-level class.
  //
  // The name of this getter does not matter, as the source
  // of the config values given to the AppAuthConfig class
  // is determined by its annotation.
  AppAuthConfig get auth;

  // Embedded config classes must declare a default
  // const constructor.
  const AppConfig();
}

// Create a class for the 'auth'-level of the config file.
//
// By utilizing the path property, the class can specify where
// in the config source that values should be read from. The path
// is a `.` separated list of config keys.
//
// The key for the build.yaml to use is also kept the same since
// this class is for the same sources as the AppConfig class.
@EmbeddedConfig('app_config', path: 'auth')
abstract class AppAuthConfig {
  String get clientId;
  AppPoliciesConfig get policies;

  const AppAuthConfig();
}

// Create a class for the 'policies'-level of the config file.
//
// Here we can see how that `.` separated syntax works. The
// policy configuration is inside of the `auth` object in the
// config, so we specify a path into it first.
@EmbeddedConfig('app_config', path: 'auth.policies')
abstract class AppPoliciesConfig {
  String get loginSignUp;
  String get passwordReset;

  const AppPoliciesConfig();
}
```

After this, the `app_config` key which each of the classes used can be mapped to the JSON configuration document inside of build.yaml:

```yaml
targets:
  $default:
    builders:
      embedded_config:
        options:
          app_config: 'lib/app_config.json'
```
