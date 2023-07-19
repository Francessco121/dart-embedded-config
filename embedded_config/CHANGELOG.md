## v0.5.0
- Added `yaml` dependency and support yaml files
- Make sure newlines are escaped in string literals
- Fix `unnecessary_const` lint in generated files.
- Updated `analyzer` dependency to `>=5.12.0 <7.0.0` (was `>=5.2.0 <6.0.0`).

## v0.4.1
- Updated `analyzer` dependency to `>=5.2.0 <6.0.0` (was `>=2.0.0 <4.0.0`).
- Updated `source_gen` dependency to `^1.2.0` (was `^1.0.0`).

## v0.4.0
- Updated `analyzer` dependency to `>=2.0.0 <4.0.0` (was `^1.0.0`).

## v0.3.0+1
- **No code changes**, added a description for what purpose this package is intended for.

## v0.3.0
- **(breaking change)** Migrated to null-safety.
- **(breaking change)** When `null` is provided for a config key that maps to a config class, that property will be set to `null` now instead of an instance of that class with all `null` properties (Note: This does not happen for non-nullable properties as those are considered 'required' in this release).
- **(breaking change)** The escape character for the environment variable prefix is now `\` instead of a second `$`. This allows for the case where an environment variable's name starts with a `$`, which previously was impossible to embed.
- **(breaking change)** Private getters will now look for a configuration key without the leading `_` present in private Dart identifiers. Use the new `@EmbeddedPropertyName` annotation to map the old way.
- Support the new `@EmbeddedPropertyName` annotation to let a key other than the property name in Dart to be used for that property's configuration key.
- Getter types can now be `dynamic`.
- Changed minimum SDK version to `2.12.0`.
- Package dependency changes (for `embedded_config`):
    - `analyzer`: `>=0.32.4 <0.40.0` -> `^1.0.0`
    - `build`: `^1.0.0` -> `^2.0.0`
    - `code_builder`: `^3.2.0` -> `^4.0.0`
    - `source_gen`: `^0.9.0` -> `1.0.0`

## v0.2.0
- Support for `embedded_config_annotations` v0.2.0.

## v0.1.3
- Non-abstract getters are now ignored when generating the embedded config class.

## v0.1.2
- Fix usage of multiple configuration sources with embedded configs mapped to specific paths not working.

## v0.1.1
- Address a few package scoring issues including public API documentation.

## v0.1.0
- Configuration can now be sourced from JSON files and/or inline build.yaml.
- Build errors now specify the language element which caused the error.
- Added support for numeric configuration values.
- Added support for non-string-only lists.
- Added support for environment variables.
