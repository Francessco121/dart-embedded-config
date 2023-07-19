import 'dart:async';
import 'dart:convert';

import 'package:yaml/yaml.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:embedded_config_annotations/embedded_config_annotations.dart';
import 'package:source_gen/source_gen.dart' as source_gen;

import 'build_exception.dart';
import 'environment_provider.dart';
import 'key_config.dart';

const _classAnnotationTypeChecker =
    source_gen.TypeChecker.fromRuntime(EmbeddedConfig);
const _getterNameAnnotationTypeChecker =
    source_gen.TypeChecker.fromRuntime(EmbeddedPropertyName);
const _stringTypeChecker = source_gen.TypeChecker.fromRuntime(String);
const _listTypeChecker = source_gen.TypeChecker.fromRuntime(List);
const _mapTypeChecker = source_gen.TypeChecker.fromRuntime(Map);
const _numTypeChecker = source_gen.TypeChecker.fromRuntime(num);
const _boolTypeChecker = source_gen.TypeChecker.fromRuntime(bool);

class _AnnotatedClass {
  final ClassElement element;
  final EmbeddedConfig annotation;
  final Map<PropertyAccessorElement, String> annotatedGetters;

  _AnnotatedClass(this.element, this.annotation, this.annotatedGetters);
}

class ConfigGenerator extends source_gen.Generator {
  final Map<String, KeyConfig> _keys;
  final EnvironmentProvider _environmentProvider;

  ConfigGenerator(Map<String, dynamic> config,
      {EnvironmentProvider environmentProvider =
          const PlatformEnvironmentProvider()})
      // Parse key configs
      : _keys = config.map((k, v) => MapEntry(k, KeyConfig.fromBuildConfig(v))),
        _environmentProvider = environmentProvider;

  @override
  FutureOr<String?> generate(
      source_gen.LibraryReader library, BuildStep buildStep) async {
    // Get annotated classes
    final sourceClasses = <_AnnotatedClass>[];
    final annotatedElements =
        library.annotatedWith(_classAnnotationTypeChecker);

    for (final annotatedElement in annotatedElements) {
      final classElement = annotatedElement.element;

      if (classElement is! ClassElement ||
          !classElement.isAbstract ||
          classElement is EnumElement) {
        throw BuildException(
            'Only abstract classes may be annotated with @EmbeddedConfig!',
            classElement);
      }

      // Get annotated getters
      final annotatedGetterNames = <PropertyAccessorElement, String>{};

      for (final accessor in classElement.accessors) {
        final annotation =
            _getterNameAnnotationTypeChecker.firstAnnotationOf(accessor);

        if (annotation != null) {
          final reader = source_gen.ConstantReader(annotation);

          annotatedGetterNames[accessor] = reader.read('name').stringValue;
        }
      }

      sourceClasses.add(_AnnotatedClass(
          classElement,
          _reconstructClassAnnotation(annotatedElement.annotation),
          annotatedGetterNames));
    }

    // Build classes
    final classes = <Class>[];
    final generatedClasses = <String>{};

    for (final annotatedClass in sourceClasses) {
      // Resolve real config values
      final config = await _resolveConfig(
          buildStep, annotatedClass.element, annotatedClass.annotation);

      // Generate class
      final $class = _generateClass(
          annotatedClass.element,
          annotatedClass.annotatedGetters,
          config,
          sourceClasses,
          generatedClasses);

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
    final libraryAst = Library((l) => l..body.addAll(classes));

    // Emit source
    final emitter = DartEmitter(allocator: Allocator.simplePrefixing());

    return libraryAst.accept(emitter).toString();
  }

  /// Reconstructs an [EmbeddedConfig] annotation from a
  /// [source_gen.ConstantReader] of one.
  EmbeddedConfig _reconstructClassAnnotation(source_gen.ConstantReader reader) {
    String key;
    List<String>? path;

    final keyReader = reader.read('key');
    key = keyReader.stringValue;

    final pathReader = reader.read('path');
    if (!pathReader.isNull) {
      path = pathReader.listValue.map((v) => v.toStringValue()!).toList();
    }

    return EmbeddedConfig(key, path: path);
  }

  /// Resolves the config values for the given embedded config [annotation].
  Future<Map<String, dynamic>> _resolveConfig(BuildStep buildStep,
      ClassElement classElement, EmbeddedConfig annotation) async {
    // Get the key config
    final KeyConfig? keyConfig = _keys[annotation.key];

    if (keyConfig == null) {
      throw BuildException(
          'No embedded config defined for key: ${annotation.key}',
          classElement);
    }

    var config = <String, dynamic>{};

    // Apply file sources
    if (keyConfig.sources != null) {
      for (final filePath in keyConfig.sources!) {
        // Read file
        final assetId = AssetId(buildStep.inputId.package, filePath);
        final assetContents = await buildStep.readAsString(assetId);

        Map<String, dynamic> fileConfig;

        final filePathTrimmed = filePath.trimRight();

        if (filePathTrimmed.endsWith('.json')) {
          fileConfig = json.decode(assetContents);
        } else if (filePathTrimmed.endsWith('.yaml') ||
            filePathTrimmed.endsWith('.yml')) {
          fileConfig = _assertYamlKeys(loadYaml(assetContents), classElement);
        } else {
          throw BuildException(
              'Embedded config file sources must be either JSON or YAML documents.',
              classElement);
        }

        // Merge file into config
        _mergeMaps(config, fileConfig);
      }
    }

    // Apply inline source
    if (keyConfig.inline != null) {
      _mergeMaps(config, keyConfig.inline!);
    }

    // Follow path if specified
    if (annotation.path != null) {
      for (final key in annotation.path!) {
        if (config.containsKey(key)) {
          if (config[key] == null) {
            return {};
          } else {
            final subConfig = config[key];
            if (subConfig is YamlMap) {
              config = _assertYamlKeys(subConfig, classElement);
            } else {
              config = config[key];
            }
          }
        } else {
          throw BuildException(
              "Could not follow path '${annotation.path}' for config "
              '${annotation.key}.',
              classElement);
        }
      }
    }

    return config;
  }

  /// Asserts that all YAML keys are strings.
  Map<String, dynamic> _assertYamlKeys(YamlMap map, ClassElement element) {
    for (final key in map.keys) {
      if (key is! String) {
        throw BuildException(
            'YAML key $key (${key.runtimeType}) must be a string.', element);
      }
    }

    return map.cast<String, dynamic>();
  }

  /// Merges the [top] map on top of the [base] map, overwriting values at the
  /// lowest level possible.
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
  Class? _generateClass(
      ClassElement $class,
      Map<PropertyAccessorElement, String> getterNames,
      Map<String, dynamic> config,
      List<_AnnotatedClass> sourceClasses,
      Set<String> generatedClasses) {
    if (generatedClasses.contains($class.name)) {
      // This class has already been generated
      return null;
    }

    generatedClasses.add($class.name);

    // Generate field overrides for each non-static abstract getter
    final fields = <Field>[];

    final getters = $class.accessors.where((accessor) =>
        accessor.isGetter && !accessor.isStatic && accessor.isAbstract);

    for (final getter in getters) {
      try {
        fields.add(_generateOverrideForGetter(
            getter, config, sourceClasses, getterNames[getter]));
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
    final constructor = $class.unnamedConstructor;
    if (constructor == null || !constructor.isConst) {
      throw BuildException(
          'Embedded config classes must declare a const default constructor.',
          $class);
    }

    // Build class
    return Class((c) => c
      ..name = _generatedClassNameOf($class.name)
      ..extend = refer($class.name)
      ..fields.addAll(fields)
      ..constructors.add(Constructor((t) => t..constant = true)));
  }

  /// Generates a field which overrides the given [getter].
  ///
  /// The field contains the embedded config value for the
  /// [getter] retrieved from the [config].
  Field _generateOverrideForGetter(
      PropertyAccessorElement getter,
      Map<String, dynamic> config,
      List<_AnnotatedClass> sourceClasses,
      String? customKey) {
    final returnType = getter.returnType;

    // Determine key
    final String key;

    if (customKey == null) {
      key = getter.isPrivate ? getter.name.substring(1) : getter.name;
    } else {
      key = customKey;
    }

    // Ensure non-null value provided for non-null field
    if (returnType.nullabilitySuffix == NullabilitySuffix.none &&
        returnType is! DynamicType &&
        config[key] == null) {
      throw BuildException(
          'Must provide a non-null config value for a non-nullable config property.');
    }

    // Handle type
    if (_stringTypeChecker.isExactlyType(returnType)) {
      // String
      final value = _getString(config, key);

      return Field((f) => f
        ..annotations.add(refer('override'))
        ..modifier = FieldModifier.final$
        ..name = getter.name
        ..assignment = _codeLiteral(value));
    } else if (_listTypeChecker.isAssignableFromType(returnType)) {
      // List
      var forceStrings = false;

      if (returnType is ParameterizedType) {
        // Force all values to strings if this is a List<String>
        forceStrings = returnType.typeArguments.isNotEmpty &&
            _stringTypeChecker.isExactlyType(returnType.typeArguments.first);
      }

      final value = _getList(config, key, forceStrings: forceStrings);

      return Field((f) => f
        ..annotations.add(refer('override'))
        ..modifier = FieldModifier.final$
        ..name = getter.name
        ..assignment = _codeLiteral(value));
    } else if (_mapTypeChecker.isAssignableFromType(returnType)) {
      // Map
      var forceStrings = false;

      if (returnType is ParameterizedType) {
        // Force all values to strings if this is a Map<T, String>
        forceStrings = returnType.typeArguments.length > 1 &&
            _stringTypeChecker.isExactlyType(returnType.typeArguments[1]);
      }

      final value = _getMap(config, key, forceStrings: forceStrings);

      return Field((f) => f
        ..annotations.add(refer('override'))
        ..modifier = FieldModifier.final$
        ..name = getter.name
        ..assignment = _codeLiteral(value));
    } else if (_numTypeChecker.isAssignableFromType(returnType) ||
        _boolTypeChecker.isAssignableFromType(returnType) ||
        returnType is DynamicType) {
      // Num, bool, dynamic, num? (note: num? will be dynamic)
      final value = _getLiteral(config, key);

      return Field((f) => f
        ..annotations.add(refer('override'))
        ..modifier = FieldModifier.final$
        ..name = getter.name
        ..assignment = _codeLiteral(value));
    } else if (returnType.element is ClassElement) {
      // Class
      final innerClass = returnType.element as ClassElement;

      if (returnType.element!.library != getter.library) {
        throw BuildException(
            'Cannot reference a class from a different library as '
            'a config property.');
      }

      if (!sourceClasses.any((c) => c.element == innerClass)) {
        throw BuildException(
            'Cannot reference a non embedded config class as a config '
            'property.');
      }

      // Add field
      return Field((f) => f
        ..annotations.add(refer('override'))
        ..modifier = FieldModifier.final$
        ..name = getter.name
        ..assignment = config[key] == null
            ? _codeLiteral(null)
            : _codeClassInstantiation(_generatedClassNameOf(innerClass.name)));
    } else {
      // Any
      throw BuildException('Type $returnType is not supported.');
    }
  }

  /// If the given [string] starts with `$`, then the value of
  /// the environment variable with the name specified by the remaining
  /// characters in [string] after the `$` will be returned.
  ///
  /// If [string] starts with `\$` then the `$` will be treated as
  /// an escaped character (environment variables will not be queried)
  /// and the first `\` will be removed. This also means that for every
  /// `\` starting character after the first, one will always be removed
  /// to account for the escaping (ex. `\\$` turns into `\$`).
  String? _checkEnvironmentVariable(String string) {
    if (string.startsWith(RegExp(r'^\\+\$'))) {
      return string.substring(1);
    } else if (string.startsWith(r'$')) {
      return _environmentProvider.environment[string.substring(1)];
    } else {
      return string;
    }
  }

  String? _getLiteral(Map<String, dynamic> map, String key) {
    final dynamic value = map[key];

    if (value == null) return null;

    return _makeLiteral(value);
  }

  String? _getString(Map<String, dynamic> map, String key) {
    final dynamic value = map[key];

    if (value == null) return null;

    if (value is String) {
      return _makeStringLiteral(_checkEnvironmentVariable(value));
    } else {
      return _makeStringLiteral(value.toString());
    }
  }

  String? _getList(Map<String, dynamic> map, String key,
      {bool forceStrings = false}) {
    final dynamic value = map[key];

    if (value == null) return null;

    if (value is List) {
      return _makeListLiteral(value, forceStrings: forceStrings);
    } else {
      throw BuildException("Config value '$key' must be a list.");
    }
  }

  String? _getMap(Map<String, dynamic> map, String key,
      {bool forceStrings = false}) {
    final dynamic value = map[key];

    if (value == null) return null;

    if (value is Map) {
      return _makeMapLiteral(value, forceStrings: forceStrings);
    } else {
      throw BuildException("Config value '$key' must be a map.");
    }
  }

  String _makeLiteral(dynamic value) {
    if (value is String) {
      return _makeStringLiteral(_checkEnvironmentVariable(value));
    } else if (value is bool) {
      return _makeBoolLiteral(value);
    } else if (value is List) {
      return _makeListLiteral(value);
    } else if (value is Map) {
      return _makeMapLiteral(value);
    } else {
      return value.toString();
    }
  }

  String _makeBoolLiteral(bool value) {
    return value ? 'true' : 'false';
  }

  String _makeStringLiteral(String? value) {
    if (value != null) {
      value = value
          .replaceAll('\\', '\\\\')
          .replaceAll("'", "\\'")
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r')
          .replaceAll(r'$', '\\\$');
    }

    return "'$value'";
  }

  String _makeListLiteral(List value, {bool forceStrings = false}) {
    final buffer = StringBuffer();
    buffer.write('const [');

    for (var i = 0; i < value.length; i++) {
      if (i > 0) {
        buffer.write(',');
      }

      final element = value[i];

      if (element is String) {
        buffer.write(_makeStringLiteral(_checkEnvironmentVariable(element)));
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

  String _makeMapLiteral(Map value, {bool forceStrings = false}) {
    final buffer = StringBuffer();
    buffer.write('const {');

    var first = true;
    for (final entry in value.entries) {
      if (!first) {
        buffer.write(',');
      }

      buffer.write(_makeStringLiteral(entry.key.toString()));
      buffer.write(': ');

      final value = entry.value;

      if (value is String) {
        buffer.write(_makeStringLiteral(_checkEnvironmentVariable(value)));
      } else {
        if (forceStrings && value is! List && value is! Map) {
          buffer.write(_makeStringLiteral(value.toString()));
        } else {
          buffer.write(_makeLiteral(value));
        }
      }

      first = false;
    }

    buffer.write('}');

    return buffer.toString();
  }

  Code _codeLiteral(String? value) {
    if (value == null) return const Code('null');

    return Code(value);
  }

  Code _codeClassInstantiation(String className) {
    return Code('const $className()');
  }

  String _generatedClassNameOf(String className) {
    return '_\$${className}Embedded';
  }
}
