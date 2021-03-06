import 'package:model_generator/config/pubspec_config.dart';
import 'package:model_generator/model/field.dart';
import 'package:model_generator/model/item_type/array_type.dart';
import 'package:model_generator/model/item_type/boolean_type.dart';
import 'package:model_generator/model/item_type/date_time_type.dart';
import 'package:model_generator/model/item_type/double_type.dart';
import 'package:model_generator/model/item_type/dynamic_type.dart';
import 'package:model_generator/model/item_type/integer_type.dart';
import 'package:model_generator/model/item_type/item_type.dart';
import 'package:model_generator/model/item_type/object_type.dart';
import 'package:model_generator/model/item_type/string_type.dart';
import 'package:model_generator/model/model/custom_from_to_json_model.dart';
import 'package:model_generator/model/model/custom_model.dart';
import 'package:model_generator/model/model/enum_model.dart';
import 'package:model_generator/model/model/json_converter_model.dart';
import 'package:model_generator/model/model/model.dart';
import 'package:model_generator/model/model/object_model.dart';
import 'package:model_generator/util/type_checker.dart';
import 'package:yaml/yaml.dart';

class YmlGeneratorConfig {
  final _models = <Model>[];

  List<Model> get models => _models;

  YmlGeneratorConfig(PubspecConfig pubspecConfig, String configContent) {
    loadYaml(configContent).forEach((key, value) {
      final String baseDirectory =
          value['base_directory'] ?? pubspecConfig.baseDirectory;
      final String path = value['path'];
      final dynamic properties = value['properties'];
      final YamlList converters = value['converters'];
      final String type = value['type'];
      if (type == 'custom') {
        models.add(
            CustomModel(name: key, path: path, baseDirectory: baseDirectory));
        return;
      } else if (type == 'custom_from_to_json') {
        models.add(CustomFromToJsonModel(
            name: key, path: path, baseDirectory: baseDirectory));
        return;
      } else if (type == 'json_converter') {
        models.add(JsonConverterModel(
            name: key, path: path, baseDirectory: baseDirectory));
        return;
      }
      if (properties == null) {
        throw Exception('Properties can not be null. model: $key');
      }
      if (!(properties is YamlMap)) {
        throw Exception(
            'Properties should be a map, right now you are using a ${properties.runtimeType}. model: $key');
      }
      if (type == 'enum') {
        final fields = <EnumField>[];
        properties.forEach((propertyKey, propertyValue) {
          if (propertyValue != null && !(propertyValue is YamlMap)) {
            throw Exception('$propertyKey should be an object');
          }
          fields.add(EnumField(
            name: propertyKey,
            value: propertyValue == null ? '' : propertyValue['value'],
          ));
        });
        models.add(EnumModel(
          name: key,
          path: path,
          baseDirectory: baseDirectory,
          fields: fields,
        ));
      } else {
        final fields = <Field>[];
        properties.forEach((propertyKey, propertyValue) {
          if (!(propertyValue is YamlMap)) {
            throw Exception('$propertyKey should be an object');
          }
          fields.add(getField(propertyKey, propertyValue));
        });
        final mappedConverters =
            converters?.map((element) => element.toString())?.toList() ??
                <String>[];
        models.add(ObjectModel(
          name: key,
          path: path,
          baseDirectory: baseDirectory,
          fields: fields,
          converters: mappedConverters,
        ));
      }
    });

    checkIfTypesAvailable();
  }

  Field getField(String name, YamlMap property) {
    try {
      final required =
          property.containsKey('required') && property['required'] == true;
      final ignored =
          property.containsKey('ignore') && property['ignore'] == true;
      final nonFinal = ignored ||
          property.containsKey('non_final') && property['non_final'] == true;
      final includeIfNull = property.containsKey('include_if_null') &&
          property['include_if_null'] == true;
      final unknownEnumValue = property['unknown_enum_value'];
      final jsonKey = property['jsonKey'] ?? property['jsonkey'];
      final type = property['type'];
      ItemType itemType;

      if (type == null) {
        throw Exception('$name has no defined type');
      }
      if (type == 'object' || type == 'dynamic' || type == 'any') {
        itemType = DynamicType();
      } else if (type == 'bool' || type == 'boolean') {
        itemType = BooleanType();
      } else if (type == 'string' || type == 'String') {
        itemType = StringType();
      } else if (type == 'date' || type == 'datetime') {
        itemType = DateTimeType();
      } else if (type == 'double') {
        itemType = DoubleType();
      } else if (type == 'int' || type == 'integer') {
        itemType = IntegerType();
      } else if (type == 'array') {
        final items = property['items'];
        final arrayType = items['type'];
        if (arrayType == 'string' || arrayType == 'String') {
          itemType = ArrayType('String');
        } else if (arrayType == 'bool' || arrayType == 'boolean') {
          itemType = ArrayType('bool');
        } else if (arrayType == 'double') {
          itemType = ArrayType('double');
        } else if (arrayType == 'date' || arrayType == 'datetime') {
          itemType = ArrayType('DateTime');
        } else if (arrayType == 'int' || arrayType == 'integer') {
          itemType = ArrayType('int');
        } else if (arrayType == 'object' ||
            arrayType == 'dynamic' ||
            arrayType == 'any') {
          itemType = ArrayType('dynamic');
        } else {
          itemType = ArrayType(arrayType);
        }
      } else {
        itemType = ObjectType(type);
      }
      return Field(
        name: name,
        type: itemType,
        isRequired: required,
        ignore: ignored,
        jsonKey: jsonKey,
        nonFinal: nonFinal,
        includeIfNull: includeIfNull,
        unknownEnumValue: unknownEnumValue,
      );
    } catch (e) {
      print('Something went wrong with $name:\n\n${e.toString()}');
      rethrow;
    }
  }

  String getPathForName(PubspecConfig pubspecConfig, String name) {
    final foundModel =
        models.firstWhere((model) => model.name == name, orElse: () => null);
    if (foundModel == null) {
      throw Exception(
          'getPathForName is null: because `$name` was not added to the config file');
    }
    final baseDirectory =
        foundModel.baseDirectory ?? pubspecConfig.baseDirectory;
    if (foundModel.path == null) {
      return '$baseDirectory';
    } else if (foundModel.path.startsWith('package:')) {
      return foundModel.path;
    } else {
      return '$baseDirectory/${foundModel.path}';
    }
  }

  void checkIfTypesAvailable() {
    final names = <String>{};
    final types = <String>{};
    models.forEach((model) {
      names.add(model.name);
      if (model is ObjectModel) {
        model.fields.forEach((field) {
          types.add(field.type.name);
        });
      }
    });

    print('Registered models:');
    print(names);
    print('=======');
    print('Models used as a field in another model:');
    print(types);
    types.forEach((type) {
      if (!TypeChecker.isKnownDartType(type) && !names.contains(type)) {
        throw Exception(
            'Could not generate all models. `$type` is not added to the config file');
      }
    });
  }

  Model getModelByName(ItemType itemType) {
    if (itemType is! ObjectType) return null;
    final model = _models.firstWhere((element) => element.name == itemType.name,
        orElse: () => null);
    if (model == null) {
      throw Exception(
          'getModelByname is null: because `${itemType.name}` was not added to the config file');
    }
    return model;
  }
}
