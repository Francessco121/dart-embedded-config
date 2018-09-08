import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

import 'ast.dart';

ClassNode parse(ClassElement rootClass) {
  return _parseClass(rootClass);
}

const TypeChecker _stringTypeChecker = TypeChecker.fromRuntime(String);
const TypeChecker _listTypeChecker = TypeChecker.fromRuntime(List);

ClassNode _parseClass(ClassElement classElement) {
  List<AstNode> getterNodes = [];

  Iterable<PropertyAccessorElement> getters = classElement.accessors
    .where((accessor) => accessor.isGetter);

  for (PropertyAccessorElement getter in getters) {
    AstNode node;
    
    if (_stringTypeChecker.isExactlyType(getter.returnType)) {
      node = _parseStringGetter(getter);
    } else if (_listTypeChecker.isAssignableFromType(getter.returnType)) {
      // Ensure is list of strings
      if (getter.returnType is ParameterizedType) {
        ParameterizedType type = getter.returnType;

        if (type.typeArguments.isNotEmpty) {
          if (_stringTypeChecker.isExactlyType(type.typeArguments.first)) {
            node = _parseStringListGetter(getter);
          }
        }
      }
    } else if (getter.returnType.element is ClassElement) {
      node = _parseClassGetterNode(getter);
    }

    if (node != null) {
      getterNodes.add(node);
    }
  }

  return ClassNode(classElement, getterNodes);
}

ClassGetterNode _parseClassGetterNode(PropertyAccessorElement getter) {
  ClassNode classNode = _parseClass(getter.returnType.element);

  return ClassGetterNode(getter, classNode);
}

StringGetterNode _parseStringGetter(PropertyAccessorElement getter) {
  return StringGetterNode(getter);
}

StringListGetterNode _parseStringListGetter(PropertyAccessorElement getter) {
  return StringListGetterNode(getter);
}