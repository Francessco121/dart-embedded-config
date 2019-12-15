import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:embedded_config_annotations/embedded_config_annotations.dart';
import 'package:source_gen/source_gen.dart' as source_gen;

import 'build_exception.dart';
import 'key_config.dart';

const _classAnnotationTypeChecker = source_gen.TypeChecker.fromRuntime(EmbeddedConfig);
const _stringTypeChecker = source_gen.TypeChecker.fromRuntime(String);
const _listTypeChecker = source_gen.TypeChecker.fromRuntime(List);

class _AnnotatedClass {
  final ClassElement element;
  final EmbeddedConfig annotation;

  _AnnotatedClass(this.element, this.annotation);
}

class ConfigGenerator extends source_gen.Generator {
  final Map<String, KeyConfig> _keys;

  ConfigGenerator(Map<String, dynamic> config)
    // Parse key configs
    : _keys = config.map((k, v) => MapEntry(k, KeyConfig.fromBuildConfig(v)));

  @override
  FutureOr<String> generate(source_gen.LibraryReader library, BuildStep buildStep) async {
    // Get annotated classes
    final List<_AnnotatedClass> sourceClasses = [];
    
    for (final annotatedElement in library.annotatedWith(_classAnnotationTypeChecker)) {
      final classElement = annotatedElement.element;

      if (classElement is! ClassElement || !(classElement as ClassElement).isAbstract) {
        throw BuildException(
          'Only abstract classes may be annotated with @EmbeddedConfig!',
          classElement
        );
      }

      sourceClasses.add(_AnnotatedClass(
        classElement,
        _reconstructClassAnnotation(annotatedElement.annotation)
      ));
    }

    // Build classes
    final List<Class> classes = [];
    final Set<String> generatedClasses = new Set<String>();

    for (final _AnnotatedClass annotatedClass in sourceClasses) {
      // Resolve real config values
      if (annotatedClass.annotation.key == null) {
        throw BuildException('Embedded config key cannot be null.', annotatedClass.element);
      }

      final Map<String, dynamic> config = 
        await _resolveConfig(buildStep, annotatedClass.element, annotatedClass.annotation);

      if (config == null) {
        throw BuildException('Could not resolve config source.', annotatedClass.element);
      }

      // Generate class
      final Class $class = _generateClass(annotatedClass.element, config, sourceClasses, generatedClasses);
      
      if ($class != null) {
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

  /// Reconstructs an [EmbeddedConfig] annotation from a [source_gen.ConstantReader] of one.
  EmbeddedConfig _reconstructClassAnnotation(source_gen.ConstantReader reader) {
    String key;
    String path;

    final keyReader = reader.read('key');
    if (!keyReader.isNull) {
      key = keyReader.stringValue;
    }

    final pathReader = reader.read('path');
    if (!pathReader.isNull) {
      path = pathReader.stringValue;
    }

    return EmbeddedConfig(key, path: path);
  }

  /// Resolves the config values for the given embedded config [annotation].
  Future<Map<String, dynamic>> _resolveConfig(
    BuildStep buildStep, 
    ClassElement classElement, 
    EmbeddedConfig annotation
  ) async {
    // Get the key config
    final KeyConfig keyConfig = _keys[annotation.key];

    if (keyConfig == null) {
      throw BuildException('No embedded config defined for key: ${annotation.key}', classElement);
    }

    final Map<String, dynamic> config = {};

    // Apply file sources
    if (keyConfig.sources != null) {
      for (final String filePath in keyConfig.sources) {
        // Read file
        final assetId = AssetId(buildStep.inputId.package, filePath);
        final String assetContents = await buildStep.readAsString(assetId);

        Map<String, dynamic> _fileConfig;

        if (filePath.trimRight().endsWith('.json')) {
          _fileConfig = json.decode(assetContents);
        } else {
          throw BuildException('Embedded config file sources must be JSON documents.', classElement);
        }

        // Follow path if specified
        if (annotation.path != null) {
          for (final String key in annotation.path.split('.')) {
            if (_fileConfig.containsKey(key)) {
              _fileConfig = _fileConfig[key];
            } else {
              throw BuildException("Could not follow path '${annotation.path}' for file at $assetId.", classElement);
            }
          }
        }

        // Merge file into config
        _mergeMaps(config, _fileConfig);
      }
    }

    // Apply inline source
    if (keyConfig.inline != null) {
      _mergeMaps(config, keyConfig.inline);
    }

    return config;
  }

  /// Merges the [top] map on top of the [base] map, overwriting values at the lowest level possible.
  void _mergeMaps(Map base, Map top) {
    top.forEach((k, v) {
      final baseValue = base[k];

      if (baseValue != null && baseValue is Map && v is Map) {
        _mergeMaps(baseValue, v);
      } else {
        base[k] = v;
      }
    });
  }

  /// Generates a class for the given [$class] element using the given [config].
  Class _generateClass(
    ClassElement $class, 
    Map<String, dynamic> config,
    List<_AnnotatedClass> sourceClasses,
    Set<String> generatedClasses
  ) {
    if (generatedClasses.contains($class.name)) {
      // This class has already been generated
      return null;
    }

    generatedClasses.add($class.name);

    final List<Field> fields = [];

    Iterable<PropertyAccessorElement> getters = $class.accessors
      .where((accessor) => accessor.isGetter);

    for (PropertyAccessorElement getter in getters) {
      try {
        if (_stringTypeChecker.isExactlyType(getter.returnType)) {
          // String
          final String value = _getString(config, getter.name);

          fields.add(Field((f) => f
            ..annotations.add(refer('override'))
            ..modifier = FieldModifier.final$
            ..name = getter.name
            ..assignment = _codeLiteral(value)
          ));
        } else if (_listTypeChecker.isAssignableFromType(getter.returnType)) {
          // List
          if (getter.returnType is ParameterizedType) {
            final ParameterizedType type = getter.returnType;

            final String value = _getList(config, getter.name, 
              // Force all values to strings if this is a List<String>
              forceStrings: type.typeArguments.isNotEmpty 
                && _stringTypeChecker.isExactlyType(type.typeArguments.first)
            );

            fields.add(Field((f) => f
              ..annotations.add(refer('override'))
              ..modifier = FieldModifier.final$
              ..name = getter.name
              ..assignment = _codeLiteral(value)
            ));
          }
        } else if (getter.returnType.element.library == getter.library) {
          // Class
          final ClassElement innerClass = getter.returnType.element;

          if (!sourceClasses.any((c) => c.element == innerClass)) {
            throw BuildException('Cannot reference a non embedded config class as a config property.');
          }

          // Add field
          fields.add(Field((f) => f
            ..annotations.add(refer('override'))
            ..modifier = FieldModifier.final$
            ..name = getter.name
            ..assignment = _codeClassInstantiation(_generatedClassNameOf(innerClass.name))
          ));
        } else {
          // Any
          final String value = _getLiteral(config, getter.name);

          fields.add(Field((f) => f
            ..annotations.add(refer('override'))
            ..modifier = FieldModifier.final$
            ..name = getter.name
            ..assignment = _codeLiteral(value)
          ));
        }
      } on BuildException catch (ex) {
        if (ex.element == null) {
          // Attach getter element to exception
          throw BuildException(ex.message, getter);
        } else {
          rethrow;
        }
      }
    }

    // Ensure class declares a constant default constructor
    if ($class.unnamedConstructor == null || !$class.unnamedConstructor.isConst) {
      throw BuildException('Embedded config classes must declare a const default constructor.', $class);
    }

    // Build class
    return Class((c) => c
      ..name = _generatedClassNameOf($class.name)
      ..extend = refer($class.name)
      ..fields.addAll(fields)
      ..constructors.add(Constructor((t) => t
        ..constant = true
      ))
    );
  }

  /// If the given [string] starts with `$`, then the value of
  /// the environment variable with the name specified by the remaining
  /// characters in [string] after the `$` will be returned.
  /// 
  /// If [string] starts with `\$` then the `$` will be treated as
  /// an escaped character and the `\` will be removed.
  String _checkEnvironmentVariable(String string) {
    if (string.startsWith(r'$')) {
      return Platform.environment[string.substring(1)];
    } else if (string.startsWith(r'\$')) {
      return string.substring(1);
    } else {
      return string;
    }
  }

  String _getLiteral(Map<String, dynamic> map, String key) {
    final dynamic value = map[key];

    if (value == null) return null;

    return _makeLiteral(value);
  }

  String _getString(Map<String, dynamic> map, String key) {
    final dynamic value = map[key];

    if (value == null) return null;

    if (value is String) {
      return _makeStringLiteral(_checkEnvironmentVariable(value));
    } else {
      return _makeStringLiteral(value.toString());
    }
  }

  String _getList(Map<String, dynamic> map, String key, {bool forceStrings}) {
    if (map == null) return null;

    final dynamic value = map[key];

    if (value == null) return null;

    if (value is List) {
      return _makeListLiteral(value, forceStrings: forceStrings);
    } else {
      throw new BuildException("Config value '$key' must be a list.");
    }
  }

  String _makeLiteral(dynamic value) {
    if (value is String) {
      return _checkEnvironmentVariable(_makeStringLiteral(value));
    } else if (value is bool) {
      return _makeBoolLiteral(value);
    } else if (value is List) {
      return _makeListLiteral(value);
    } else {
      return value.toString();
    }
  }

  String _makeBoolLiteral(bool value) {
    return value ? 'true': 'false';
  }

  String _makeStringLiteral(String value) {
    value = value
      .replaceAll('\\', '\\\\')
      .replaceAll("'", "\\'")
      .replaceAll(r'$', '\\\$');

    return "'$value'";
  }

  String _makeListLiteral(List value, {bool forceStrings}) {
    final buffer = new StringBuffer();
    buffer.write('const [');
    
    for (int i = 0; i < value.length; i++) {
      if (i > 0) {
        buffer.write(',');
      }

      final element = value[i];

      if (element is String) {
        buffer.write(_checkEnvironmentVariable(_makeStringLiteral(element)));
      } else {
        if (forceStrings) {
          buffer.write(_makeStringLiteral(element.toString()));
        } else {
          buffer.write(_makeLiteral(element));
        }
      }
    }

    buffer.write(']');

    return buffer.toString();
  }

  Code _codeLiteral(String value) {
    if (value == null) return const Code('null');

    return Code(value);
  }

  Code _codeClassInstantiation(String className) {
    return Code('const $className()');
  }

  String _generatedClassNameOf(String className) {
    return '\$${className}Embedded';
  }
}
