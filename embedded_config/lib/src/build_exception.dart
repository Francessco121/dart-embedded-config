import 'package:analyzer/dart/element/element.dart';

class BuildException implements Exception {
  final String message;

  final Element element;

  BuildException(this.message, [this.element]);

  @override
  String toString() => '[${element.displayName}] $message';
}