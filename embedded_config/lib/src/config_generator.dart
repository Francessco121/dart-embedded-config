import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:embedded_config_annotations/embedded_config_annotations.dart';
import 'package:source_gen/source_gen.dart' as source_gen;

import 'build_exception.dart';

const _annotationTypeChecker = source_gen.TypeChecker.fromRuntime(FromEmbeddedConfig);
const _boolTypeChecker = source_gen.TypeChecker.fromRuntime(bool);
const _stringTypeChecker = source_gen.TypeChecker.fromRuntime(String);
const _listTypeChecker = source_gen.TypeChecker.fromRuntime(List);

class ConfigGenerator extends source_gen.Generator {
  final Map<String, dynamic> _config;

  ConfigGenerator(this._config);

  @override
  FutureOr<String> generate(source_gen.LibraryReader library, BuildStep buildStep) async {
    // Build classes
    final List<Class> classes = [];
    final Set<String> generatedClasses = new Set<String>();

    for (final annotatedElement in library.annotatedWith(_annotationTypeChecker)) {
      if (annotatedElement.element is! ClassElement) {
        throw BuildException(
          'Only classes may be annotated with @FromEmbeddedConfig!',
          annotatedElement.element
        );
      }

      for (Class $class in _generateClasses(annotatedElement.element, _config, generatedClasses)) {
        classes.add($class);
      }
    }

    // Check if any classes were generated
    if (classes.isEmpty) {
      // Don't create a file if nothing was generated
      return null;
    }

    // Build library
    final String libraryName = library.element.librarySource.shortName;

    final libraryAst = Library((l) => l
      ..directives.add(Directive((d) => d
        ..type = DirectiveType.import
        ..url = libraryName
      ))
      ..body.addAll(classes)
    );

    // Emit source
    final emitter = new DartEmitter(Allocator.simplePrefixing());
    
    return libraryAst.accept(emitter).toString();
  }

  /// Generates a class for the given [$class] element and any
  /// other classes it references.
  Iterable<Class> _generateClasses(
    ClassElement $class, 
    Map<String, dynamic> currentMap, 
    Set<String> generatedClasses
  ) sync* {
    if (generatedClasses.contains($class.name)) {
      // This class has already been generated
      return;
    }

    generatedClasses.add($class.name);

    final List<Field> fields = [];

    Iterable<PropertyAccessorElement> getters = $class.accessors
      .where((accessor) => accessor.isGetter);

    for (PropertyAccessorElement getter in getters) {
      if (_stringTypeChecker.isExactlyType(getter.returnType)) {
        // String
        final String value = _getString(currentMap, getter.name);

        fields.add(Field((f) => f
          ..annotations.add(refer('override'))
          ..modifier = FieldModifier.final$
          ..type = refer('String')
          ..name = getter.name
          ..assignment = _codeString(value)
        ));
      } else if (_boolTypeChecker.isExactlyType(getter.returnType)) {
        // Boolean
        final bool value = _getBool(currentMap, getter.name);

        fields.add(Field((f) => f
          ..annotations.add(refer('override'))
          ..modifier = FieldModifier.final$
          ..type = refer('bool')
          ..name = getter.name
          ..assignment = _codeBool(value)
        ));
      } else if (_listTypeChecker.isAssignableFromType(getter.returnType)) {
        // List
        if (getter.returnType is ParameterizedType) {
          final ParameterizedType type = getter.returnType;

          if (type.typeArguments.isNotEmpty 
            && _stringTypeChecker.isExactlyType(type.typeArguments.first)) {
            // List of strings
            final List<String> list = _getStringList(currentMap, getter.name);

            fields.add(Field((f) => f
              ..annotations.add(refer('override'))
              ..modifier = FieldModifier.final$
              ..type = refer('List<String>')
              ..name = getter.name
              ..assignment = _codeStringList(list)
            ));
          }
        }
      } else if (getter.returnType.element.library == getter.library) {
        // Class
        final ClassElement innerClass = getter.returnType.element;

        // Add field
        fields.add(Field((f) => f
          ..annotations.add(refer('override'))
          ..modifier = FieldModifier.final$
          ..type = refer(innerClass.name)
          ..name = getter.name
          ..assignment = _codeClass(_generatedClassNameOf(innerClass.name))
        ));

        // Generate inner classes
        yield* _generateClasses(
          innerClass, 
          currentMap == null 
            ? null 
            : currentMap[getter.name].cast<String, dynamic>(),
          generatedClasses
        );
      }
    }

    // Build class
    yield Class((c) => c
      ..name = _generatedClassNameOf($class.name)
      ..extend = refer($class.name)
      ..fields.addAll(fields)
      ..constructors.add(Constructor((t) => t
        ..constant = true
      ))
    );
  }

  bool _getBool(Map<String, dynamic> map, String key) {
    // ignore: avoid_returning_null
    if (map == null) return null;

    final dynamic value = map[key];

    // ignore: avoid_returning_null
    if (value == null) return null;

    if (value is bool) {
      return value;
    } else {
      throw new BuildException("Option '$key' must be a boolean.");
    }
  }

  String _getString(Map<String, dynamic> map, String key) {
    if (map == null) return null;

    final dynamic value = map[key];

    if (value == null) return null;

    if (value is String) {
      return value;
    } else {
      throw new BuildException("Option '$key' must be a string.");
    }
  }

  List<String> _getStringList(Map<String, dynamic> map, String key) {
    if (map == null) return null;

    final dynamic value = map[key];

    if (value == null) return null;

    if (value is List) {
      for (final value in value) {
        if (value is! String) {
          throw new BuildException("Option '$key' must be a list of strings.");
        }
      }

      return value.cast<String>();
    } else {
      throw new BuildException("Option '$key' must be a list.");
    }
  }

  Code _codeBool(bool value) {
    if (value == null) return const Code('null');

    return Code(value ? 'true' : 'false');
  }

  Code _codeString(String value) {
    if (value == null) return const Code('null');

    return Code(_makeStringLiteral(value));
  }

  Code _codeStringList(List<String> value) {
    if (value == null) return const Code('null');

    final buffer = new StringBuffer();
    buffer.write('const [');
    
    for (int i = 0; i < value.length; i++) {
      if (i > 0) {
        buffer.write(',');
      }

      buffer.write(_makeStringLiteral(value[i]));
    }

    buffer.write(']');

    return Code(buffer.toString());
  }

  Code _codeClass(String className) {
    return Code('const $className()');
  }

  String _generatedClassNameOf(String className) {
    return '\$${className}Embedded';
  }

  String _makeStringLiteral(String value) {
    value = value
      .replaceAll('\\', '\\\\')
      .replaceAll("'", "\\'");

    return "'$value'";
  }
}
