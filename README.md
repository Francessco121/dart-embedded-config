# dart-embedded-config

A super experimental Dart package for embedding configs into source code at build time.

> **Note:** Requires Dart 2.x, as this package takes advantage of the new build system.

## Contents
- [Usage](#usage)
- [Injecting into Angular applications](#injecting-into-angular-applications)
- [Usage with Flutter](#usage-with-flutter)

## Usage

### Steps
1. [Add the package to your pubspec](#1-add-the-package-to-your-pubspec).
2. [Specify your config layout in code](#2-specify-your-config-layout-in-code).
3. [Specify your build-time config](#3-specify-your-build-time-config).
4. [Use the embedded config](#4-use-the-embedded-config).

### 1. Add the package to your pubspec

> **Note:** Currently this package is not hosted on pub.

Add the embedded_config package to your pubspec:
```yaml
dependencies:
  embedded_config:
    git: https://github.com/Francessco121/dart-embedded-config.git
    ref: <insert latest commit ID> # Optional but recommended
```

### 2. Specify your config layout in code

Example, using a file named **web_config.dart**:
```dart
import 'package:embedded_config/embedded_config.dart';

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

### 3. Specify your build-time config
In your application's `build.yaml` file, you can add values for the previously defined config:
```yaml
targets:
  $default:
    builders:
      embedded_config:
        options:
          apiBaseUrl: '/api'
          nested:
            clientId: '------------'
```

### 4. Use the embedded config

At build-time, an implementation of every class annotated with `@fromEmbeddedConfig` will be generated with values hard-coded from your `build.yaml` (or whichever build yaml the package was built with).

Generated files are in the same directory as the file they were generated from and follow the naming pattern `<file-name>.embedded.dart`. For example, an embedded config implementation generated from the file `web_config.dart` would be named `web_config.embedded.dart`. This file can be imported like any other source file.

The generated file contains a class for each annotated class following the naming pattern `$<class-name>Embedded`. For example:
```dart
// Assumes that 'web_config.dart' is in the same directory as the current file.
import 'web_config.embedded.dart' as embedded_config;

...

var config = const embedded_config.$WebConfigEmbedded();
var clientId = config.apiBaseUrl; // Would equal '/api' from the previous example
```

## Injecting into Angular applications

Assuming the config file is named `web_config.dart` and is at the root of the applications `lib` folder, the generated config could be injected into the root of the Angular application (in `main.dart`) by doing for example:
```dart
import 'package:app_name/web_config.dart';
import 'package:app_name/web_config.embedded.dart';

@GenerateInjector([
  // Note: A factory provider is used because the generated config file is not
  // guaranteed to be created before Angular's builder runs. You could get
  // around this by using a reflective injector instead.
  FactoryProvider(WebConfig, configFactory)
])
...

WebConfig configFactory() {
  return const embedded_config.$WebConfigEmbedded();
}
```

Now `WebConfig` can be injected anywhere in the Angular application with the values populated from `build.yaml`!

## Usage with Flutter

Flutter currently has limited support for `build_runner`. By default, the `embedded_config` builder builds the generated files to the Dart cache (`.dart_tool`). Flutter builds are unable to reference files in this folder. To get around this, use the `embedded_config_to_source` builder. This will cause the generated files to be placed with the source code instead of `.dart_tool`.

This can be achieved by enabling `embedded_config_to_source` in `build.yaml` and disabling `embedded_config`:

```yaml
targets:
  $default:
    builders:
      embedded_config:
        enabled: false
      embedded_config|embedded_config_to_source:
        enabled: true
        options:
          # Options go here instead
```
