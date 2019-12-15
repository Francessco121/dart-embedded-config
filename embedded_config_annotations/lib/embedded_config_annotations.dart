/// Marks an abstract class to be extended at build-time with overrides
/// for each getter containing config values.
class EmbeddedConfig {
  /// A configuration key defined in build.yaml which specifies
  /// which sources should be used to get config values for the annotated class.
  /// 
  /// For example, to create an embedded config for a JSON document
  /// placed at `lib/app_config.json` in your application, you would
  /// define a key with the file as a source in your `build.*.yaml`:
  /// ```yaml
  /// targets:
  ///   $default:
  ///     builders:
  ///       embedded_config:
  ///         options:
  ///           app_config: 'lib/app_config.json'
  /// 
  /// ```
  /// 
  /// Then, annotate a class with the [key] set to the one defined in
  /// `build.*.yaml` (in this case `app_config`):
  /// ```dart
  /// @EmbeddedConfig('app_config')
  /// abstract class AppConfig { }
  /// ```
  final String key;

  /// A `.` separated list of keys which specify where in the
  /// config source the annotated class should get its values from.
  /// 
  /// Defaults to `null`, which will get values from the root
  /// of the config source.
  /// 
  /// For example, to create an embedded config for the values in
  /// the `sub2` object in the below JSON document:
  /// ```json
  /// {
  ///   "sub": {
  ///     "sub2": {
  ///       "prop": "value"
  ///     }
  ///   }
  /// }
  /// ```
  /// 
  /// You would create the following embedded config:
  /// ```dart
  /// @EmbeddedConfig('<config key>', path: 'sub.sub2')
  /// abstract class Sub2Config {
  ///   String get prop;
  /// }
  /// ```
  /// 
  /// This is necessary to get config values from any nested
  /// config object as an embedded config class can only get
  /// values from the single level in the config hierarchy
  /// which is it set to read from.
  final String path;

  const EmbeddedConfig(this.key, {this.path})
    : assert(key != null);
}
