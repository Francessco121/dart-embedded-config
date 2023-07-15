import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:embedded_config/src/build_exception.dart';
import 'package:test/test.dart';

import 'test_utils/map_environment_provider.dart';
import 'test_utils/test_utils.dart';

void main() {
  group('ConfigGenerator', () {
    group('yaml', () {
      test('basic', () async {
        await testGenerator(config: {
          'test_config': {'source': ['lib/test_config.yaml']}
        }, assets: {
          'a|lib/test_config.yaml': '''
              string: value
          ''',
          'a|lib/test.dart': '''
            import 'package:embedded_config_annotations/embedded_config_annotations.dart';

            part 'test.embedded.dart';

            @EmbeddedConfig('test_config')
            abstract class TestYamlConfig {
              const TestYamlConfig();

              String get string;
            }
          '''
        }, outputs: {
          'a|lib/test.embedded.dart': (CompilationUnit unit) {
            expect(unit.declarations, hasClass(r'_$TestYamlConfigEmbedded'));
            final $class = getClass(unit, r'_$TestYamlConfigEmbedded')!;

            testField($class, 'string', 'value');
          }
        });
      });
      test('generates correctly named and typed fields', () async {
        await testGenerator(config: {
          'test_config': {'source': ['lib/test_config.yaml']}
        }, assets: {
          'a|lib/test_config.yaml': '''
              string: value
              stringMultiline: |-
                Multiline
                String
              doubleWithInt: 0
              numWithInt: 0
              numWithDouble: 0.0
              boolean: true
              stringList:
                  - a
                  - b
              intList: [0, 1]
              doubleList: [0.4, 1.4]
              doubleListWithInts: [0, 1, 2.4]
              untypedList:
                - a
                - 0
                - 1.4
                - true
                - null
                - ['b', false, null]
              stringMap: {'key': 'value'}
              numMap:
                  int: 0
                  double: 0.0
              boolMap:
                  key: true
              stringListMap:
                key:
                    - value
              untypedMap:
                string: value
                num: 2.4
                boolean: true
                list:
                  - a
                  - 0
                null: null
          ''',
          'a|lib/test.dart': r'''
            import 'package:embedded_config_annotations/embedded_config_annotations.dart';

            part 'test.embedded.dart';

            @EmbeddedConfig('test_config')
            abstract class TestConfig {
              String get string;
              String get stringMultiline;
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
              const TestConfig();
            }
          '''
        }, outputs: {
          'a|lib/test.embedded.dart': (CompilationUnit unit) {
            expect(unit.declarations, hasClass(r'_$TestConfigEmbedded'));
            final $class = getClass(unit, r'_$TestConfigEmbedded')!;

            testField($class, 'string', 'value');
            testField($class, 'stringMultiline', 'Multiline\nString');
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
          }
        });
      });

    });
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

    test('handles environment variables and environment variable escaping',
        () async {
      await testGenerator(
          config: {
            'test_config': {
              'inline': {
                'envVar': r'$VARIABLE',
                r'envVarWith$': r'$$VARIABLE',
                'escapedEnvVar': r'\$VARIABLE',
                r'escapeEnvVarWithExtraSlash': r'\\$VARIABLE',
                r'variableWithSlash$': r'VARIABLE\$'
              }
            }
          },
          assets: {
            'a|lib/test.dart': r'''
              import 'package:embedded_config_annotations/embedded_config_annotations.dart';
              
              part 'test.embedded.dart';

              @EmbeddedConfig('test_config')
              abstract class TestConfig {
                String get envVar;
                String get envVarWith$;
                String get escapedEnvVar;
                String get escapeEnvVarWithExtraSlash;
                String get variableWithSlash$;

                const TestConfig();
              }
            '''
          },
          environmentProvider: MapEnvironmentProvider(
              {'VARIABLE': 'value1', r'$VARIABLE': 'value2'}),
          outputs: {
            'a|lib/test.embedded.dart': (CompilationUnit unit) {
              expect(unit.declarations, hasClass(r'_$TestConfigEmbedded'));
              final $class = getClass(unit, r'_$TestConfigEmbedded')!;

              testField($class, 'envVar', 'value1');
              testField($class, r'envVarWith$', 'value2');
              testField($class, 'escapedEnvVar', r'$VARIABLE');
              testField($class, 'escapeEnvVarWithExtraSlash', r'\$VARIABLE');
              testField($class, r'variableWithSlash$', r'VARIABLE\$');
            }
          });
    });

    test('allows properties to be renamed', () async {
      await testGenerator(config: {
        'test_config': {
          'inline': {
            'test_1': 'value',
            'test_2': 0,
            'test_3': true,
            'test_4': ['a'],
            'test_5': {'a': 'b'}
          }
        }
      }, assets: {
        'a|lib/test.dart': '''
          import 'package:embedded_config_annotations/embedded_config_annotations.dart';
          
          part 'test.embedded.dart';

          @EmbeddedConfig('test_config')
          abstract class TestConfig {
            @EmbeddedPropertyName('test_1')
            String get test1;

            @EmbeddedPropertyName('test_2')
            num get test2;

            @EmbeddedPropertyName('test_3')
            bool get test3;

            @EmbeddedPropertyName('test_4')
            List get test4;

            @EmbeddedPropertyName('test_5')
            Map get test5;

            const TestConfig();
          }
        '''
      }, outputs: {
        'a|lib/test.embedded.dart': (CompilationUnit unit) {
          expect(unit.declarations, hasClass(r'_$TestConfigEmbedded'));
          final $class = getClass(unit, r'_$TestConfigEmbedded')!;

          testField($class, 'test1', 'value');
          testField($class, 'test2', 0);
          testField($class, 'test3', true);
          testField($class, 'test4', ['a']);
          testField($class, 'test5', {'a': 'b'});
        }
      });
    });

    test('allows properties to be private', () async {
      await testGenerator(config: {
        'test_config': {
          'inline': {'key1': 'value1', 'key_2': 'value2'}
        }
      }, assets: {
        'a|lib/test.dart': '''
          import 'package:embedded_config_annotations/embedded_config_annotations.dart';
          
          part 'test.embedded.dart';

          @EmbeddedConfig('test_config')
          abstract class TestConfig {
            String get _key1;

            @EmbeddedPropertyName('key_2')
            String get _key2;

            const TestConfig();
          }
        '''
      }, outputs: {
        'a|lib/test.embedded.dart': (CompilationUnit unit) {
          expect(unit.declarations, hasClass(r'_$TestConfigEmbedded'));
          final $class = getClass(unit, r'_$TestConfigEmbedded')!;

          testField($class, '_key1', 'value1');
          testField($class, '_key2', 'value2');
        }
      });
    });
  });
}
