import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:embedded_config/src/build_exception.dart';
import 'package:test/test.dart';

import 'test_utils/test_utils.dart';

void main() {
  group('ConfigGenerator', () {
    test('generates a correctly named class', () async {
      await testGenerator(config: {
        'test_config': {'inline': {}}
      }, assets: {
        'a|lib/test.dart': '''
          import 'package:embedded_config_annotations/embedded_config_annotations.dart';
          
          part 'test.embedded.dart';

          @EmbeddedConfig('test_config')
          abstract class TestConfig {
            const TestConfig();
          }
        '''
      }, outputs: {
        'a|lib/test.embedded.dart': (CompilationUnit unit) {
          expect(unit.declarations, hasClass(r'_$TestConfigEmbedded'));
        }
      });
    });

    test('generates correctly named and typed fields', () async {
      await testGenerator(config: {
        'test_config': {
          'inline': {
            'string': 'value',
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
      }, assets: {
        'a|lib/test.dart': r'''
          import 'package:embedded_config_annotations/embedded_config_annotations.dart';
          
          part 'test.embedded.dart';

          @EmbeddedConfig('test_config')
          abstract class TestConfig {
            String get string;
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
            Map get untypedMap;
            dynamic get $dynamic;

            const TestConfig();
          }
        '''
      }, outputs: {
        'a|lib/test.embedded.dart': (CompilationUnit unit) {
          expect(unit.declarations, hasClass(r'_$TestConfigEmbedded'));
          final $class = getClass(unit, r'_$TestConfigEmbedded')!;

          testField($class, 'string', 'value');
          testField($class, r'$int', 0);
          testField($class, r'$double', 0.0);
          testField($class, 'doubleWithInt', 0);
          testField($class, 'numWithInt', 0);
          testField($class, 'numWithDouble', 0.0);
          testField($class, 'boolean', true);
          testField($class, 'stringList', ['a', 'b']);
          testField($class, 'intList', [0, 1]);
          testField($class, 'doubleList', [0.4, 1.4]);
          testField($class, 'doubleListWithInts', [0, 1, 2.4]);
          testField($class, 'untypedList', [
            'a',
            0,
            1.4,
            true,
            null,
            ['b', false, null]
          ]);
          testField($class, 'doubleListWithInts', [0, 1, 2.4]);
          testField($class, 'stringMap', {'key': 'value'});
          testField($class, 'numMap', {'int': 0, 'double': 0.0});
          testField($class, 'boolMap', {'key': true});
          testField($class, 'stringListMap', {
            'key': ['value']
          });
          testField($class, 'untypedMap', {
            'string': 'value',
            'num': 2.4,
            'boolean': true,
            'list': ['a', 0],
            'null': null
          });
          testField($class, r'$dynamic', 0);
        }
      });
    });

    test('handles nullable fields correctly', () async {
      await testGenerator(config: {
        'test_config': {
          'inline': {
            'string': null,
            r'$int': null,
            r'$double': null,
            'num': null,
            'boolean': null,
            'stringList': null,
            'intList': null,
            'untypedList': null,
            'untypedMap': null,
            r'$dynamic': null
          }
        }
      }, assets: {
        'a|lib/test.dart': r'''
          import 'package:embedded_config_annotations/embedded_config_annotations.dart';
          
          part 'test.embedded.dart';

          @EmbeddedConfig('test_config')
          abstract class TestConfig {
            String? get string;
            int? get $int;
            double? get $double;
            num? get num;
            bool? get boolean;
            List<String>? get stringList;
            List<int>? get intList;
            List<double>? get doubleList;
            List? get untypedList;
            Map? get untypedMap;

            const TestConfig();
          }
        '''
      }, outputs: {
        'a|lib/test.embedded.dart': (CompilationUnit unit) {
          expect(unit.declarations, hasClass(r'_$TestConfigEmbedded'));
          final $class = getClass(unit, r'_$TestConfigEmbedded')!;

          testField($class, 'string', null);
          testField($class, r'$int', null);
          testField($class, r'$double', null);
          testField($class, 'num', null);
          testField($class, 'boolean', null);
          testField($class, 'stringList', null);
          testField($class, 'intList', null);
          testField($class, 'doubleList', null);
          testField($class, 'untypedList', null);
          testField($class, 'untypedMap', null);
        }
      });
    });

    test('handles nullable fields with non-nullable values', () async {
      await testGenerator(config: {
        'test_config': {
          'inline': {
            'string': 'value',
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
            'untypedMap': {
              'string': 'value',
              'num': 2.4,
              'boolean': true,
              'list': ['a', 0],
              'null': null
            }
          }
        }
      }, assets: {
        'a|lib/test.dart': r'''
          import 'package:embedded_config_annotations/embedded_config_annotations.dart';
          
          part 'test.embedded.dart';

          @EmbeddedConfig('test_config')
          abstract class TestConfig {
            String? get string;
            int? get $int;
            double? get $double;
            double? get doubleWithInt;
            num? get numWithInt;
            num? get numWithDouble;
            bool? get boolean;
            List<String>? get stringList;
            List<int>? get intList;
            List<double>? get doubleList;
            List<double>? get doubleListWithInts;
            List? get untypedList;
            Map<String, String>? get stringMap;
            Map<String, num>? get numMap;
            Map<String, bool>? get boolMap;
            Map<String, List<String>>? get stringListMap;
            Map? get untypedMap;

            const TestConfig();
          }
        '''
      }, outputs: {
        'a|lib/test.embedded.dart': (CompilationUnit unit) {
          expect(unit.declarations, hasClass(r'_$TestConfigEmbedded'));
          final $class = getClass(unit, r'_$TestConfigEmbedded')!;

          testField($class, 'string', 'value');
          testField($class, r'$int', 0);
          testField($class, r'$double', 0.0);
          testField($class, 'doubleWithInt', 0);
          testField($class, 'numWithInt', 0);
          testField($class, 'numWithDouble', 0.0);
          testField($class, 'boolean', true);
          testField($class, 'stringList', ['a', 'b']);
          testField($class, 'intList', [0, 1]);
          testField($class, 'doubleList', [0.4, 1.4]);
          testField($class, 'doubleListWithInts', [0, 1, 2.4]);
          testField($class, 'untypedList', [
            'a',
            0,
            1.4,
            true,
            null,
            ['b', false, null]
          ]);
          testField($class, 'stringMap', {'key': 'value'});
          testField($class, 'numMap', {'int': 0, 'double': 0.0});
          testField($class, 'boolMap', {'key': true});
          testField($class, 'stringListMap', {
            'key': ['value']
          });
          testField($class, 'untypedMap', {
            'string': 'value',
            'num': 2.4,
            'boolean': true,
            'list': ['a', 0],
            'null': null
          });
        }
      });
    });

    test('requires non-null config value for non-nullable field', () {
      expect(
          () => testGenerator(config: {
                'test_config': {
                  'inline': {'requiredKey': null}
                }
              }, assets: {
                'a|lib/test.dart': '''
                  import 'package:embedded_config_annotations/embedded_config_annotations.dart';
                  
                  part 'test.embedded.dart';

                  @EmbeddedConfig('test_config')
                  abstract class TestConfig {
                    String get requiredKey;

                    const TestConfig();
                  }
                '''
              }, outputs: {
                'a|lib/test.embedded.dart': (CompilationUnit unit) {
                  expect(unit.declarations, hasClass(r'_$TestConfigEmbedded'));
                }
              }),
          throwsA(isA<BuildException>().having(
              (ex) => ex.element,
              'element',
              predicate((element) =>
                  element is PropertyAccessorElement &&
                  element.name == 'requiredKey'))));
    });

    test('handles sub configs', () async {
      await testGenerator(config: {
        'test_config': {
          'inline': {
            'sub': {'key': 'value'}
          }
        }
      }, assets: {
        'a|lib/test.dart': '''
          import 'package:embedded_config_annotations/embedded_config_annotations.dart';
          
          part 'test.embedded.dart';

          @EmbeddedConfig('test_config')
          abstract class TestConfig {
            TestSubConfig get sub;

            const TestConfig();
          }

          @EmbeddedConfig('test_config', path: ['sub'])
          abstract class TestSubConfig {
            String get key;

            const TestSubConfig();
          }
        '''
      }, outputs: {
        'a|lib/test.embedded.dart': (CompilationUnit unit) {
          expect(unit.declarations, hasClass(r'_$TestConfigEmbedded'));
          expect(unit.declarations, hasClass(r'_$TestSubConfigEmbedded'));

          final $class = getClass(unit, r'_$TestConfigEmbedded')!;
          testFieldClassName($class, 'sub', r'_$TestSubConfigEmbedded');

          final subClass = getClass(unit, r'_$TestSubConfigEmbedded')!;
          testField(subClass, 'key', 'value');
        }
      });
    });

    test('requires non-null config value for non-nullable class field', () {
      expect(
          () => testGenerator(config: {
                'test_config': {
                  'inline': {'sub': null}
                }
              }, assets: {
                'a|lib/test.dart': '''
                  import 'package:embedded_config_annotations/embedded_config_annotations.dart';
                  
                  part 'test.embedded.dart';

                  @EmbeddedConfig('test_config')
                  abstract class TestConfig {
                    TestSubConfig get sub;

                    const TestConfig();
                  }

                  @EmbeddedConfig('test_config', path: ['sub'])
                  abstract class TestSubConfig {
                    const TestSubConfig();
                  }
                '''
              }),
          throwsA(isA<BuildException>().having(
              (ex) => ex.element,
              'element',
              predicate((element) =>
                  element is PropertyAccessorElement &&
                  element.name == 'sub'))));
    });

    test('allows null config value for nullable class field', () async {
      await testGenerator(config: {
        'test_config': {
          'inline': {'sub': null}
        }
      }, assets: {
        'a|lib/test.dart': '''
          import 'package:embedded_config_annotations/embedded_config_annotations.dart';
          
          part 'test.embedded.dart';

          @EmbeddedConfig('test_config')
          abstract class TestConfig {
            TestSubConfig? get sub;

            const TestConfig();
          }

          @EmbeddedConfig('test_config', path: ['sub'])
          abstract class TestSubConfig {
            const TestSubConfig();
          }
        '''
      }, outputs: {
        'a|lib/test.embedded.dart': (CompilationUnit unit) {
          expect(unit.declarations, hasClass(r'_$TestConfigEmbedded'));
          expect(unit.declarations, hasClass(r'_$TestSubConfigEmbedded'));

          final $class = getClass(unit, r'_$TestConfigEmbedded')!;
          testField($class, 'sub', null);
        }
      });
    });
  });
}
