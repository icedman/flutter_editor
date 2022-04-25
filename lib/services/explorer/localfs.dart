import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart' as _path;
import 'package:editor/services/explorer/filesystem.dart';

class LocalFs extends ExplorerBackend {
  List<ExplorerListener> listeners = [];
  List<FileSystemEntity> files = [];
  String rootPath = '';

  void addListener(ExplorerListener listener) {
    listeners.add(listener);
  }

  void setRootPath(String path) {
    rootPath = _path.normalize(path);
    loadPath(path, recursive: true);
  }

  void loadPath(String path, {bool recursive = false}) {
    files = <FileSystemEntity>[];
    Directory dir = Directory(path);
    var lister = dir.list(recursive: recursive);
    lister.listen((file) => files.add(file), onError: (err) {
      listeners.forEach((l) {
        l.onError(jsonEncode({'path': path, 'operation': 'load'}));
      });
    }, onDone: () {
      Map<String, dynamic> dirs = {};
      dirs[_path.normalize(dir.absolute.path)] = {
        'path': _path.normalize(dir.absolute.path),
        'isDirectory': true,
        'items': []
      };
      List<dynamic> items = [];
      for (final i in files) {
        String p = _path.normalize(i.path);
        if (i is Directory) {
          dirs[p] = {
            'path': p,
            'isDirectory': true,
            'items': [],
          };
        }

        final d = dirs[_path.dirname(p)] ?? {};
        d['items']?.add({'path': p, 'isDirectory': (i is Directory)});
      }

      int delay = 0;
      listeners.forEach((l) {
        for (final k in dirs.keys) {
          final json = jsonEncode(dirs[k]);
          Future.delayed(Duration(milliseconds: 50 * delay++), () {
            l.onLoad(json);
          });
        }
      });
    });
  }

  void openFile(String path) {}

  void createDirectory(String path) {
    final d = Directory(path);
    d.create().then((res) {
      final json = jsonEncode({'path': _path.normalize(path)});
      listeners.forEach((l) {
        l.onDelete(json);
      });
    }).catchError((err) {
      listeners.forEach((l) {
        l.onError(jsonEncode({'path': path, 'operation': 'create'}));
      });
    });
  }

  void createFile(String path) {}

  void deleteDirectory(String path, {bool recursive = false}) {
    final d = Directory(path);
    d.delete(recursive: true).then((res) {
      final json = jsonEncode({'path': _path.normalize(path)});
      listeners.forEach((l) {
        l.onDelete(json);
      });
    }).catchError((err) {
      listeners.forEach((l) {
        l.onError(jsonEncode({'path': path, 'operation': 'delete'}));
      });
    });
  }

  void deleteFile(String path) {
    final f = File(path);
    f.delete().then((res) {
      final json = jsonEncode({'path': _path.normalize(path)});
      listeners.forEach((l) {
        l.onDelete(json);
      });
    }).catchError((err) {
      listeners.forEach((l) {
        l.onError(jsonEncode({'path': path, 'operation': 'delete'}));
      });
    });
  }

  void renameDirectory(String path, String newPath) {
    final d = Directory(path);
    d.rename(newPath).then((res) {
      final json = jsonEncode({'path': _path.normalize(path)});
      listeners.forEach((l) {
        l.onDelete(json);
      });
    }).catchError((err) {
      listeners.forEach((l) {
        l.onError(jsonEncode({'path': path, 'operation': 'rename'}));
      });
    });
  }

  void renameFile(String path, String newPath) {
    final f = File(path);
    f.rename(newPath).then((res) {
      final json = jsonEncode({'path': _path.normalize(path)});
      listeners.forEach((l) {
        l.onDelete(json);
      });
    }).catchError((err) {
      listeners.forEach((l) {
        l.onError(jsonEncode({'path': path, 'operation': 'rename'}));
      });
    });
  }

  void search(String fileName) {}
}
