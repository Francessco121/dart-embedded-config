## v0.3.0+1
- **No code changes**, added a description for what purpose this package is intended for.

## v0.3.0
- **(breaking change)** Migrated to null-safety.
- Add the `@EmbeddedPropertyName` annotation to let a key other than the property name in Dart to be used for that property's configuration key.
- Changed minimum SDK version to `2.12.0`.

## v0.2.0
- **(breaking change)** `EmbeddedConfig.path` is now a `List<String>`. This addresses incompatibilities with keys containing `.` characters.

## v0.1.1
- Add an example to address package scoring.

## v0.1.0
- Replace `@FromEmbeddedConfig` annotation with `@EmbeddedConfig`.
