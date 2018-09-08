# dart-embedded-config

A super experimental Dart package for embedding configs into source code at build time.

> **Note:** Requires Dart 2.x, as this package takes advantage of the new build system.

## Usage

### Steps
1. [Add the package to your pubspec](#add-the-package-to-your-pubspec)
    - [Non-Angular Applications](#non-angular-applications)
    - [Angular Applications](#angular-applications)
2. [Specify your config layout in code](#specify-your-config-layout-in-code)
3. [Specify your build-time config](#specify-your-build-time-config)
4. [Use the embedded config](#use-the-embedded-config)
    - [Injecting into Angular applications](#injecting-into-angular-applications)

### Add the package to your pubspec

> **Note:** Currently this is not a hosted package, but can be added as a local path dependency.

#### Non-Angular Applications

Add the embedded_config package to your pubspec:
```yaml
dependencies:
  embedded_config:
    path: /path/to/dart-embedded-config/embedded_config
```

#### Angular Applications

> **Note:** This is only necessary if you plan on injecting the embedded config into your Angular application.
> The angular_embedded_config package includes extra build configuration to specify that it must run before Angular.

Add the angular_embedded_config package to your pubspec:
```yaml
dependencies:
  embedded_config:
    path: /path/to/dart-embedded-config/angular_embedded_config
```

### Specify your config layout in code

Example, using a file named **web_config.dart**:
```dart
import 'package:embedded_config/embedded_config.dart';
// If using the angular_embedded_config package:
// import 'package:angular_embedded_config/angular_embedded_config.dart';

@fromEmbeddedConfig
abstract class WebConfig {
  String get apiBaseUrl;

  // Supports nested classes!
  NestedConfig get nested;

  const WebConfig();
}

abstract class NestedConfig {
  String get clientId;

  const NestedConfig();
}
```

### Specify your build-time config
In your application's `build.yaml` file, you can add values for the previously defined config:
```yaml
targets:
  $default:
    builders:
      embedded_config:
      # If using Angular, replace previous line with:
      # angular_embedded_config:
        options:
          apiBaseUrl: '/api'
          nested:
            clientId: '------------'
```

### Use the embedded config

At build-time, an implementation of every class annotated with `@fromEmbeddedConfig` will be generated with values hard-coded from your `build.yaml`.

Generated files are in the same directory as the file they were generated from following the name `<file-name>.g.dart`. For example, an embedded config implementation generated from the file `web_config.dart` would be named `web_config.g.dart`. This file can be imported like any other source file.

The generated file contains a class for each annotated class following the name `$<class-name>Embedded`. For example:
```dart
// Assumes that 'web_config.dart' is in the same directory as the current file.
import 'web_config.g.dart' as embedded_config;

...

var config = new embedded_config.$WebConfigEmbedded();
var clientId = config.apiBaseUrl; // Would equal '/api' from the previous example
```

The generated class can be used as a singleton.

#### Injecting into Angular applications

Assuming the config file is named `web_config.dart` and is at the root of the applications `lib` folder, the generated config could be injected into the root of the Angular application (in `main.dart`) by doing for example:
```dart
import 'package:app_name/web_config.dart';
import 'package:app_name/web_config.g.dart';

@GenerateInjector([
  ClassProvider(WebConfig, useClass: embedded_config.$WebConfigEmbedded)
])
...
```

Now `WebConfig` can be injected anywhere in the Angular application with the values populated from `build.yaml`.