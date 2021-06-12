import 'dart:async';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:collection/collection.dart';
import 'package:embedded_config/embedded_config.dart';
import 'package:embedded_config/src/config_generator.dart';
import 'package:embedded_config/src/environment_provider.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

import 'in_memory_asset_string_writer.dart';

typedef OutputTestCallback = FutureOr<void> Function(CompilationUnit unit);

/// Tests the [ConfigGenerator] by running it using the [config] on
/// the given [assets] and testing the [outputs] using the provided test
/// functions per asset file.
///
/// To test the [outputs], use utilities like [getClass] and [testField].
///
/// If [outputs] is not provided, then the generator will just be ran
/// without validation. If a build exception is thrown, it will not be caught
/// here and can be handled by the caller.
///
/// A custom [environmentProvider] may be provided to allow the testing of
/// environment variable mapped config values.
///
/// See [testBuilder] for more info.
Future<void> testGenerator(
    {required Map<String, dynamic> config,
    required Map<String, String> assets,
    Map<String, OutputTestCallback>? outputs,
    EnvironmentProvider? environmentProvider}) async {
  // Create builder for ConfigGenerator
  Builder builder;

  if (environmentProvider == null) {
    builder = configBuilder(BuilderOptions(config));
  } else {
    builder = PartBuilder(
        [ConfigGenerator(config, environmentProvider: environmentProvider)],
        '.embedded.dart');
  }

  // Run generator
  final writer = InMemoryAssetStringWriter();

  await testBuilder(builder, assets,
      reader: await PackageAssetReader.currentIsolate(), writer: writer);

  // Test outputs
  if (outputs != null) {
    for (final entry in outputs.entries) {
      // Resolve compilation unit
      final CompilationUnit unit = await resolveSources(writer.stringAssets,
          (r) => r.compilationUnitFor(AssetId.parse(entry.key)));

      await entry.value(unit);
    }
  }
}

ClassDeclaration? getClass(CompilationUnit unit, String name) {
  return unit.declarations
          .firstWhereOrNull((d) => d is ClassDeclaration && d.name.name == name)
      as ClassDeclaration?;
}

Matcher hasClass(String name) {
  return contains(
      isA<ClassDeclaration>().having((d) => d.name.name, 'name', equals(name)));
}

void testField(ClassDeclaration $class, String name, dynamic value) {
  // Get field
  final ClassMember? member = $class.members.firstWhereOrNull((d) =>
      d is FieldDeclaration && d.fields.variables.first.name.name == name);

  expect(member, isNotNull, reason: 'Class has no field named $name');

  final VariableDeclaration field =
      (member as FieldDeclaration).fields.variables.first;

  // Test field initializer
  expect(field.initializer, isNotNull,
      reason: 'Field $name is missing an initializer');

  _testExpression(field.initializer!, value);
}

void testFieldClassName(
    ClassDeclaration $class, String name, String className) {
  // Get field
  final ClassMember? member = $class.members.firstWhereOrNull((d) =>
      d is FieldDeclaration && d.fields.variables.first.name.name == name);

  expect(member, isNotNull, reason: 'Class has no field named $name');

  final VariableDeclaration field =
      (member as FieldDeclaration).fields.variables.first;

  // Test field initializer
  expect(field.initializer, isNotNull,
      reason: 'Field $name is missing an initializer');

  expect(field.initializer, isA<InstanceCreationExpression>());

  final creationExp = field.initializer as InstanceCreationExpression;

  expect(creationExp.constructorName.type.name.name, equals(className));
}

void _testExpression(Expression exp, dynamic value) {
  if (value == null) {
    // null
    expect(exp, isA<NullLiteral>());
  } else if (value is String) {
    // String
    expect(exp, isA<SimpleStringLiteral>());
    expect((exp as SimpleStringLiteral).value, equals(value));
  } else if (value is double) {
    // double
    expect(exp, isA<DoubleLiteral>());
    expect((exp as DoubleLiteral).value, equals(value));
  } else if (value is int) {
    // int
    expect(exp, isA<IntegerLiteral>());
    expect((exp as IntegerLiteral).value, equals(value));
  } else if (value is bool) {
    // bool
    expect(exp, isA<BooleanLiteral>());
    expect((exp as BooleanLiteral).value, equals(value));
  } else if (value is List) {
    // List
    expect(exp, isA<ListLiteral>());

    final literal = exp as ListLiteral;

    expect(literal.elements.length, equals(value.length));

    for (int i = 0; i < value.length; i++) {
      final CollectionElement literalElement = exp.elements[i];
      final dynamic valueElement = value[i];

      expect(literalElement, isA<Expression>());
      _testExpression(literalElement as Expression, valueElement);
    }
  } else if (value is Map) {
    // Map
    expect(exp, isA<SetOrMapLiteral>());

    final literal = exp as SetOrMapLiteral;

    expect(literal.elements.length, equals(value.length));

    for (int i = 0; i < value.length; i++) {
      final CollectionElement literalElement = exp.elements[i];

      expect(literalElement, isA<MapLiteralEntry>());

      final literalEntry = literalElement as MapLiteralEntry;

      expect(literalEntry.key, isA<SimpleStringLiteral>());
      final literalEntryKey = literalEntry.key as SimpleStringLiteral;

      expect(value.containsKey(literalEntryKey.value), isTrue);

      final dynamic valueEntryValue = value[literalEntryKey.value];
      _testExpression(literalEntry.value, valueEntryValue);
    }
  } else {
    throw UnimplementedError('Unimplemented type ${value.runtimeType}');
  }
}
