import 'package:embedded_config/src/build_exception.dart';
import 'package:embedded_config/src/key_config.dart';
import 'package:test/test.dart';

void main() {
  group('KeyConfig', () {
    test('parses single source', () {
      final config = 'test_source';
      final keyConfig = KeyConfig.fromBuildConfig(config);

      expect(keyConfig.sources, equals(['test_source']));
    });

    test('parses single source from map key', () {
      final config = {'source': 'test_source'};
      final keyConfig = KeyConfig.fromBuildConfig(config);

      expect(keyConfig.sources, equals(['test_source']));
    });

    test('parses multiple sources from map key', () {
      final config = {
        'source': ['test_source1', 'test_source2']
      };
      final keyConfig = KeyConfig.fromBuildConfig(config);

      expect(keyConfig.sources, equals(['test_source1', 'test_source2']));
    });

    test('parses inline config', () {
      final config = {
        'inline': {'key1': 'value1', 'key2': 'value2'}
      };
      final keyConfig = KeyConfig.fromBuildConfig(config);

      expect(keyConfig.inline, equals({'key1': 'value1', 'key2': 'value2'}));
    });

    test('parses sources and inline config', () {
      final config1 = {
        'source': 'test_source',
        'inline': {'key1': 'value1', 'key2': 'value2'}
      };

      final keyConfig1 = KeyConfig.fromBuildConfig(config1);

      expect(keyConfig1.sources, equals(['test_source']));
      expect(keyConfig1.inline, equals({'key1': 'value1', 'key2': 'value2'}));

      final config2 = {
        'source': ['test_source1', 'test_source2'],
        'inline': {'key1': 'value1', 'key2': 'value2'}
      };

      final keyConfig2 = KeyConfig.fromBuildConfig(config2);

      expect(keyConfig2.sources, equals(['test_source1', 'test_source2']));
      expect(keyConfig2.inline, equals({'key1': 'value1', 'key2': 'value2'}));
    });

    test('requires source as a String or Map', () {
      expect(() => KeyConfig.fromBuildConfig({'source': 0}),
          throwsA(isA<BuildException>()));
      expect(() => KeyConfig.fromBuildConfig({'source': {}}),
          throwsA(isA<BuildException>()));
    });

    test('requires inline as a Map', () {
      expect(() => KeyConfig.fromBuildConfig({'inline': 0}),
          throwsA(isA<BuildException>()));
      expect(() => KeyConfig.fromBuildConfig({'inline': []}),
          throwsA(isA<BuildException>()));
      expect(() => KeyConfig.fromBuildConfig({'inline': ''}),
          throwsA(isA<BuildException>()));
    });

    test('requires at least either a file source or an inline source', () {
      expect(
          () => KeyConfig.fromBuildConfig({}), throwsA(isA<BuildException>()));
      expect(() => KeyConfig.fromBuildConfig(null),
          throwsA(isA<BuildException>()));
    });
  });
}
