import 'package:analyzer/dart/element/element.dart';

abstract class AstVisitor {
  void visitClass(ClassNode node);
  void visitClassGetter(ClassGetterNode node);
  void visitStringGetter(StringGetterNode node);
  void visitStringListGetter(StringListGetterNode node);
}

abstract class AstNode {
  void accept(AstVisitor visitor);
}

class ClassNode implements AstNode {
  final ClassElement element;
  final String name;
  final List<AstNode> getters;

  ClassNode(this.element, this.getters)
    : name = element.name;

  @override
  void accept(AstVisitor visitor) {
    visitor.visitClass(this);
  }
}

class ClassGetterNode implements AstNode {
  final PropertyAccessorElement element;
  final String name;
  final String returnType;
  final ClassNode classNode;

  ClassGetterNode(this.element, this.classNode)
    : name = element.name,
      returnType = element.returnType.name;

  @override
  void accept(AstVisitor visitor) {
    visitor.visitClassGetter(this);
  }
}

class StringGetterNode implements AstNode {
  final PropertyAccessorElement element;
  final String name;
  final String returnType;

  StringGetterNode(this.element)
    : name = element.name,
      returnType = element.returnType.name;

  @override
  void accept(AstVisitor visitor) {
    visitor.visitStringGetter(this);
  }
}

class StringListGetterNode implements AstNode {
  final PropertyAccessorElement element;
  final String name;
  final String returnType;

  StringListGetterNode(this.element)
    : name = element.name,
      returnType = element.returnType.name;

  @override
  void accept(AstVisitor visitor) {
    visitor.visitStringListGetter(this);
  }
}
