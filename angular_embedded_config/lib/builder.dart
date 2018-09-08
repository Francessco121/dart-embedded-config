import 'package:build/build.dart';
import 'package:embedded_config/builder.dart' as embedded_config;

// Simply forward the build to embedded_config
Builder configBuilder(BuilderOptions options) => embedded_config.configBuilder(options);