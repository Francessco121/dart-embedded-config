import 'package:build/build.dart';
import 'package:embedded_config_annotations/embedded_config_annotations.dart';
import 'package:source_gen/source_gen.dart';

import 'src/config_generator.dart';

/// Creates an embedded config part-file builder.
///
/// The builder [options] use user-defined key-to-source mappings
/// to determine where the builder gets its values.
///
/// For any file with a class using the [EmbeddedConfig] annotation,
/// a part file will be emitted with the extension `.embedded.dart`
/// in the same directory.
Builder configBuilder(BuilderOptions options) {
  return PartBuilder([ConfigGenerator(options.config)], '.embedded.dart');
}
