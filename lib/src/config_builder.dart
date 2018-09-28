import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../embedded_config.dart'
  show FromEmbeddedConfig;
import 'ast.dart' as ast;
import 'buffer_generator.dart';
import 'parser.dart';

Builder createConfigBuilder(BuilderOptions options) {
  return new LibraryBuilder(
    _ConfigGenerator(options.config),
    generatedExtension: '.g.dart'
  );
}

class _ConfigGenerator extends GeneratorForAnnotation<FromEmbeddedConfig> {
  final Map _config;

  _ConfigGenerator(this._config);

  @override
  Future<String> generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) async {
    // Setup string buffer with initial import
    final String libraryName = element.librarySource.shortName;

    final StringBuffer buffer = StringBuffer()
      ..writeln("import '$libraryName';");

    // Parse classes
    final ast.ClassNode rootClass = parse(element as ClassElement);

    // Generate code for each class
    final visitor = BufferGenerator();
    Iterable<StringBuffer> classBuffers = visitor.generateBuffers(rootClass, _config);

    // Write each class to the output file
    buffer.writeAll(classBuffers);

    return buffer.toString();
  }
}
