import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart' as _path;
import 'package:editor/services/explorer/filesystem.dart';

class LocalFs extends ExplorerBackend {
  List<ExplorerListener> listeners = [];
  String rootPath = '';

  void addListener(ExplorerListener listener) {
    listeners.add(listener);
  }

  void setRootPath(String path) {
    rootPath = _path.normalize(path);
  }

  void loadPath(String path) {
    var files = <FileSystemEntity>[];
    Directory dir = Directory(path);
    var lister = dir.list(recursive: false);
    lister.listen((file) => files.add(file), onError: (err) {
      // fail silently?
      }, onDone: () {
      List<dynamic> items = [];
      for (final i in files) {
        items.add({'path': i.path, 'isDirectory': (i is Directory)});
      }
      final json = jsonEncode(
          {'path': _path.normalize(dir.absolute.path), 'items': items});
      listeners.forEach((l) {
        l.onLoad(json);
      });
    });
  }

  void openFile(String path) {}

  void createDirectory(String path) {}

  void createFile(String path) {}

  void deleteDirectory(String path, {bool recursive: false}) {}

  void deleteFile(String path) {}

  void rename(String path) {}

}
