import 'dart:io';

import 'package:path/path.dart';

import 'src/config/pubspec_config.dart';
import 'src/config/yml_generator_config.dart';
import 'src/data_model_writer.dart';

Future<void> main(List<String> args) async {
  final pubspecYaml = File(join(Directory.current.path, 'pubspec.yaml'));
  if (!pubspecYaml.existsSync()) {
    throw Exception(
        'This program should be run from the root of a flutter/dart project');
  }
  final pubspecContent = pubspecYaml.readAsStringSync();
  final pubspecConfig = PubspecConfig(pubspecContent);

  final swagerGeneratorConfigFile =
      File(join(Directory.current.path, 'model_generator', 'config.yaml'));
  if (!swagerGeneratorConfigFile.existsSync()) {
    throw Exception(
        'This program requires a config file. `model_generator/config.yaml`');
  }
  final modelGeneratorContent = swagerGeneratorConfigFile.readAsStringSync();
  final modelGeneratorConfig = YmlGeneratorConfig(modelGeneratorContent);

  writeToFiles(pubspecConfig, modelGeneratorConfig);
  await generateJsonGeneratedModels();
  print('Done!!!');
}

void writeToFiles(
    PubspecConfig pubspecConfig, YmlGeneratorConfig modelGeneratorConfig) {
  final modelDirectory = Directory(join('lib', 'model'));
  if (!modelDirectory.existsSync()) {
    modelDirectory.createSync(recursive: true);
  }
  modelGeneratorConfig.models.forEach((model) {
    final content = DataModelWriter(pubspecConfig.projectName, model).write();
    File file;
    if (model.path == null) {
      file = File(join('lib', 'model', '${model.fileName}.dart'));
    } else {
      file = File(join('lib', 'model', model.path, '${model.fileName}.dart'));
    }
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    file.writeAsStringSync(content);

    File generatedFile;
    if (model.path == null) {
      generatedFile = File(join('lib', 'model', '${model.fileName}.g.dart'));
    } else {
      generatedFile =
          File(join('lib', 'model', model.path, '${model.fileName}.g.dart'));
    }
    generatedFile.writeAsStringSync("part of '${model.fileName}.dart';");
  });
}

/// run `flutter packages pub run build_runner build --delete-conflicting-outputs`
Future<void> generateJsonGeneratedModels() async {
  final result = Process.runSync('flutter', [
    'packages',
    'pub',
    'run',
    'build_runner',
    'build',
    '--delete-conflicting-outputs',
  ]);
  if (result.exitCode == 0) {
    print('Succesfully generated the jsonSerializable generated files');
    print('');
  } else {
    print(
        'Failed to run `flutter packages pub run build_runner build --delete-conflicting-outputs`');
  }
}
