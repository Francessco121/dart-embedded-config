import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:embedded_config/embedded_config.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import 'test_utils/in_memory_asset_string_writer.dart';

void main() {
  // Make sure generated files pass recommended lints
  test('analyzer lint test', () async {
    // Input config
    final config = {
      'test_config': {
        'inline': {
          'string': 'value',
          'stringMultiline': 'Multiline\nString',
          r'$int': 0,
          r'$double': 0.0,
          'doubleWithInt': 0,
          'numWithInt': 0,
          'numWithDouble': 0.0,
          'boolean': true,
          'stringList': ['a', 'b'],
          'intList': [0, 1],
          'doubleList': [0.4, 1.4],
          'doubleListWithInts': [0, 1, 2.4],
          'untypedList': [
            'a',
            0,
            1.4,
            true,
            null,
            ['b', false, null]
          ],
          'stringMap': {'key': 'value'},
          'numMap': {'int': 0, 'double': 0.0},
          'boolMap': {'key': true},
          'stringListMap': {
            'key': ['value']
          },
          'nestedMap': {
            'foo': {
              'bar': {
                'list': [1, 2, 3]
              },
              'test': true
            },
            'a': 1.2,
            '\$dollarKey': '\\\$\$'
          },
          'untypedMap': {
            'string': 'value',
            'num': 2.4,
            'boolean': true,
            'list': ['a', 0],
            'null': null
          },
          r'$dynamic': 0
        }
      }
    };

    // Dart source
    final fileSource = r'''
      import 'package:embedded_config_annotations/embedded_config_annotations.dart';
      
      part 'test.embedded.dart';

      @EmbeddedConfig('test_config')
      abstract class TestConfig {
        static const TestConfig instance = _$TestConfigEmbedded();

        String get string;
        String get stringMultiline;
        int get $int;
        double get $double;
        double get doubleWithInt;
        num get numWithInt;
        num get numWithDouble;
        bool get boolean;
        List<String> get stringList;
        List<int> get intList;
        List<double> get doubleList;
        List<double> get doubleListWithInts;
        List get untypedList;
        Map<String, String> get stringMap;
        Map<String, num> get numMap;
        Map<String, bool> get boolMap;
        Map<String, List<String>> get stringListMap;
        Map<String, dynamic> get nestedMap;
        Map get untypedMap;
        dynamic get $dynamic;

        const TestConfig();
      }
    ''';

    // Run generator
    final builder = configBuilder(BuilderOptions(config));
    final writer = InMemoryAssetStringWriter();

    await testBuilder(builder, {'a|lib/test.dart': fileSource},
        reader: await PackageAssetReader.currentIsolate(), writer: writer);

    // Analyze file
    final outputDirPath = p.join(p.current, 'test/_output');
    await Directory(outputDirPath).create();

    final srcFile = File(p.join(outputDirPath, 'test.dart'));
    await srcFile.writeAsString(fileSource);

    final partFile = File(p.join(outputDirPath, 'test.embedded.dart'));
    await partFile
        .writeAsString(writer.stringAssets['a|lib/test.embedded.dart']!);

    final result = await Process.run('dart',
        ['analyze', outputDirPath, '--fatal-warnings', '--fatal-infos']);
    expect(result.exitCode, equals(0),
        reason: 'dart analyze failed lint:\n${result.stdout}');
  });
}
