import '../config/pubspec_config.dart';
import '../config/yml_generator_config.dart';
import '../model/item_type/array_type.dart';
import '../model/model/custom_from_to_json_model.dart';
import '../model/model/object_model.dart';
import '../util/case_util.dart';
import '../util/type_checker.dart';

class ObjectModelWriter {
  final PubspecConfig pubspecConfig;
  final ObjectModel jsonModel;
  final YmlGeneratorConfig yamlConfig;

  const ObjectModelWriter(this.pubspecConfig, this.jsonModel, this.yamlConfig);

  String write() {
    final sb = StringBuffer();
    final imports = <String>{};

    final containsRequiredFields =
        jsonModel.fields.where((item) => item.isRequired).toList().isNotEmpty;
    if (containsRequiredFields) {
      imports.add("import 'package:flutter/material.dart';");
    }

    imports.add("import 'package:json_annotation/json_annotation.dart';");

    jsonModel.fields.forEach((field) {
      if (!TypeChecker.isKnownDartType(field.type.name)) {
        imports.add(_getImportFromPath(field.type.name));
      }
    });
    jsonModel.converters.forEach((converter) {
      imports.add(_getImportFromPath(converter));
    });
    imports.forEach(sb.writeln);

    sb
      ..writeln()
      ..writeln("part '${jsonModel.fileName}.g.dart';")
      ..writeln()
      ..writeln('@JsonSerializable()');

    jsonModel.converters.forEach((converter) {
      sb.writeln('@$converter()');
    });

    sb.writeln('class ${jsonModel.name} {');

    jsonModel.fields.sort((a, b) {
      final b1 = a.isRequired ? 1 : 0;
      final b2 = b.isRequired ? 1 : 0;
      return b2 - b1;
    });

    jsonModel.fields.forEach((key) {
      sb.write("  @JsonKey(name: '${key.serializedName}'");
      if (key.isRequired) {
        sb.write(', required: true');
      } else {
        sb.write(', nullable: true');
      }

      if (!key.includeIfNull) {
        sb.write(', includeIfNull: false');
      }

      if (key.ignore) {
        sb.write(', ignore: true');
      }

      if (key.unknownEnumValue != null) {
        sb.write(
            ', unknownEnumValue: ${key.type.name}.${key.unknownEnumValue}');
      }

      final fieldModel = yamlConfig.getModelByName(key.type);
      if (fieldModel is CustomFromToJsonModel) {
        sb.write(', fromJson: handle${fieldModel.name}FromJson');
      }
      if (fieldModel is CustomFromToJsonModel) {
        sb.write(', toJson: handle${fieldModel.name}ToJson');
      }
      sb.writeln(')');
      if (key.nonFinal) {
        sb.write('  ');
      } else {
        sb.write('  final ');
      }
      final nullableFlag =
          pubspecConfig.nullSafe ? (key.isRequired ? '' : '?') : '';
      if (key.type is ArrayType) {
        sb.writeln('List<${key.type.name}>$nullableFlag ${key.name};');
      } else {
        sb.writeln('${key.type.name}$nullableFlag ${key.name};');
      }
    });

    sb..writeln()..writeln('  ${jsonModel.name}({');

    jsonModel.fields.forEach((key) {
      if (key.isRequired) {
        if (pubspecConfig.nullSafe) {
          sb.writeln('    required this.${key.name},');
        } else {
          sb.writeln('    @required this.${key.name},');
        }
      } else {
        sb.writeln('    this.${key.name},');
      }
    });
    sb
      ..writeln('  });')
      ..writeln()
      ..writeln(
          '  factory ${jsonModel.name}.fromJson(Map<String, dynamic> json) => _\$${jsonModel.name}FromJson(json);')
      ..writeln()
      ..writeln(
          '  Map<String, dynamic> toJson() => _\$${jsonModel.name}ToJson(this);')
      ..writeln()
      ..writeln('}');
    return sb.toString();
  }

  String _getImportFromPath(String name) {
    final projectName = pubspecConfig.projectName;
    final reCaseFieldName = CaseUtil(name);
    final path = yamlConfig.getPathForName(pubspecConfig, name);
    String pathWithPackage;
    if (path.startsWith('package:')) {
      pathWithPackage = path;
    } else {
      pathWithPackage = 'package:$projectName/$path';
    }

    if (path.endsWith('.dart')) {
      return "import '$pathWithPackage';";
    } else {
      return "import '$pathWithPackage/${reCaseFieldName.snakeCase}.dart';";
    }
  }
}
