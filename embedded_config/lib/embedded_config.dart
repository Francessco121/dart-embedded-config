import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/config_generator.dart';

Builder configBuilder(BuilderOptions options) {
  return PartBuilder(
    [ConfigGenerator(options.config)], 
    '.embedded.dart'
  );
}