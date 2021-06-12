import 'dart:convert';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';

/// An implementation of [RecordingAssetWriter] that writes outputs to memory
/// as UTF8 strings.
class InMemoryAssetStringWriter extends InMemoryAssetWriter {
  final Map<String, String> stringAssets = {};

  @override
  Future<void> writeAsBytes(AssetId id, List<int> bytes) async {
    stringAssets[id.toString()] = utf8.decode(bytes);

    await super.writeAsBytes(id, bytes);
  }

  @override
  Future<void> writeAsString(AssetId id, String contents,
      {Encoding encoding = utf8}) async {
    stringAssets[id.toString()] = contents;

    await super.writeAsString(id, contents, encoding: encoding);
  }
}
