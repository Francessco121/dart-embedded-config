import 'ast.dart';

/// For every unique [ClassNode], generates a [StringBuffer] with the generated code
/// implementation of the user-defined config class.
class BufferGenerator implements AstVisitor {
  StringBuffer _currentBuffer;
  Map _currentMap;

  final Map<ClassNode, StringBuffer> _buffers = {};

  Iterable<StringBuffer> generateBuffers(ClassNode rootClass, Map rootMap) {
    _currentMap = rootMap;
    _currentBuffer = StringBuffer();
    _buffers[rootClass] = _currentBuffer;

    visitClass(rootClass);

    return _buffers.values;
  }
  
  @override
  void visitClass(ClassNode node) {
    final String embeddedClassName = _embeddedClassNameOf(node.name);

    _currentBuffer
      ..writeln()
      ..writeln('class $embeddedClassName extends ${node.name} {');

    for (AstNode getter in node.getters) {
      getter.accept(this);
    }

    _currentBuffer
      ..writeln('const $embeddedClassName();')
      ..writeln()
      ..writeln('}');
  }

  @override
  void visitClassGetter(ClassGetterNode node) {
    if (!_buffers.containsKey(node.classNode)) {
      // Class not generated yet
      StringBuffer lastBuffer = _currentBuffer;
      Map lastMap = _currentMap;

      _currentBuffer = StringBuffer();
      _currentMap = _currentMap[node.name];

      _buffers[node.classNode] = _currentBuffer;
      
      node.classNode.accept(this);

      _currentBuffer = lastBuffer;
      _currentMap = lastMap;
    }

    final String embeddedClassName = _embeddedClassNameOf(node.returnType);
    final String fieldName = '_${node.name}';

    _currentBuffer
      ..writeln('@override')
      ..writeln('$embeddedClassName get ${node.name} => $fieldName;')
      ..writeln('static const $fieldName = const $embeddedClassName();')
      ..writeln();
  }

  @override
  void visitStringGetter(StringGetterNode node) {
    final String content = _currentMap[node.name];
    final String fieldName = '_${node.name}';

    _currentBuffer
      ..writeln('@override')
      ..writeln('${node.returnType} get ${node.name} => $fieldName;')
      ..writeln("static const $fieldName = '$content';")
      ..writeln();
  }

  @override
  void visitStringListGetter(StringListGetterNode node) {
    final List<String> content = _currentMap[node.name]
      .cast<String>();

    final String fieldName = '_${node.name}';

    _currentBuffer
      ..writeln('@override')
      ..writeln('List<String> get ${node.name} => $fieldName;')
      ..writeln('static const $fieldName = [');

    for (String item in content) {
      _currentBuffer.writeln("'$item',");
    }

    _currentBuffer
      ..writeln('];')
      ..writeln();
  }

  static String _embeddedClassNameOf(String className) {
    return '\$${className}Embedded'; 
  }
}