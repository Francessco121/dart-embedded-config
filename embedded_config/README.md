# embedded_config

A package which allows application configurations to be embedded directly into source code at build-time.
Configuration can come from JSON files, environment variables, and build.yaml files.

## Contents
- [Usage](#usage)
  - [1. Installing](#1-installing)
  - [2. Create an embedded config class](#2-create-an-embedded-config-class)
  - [3. Map configuration source(s)](#3-map-configuration-sources)
- [Merging configuration](#merging-configuration)
- [Inline configuration sources](#inline-configuration-sources)
- [Complex configuration models](#complex-configuration-models)
- [Environment variables](#environment-variables)
  - [Escaping environment variables](#escaping-environment-variables)
  - [Example: Embedding a build identifier from CI](#example-embedding-a-build-identifier-from-ci)

## Usage

### 1. Installing

This package makes use of [package:build_runner](https://pub.dev/packages/build_runner). To avoid making build_runner a normal dependency, embedded_config has a partner package [embedded_config_annotations](https://pub.dev/packages/embedded_config_annotations). 

The embedded_config_annotations package should be added as a normal dependency and embedded_config should be added as a dev dependency:

```yaml
dependencies:
  embedded_config_annotations: ^0.1.0

dev_dependencies:
  embedded_config: ^0.1.0
```

The build_runner package should also be added as a dev dependency to your application.

### 2. Create an embedded config class

Configuration is embedded into your application by generating a class that extends an abstract "embedded config" class in your application. The generated extending class contains hard-coded configuration values, which come from configuration sources (we'll get to that next).

Create an abstract class annotated with `@EmbeddedConfig`. This class must also have a default `const` constructor. The `@EmbeddedConfig` annotation is given a configuration source key which we'll connect later. In this class, you may define abstract getters which map to keys from configuration sources.

```dart
// file: app_config.dart

import 'package:embedded_config_annotations/embedded_config_annotations.dart';

// Add the generated file as a part
part 'app_config.embedded.dart';

@EmbeddedConfig('app_config')
abstract class AppConfig {
  String get apiUrl;

  const AppConfig();
}
```

Getter return types can be any of the following:
- `String`
- `int`
- `double`
- `num`
- `bool`
- `List` (or `List<T>`)
- `Map` (or `Map<K, V>`)
- [Other annotated embedded config classes in the same library](#complex-configuration-models)

> **Note:** When the element type of a list is explicitly `String` or the value type of a map is explicitly `String`, values from config sources will automatically be converted to strings.
>
> Example: A getter of `List<String>` given the config value of `[24]` will get an embedded value of `["24"]`.

### 3. Map configuration source(s)

Next, we need the actual configuration. Configuration can be specified in two places: JSON files in your application package and build.yaml files. Both of these sources can additionally make use of environment variables.

Configuration sources are mapped to annotated classes inside of your application's build.yaml files. This allows you to swap out configuration values for different builds.

In any of the application package's build.*.yaml files, configure the `embedded_config` builder to map configuration sources:

```yaml
targets:
  $default:
    builders:
      embedded_config:
        options:
          # Maps the configuration source key 'app_config' to the
          # JSON file at 'lib/app_config.json'
          #
          # The key 'app_config' is the same key given to the
          # @EmbeddedConfig annotation on the embedded config class
          app_config: 'lib/app_config.json'

          # This can also be written like so, both mean the same thing
          # app_config:
          #  source: 'lib/app_config.json'
```

To complete the example, given the `AppConfig` class defined earlier, the `app_config.json` file could contain:

```json
{
  "apiUrl": "/api"
}
```

When the application package is then built using the build.yaml file configuring `embedded_config`, a file is generated containing the hard-coded configuration values extending the `app_config.dart` file defined earlier. These generated files are always in the same directory as the annotated class's file and is named `<original file name>.embedded.dart` (in this case it would be named `app_config.embedded.dart`).

The contents of the generated file in this case would look like:
```dart
part of 'app_config.dart';

class _$AppConfigEmbedded extends AppConfig {
  const _$AppConfigEmbedded();

  @override
  final apiUrl = '/api';
}
```

The annotated `AppConfig` class can then expose the generated class in any way you choose. Since embedded configs are marked with `const` constructors, one nice way is to expose it as a `static const` singleton value:

```dart
// ...

@EmbeddedConfig('app_config')
abstract class AppConfig {
  static const AppConfig instance = _$AppConfigEmbedded();

  // ...
}
```

## Merging configuration

Multiple configuration sources can be mapped to a single annotated class. This could allow you to define a "base" `app_config.json` and then environment specific `app_config.dev.json` and `app_config.prod.json` files. A `build.dev.yaml` file could map the `dev` json onto the base file, and `build.prod.yaml` with `prod`.

For example, lets define two files `app_config.json` and `app_config.dev.json`:

```json
// app_config.json
{
  "prop1": "value1",
  "sub": {
    "prop2": true
  }
}

// app_config.dev.json
{
  "prop1": "value2",
  "sub": {
    "prop3": "value3"
  }
}
```

Then, in `build.dev.yaml` specify both as a source with `dev` being last so that it overrides the base file:

```yaml
targets:
  $default:
    builders:
      embedded_config:
        options:
          app_config:
            # Order matters, later sources override earlier sources!
            source:
              - 'lib/app_config.json'
              - 'lib/app_config.dev.json'
```

When merging configurations, **values are overridden at the lowest level possible!** This means that building with `build.dev.yaml` in this example would use the equivalent of this merged JSON document:

```json
{
  "prop1": "value2",
  "sub": {
    "prop2": true,
    "prop3": "value3"
  }
}
```

Keys cannot be removed when merging configurations. Properties can of course still be set to `null` (in this example the `sub` object could be "removed" by setting it to `null`, but `prop2` inside of `sub` cannot be removed otherwise).

## Inline configuration sources

Configuration can also be specified directly in build.yaml files. This is done through the `inline` property:

```yaml
targets:
  $default:
    builders:
      embedded_config:
        options:
          app_config:
            inline:
              apiUrl: '/api2'
```

Inline configuration can also be combined with file sources, however inline will always be applied last and override all file sources. See [Merging configuration](#merging-configuration) to understand how inline sources would override file sources, it works the same as a file overriding another file.

## Complex configuration models

When configuration is not a flat set of key/value pairs, multiple annotated embedded config classes can be used. This works by setting the `path` property of the `@EmbeddedConfig` annotation. The path is a `.` separated list of configuration keys.

For example, to embed the following configuration:
```json
{
  "prop1": "value1",
  "sub": {
    "prop2": "value2",
    "sub2": {
      "prop3": "value3"
    }
  }
}
```

You would need to create three annotated classes:
```dart
import 'package:embedded_config_annotations/embedded_config_annotations.dart';

// Embeds the top-level of the configuration
@EmbeddedConfig('app_config')
abstract class AppConfig {
  String get prop1;
  // Other embedded config classes in the same Dart library 
  // can be referenced as a getter type
  AppSubConfig get sub;

  const AppConfig();
}

// Embeds the top-level contents of the "sub" object
@EmbeddedConfig('app_config', path: 'sub')
abstract class AppSubConfig {
  String get prop2;
  AppSub2Config get sub2;

  const AppSubConfig();
}

// Embeds the top-level contents of the "sub2" object inside
// of the "sub" object
@EmbeddedConfig('app_config', path: 'sub.sub2')
abstract class AppSub2Config {
  String get prop3;

  const AppSub2Config();
}
```

The `path` property can also be used outside of this use-case and does not require a 'parent' class to also be defined.

> **Note:** Any annotated classes which reference each other must be declared in the same Dart library.

## Environment variables

Environment variables can be substituted for any **string value** in the configuration. This is done by starting a value with `$`. For example, `$BUILD_ID` would be substituted with the value of the environment variable `BUILD_ID`.

### Escaping environment variables
If a configuration value literally starts with `$` and is not intended to be substituted for an environment variable, you can escape it with another `$`. For example, to embed the literal value `$BUILD_ID` your configuration would need the value `$$BUILD_ID`. This also means that embedding the literal value `$$BUILD_ID` requires the configuration value `$$$BUILD_ID` and so forth as any value starting with `$$` has those two first characters replaced with a single `$`.

### Example: Embedding a build identifier from CI
The following is an example of how you could embed a build identifier from CI exposed as an environment variable into your application:

```dart
import 'package:embedded_config_annotations/embedded_config_annotations.dart';

@EmbeddedConfig('environment')
abstract class Environment {
  String get buildId;

  const Environment();
}
```

You could specify the environment variable in a JSON source:

```json
{
  "buildId": "$BUILD_ID"
}
```

Or, more simply in this case, specify it inline in build.yaml:

```yaml
targets:
  $default:
    builders:
      embedded_config:
        options:
          environment:
            inline:
              buildId: '$BUILD_ID'
```
