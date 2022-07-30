import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart' as _path;
import 'package:editor/services/explorer/filesystem.dart';
import 'package:editor/services/ffi/bridge.dart';

class SFtpFs extends ExplorerBackend {
  List<ExplorerListener> listeners = [];
  List<FileSystemEntity> files = [];
  String rootPath = '';

    String url = 'iceman@127.0.0.1';
    String password = '';

  void addListener(ExplorerListener listener) {
    listeners.add(listener);
  }

  void setRootPath(String path) {
    rootPath = _path.normalize(path);
  }

  int _depth(String path) {
    String ll = path.replaceAll('/', '');
    ll = ll.replaceAll('\\', '');
    return (path.length - ll.length);
  }

  void _loadPath(String path, {bool recursive: false}) {
    files = <FileSystemEntity>[];
    Directory dir = Directory(path);
    int depthRoot = _depth(dir.absolute.path);

    final _sendTheFiles = () {
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

      files.clear();

      listeners.forEach((l) {
        for (final k in dirs.keys) {
          final json = jsonEncode(dirs[k]);
          Future.delayed(Duration(milliseconds: 0), () {
            l.onLoad(json);
          });
        }
      });
    };

  FFIMessaging.instance().sendMessage({
     'channel': 'sftp',
     'message': {
        'command': 'dir',
        'basePath': url,
        'passphrase': password,
        'path': path,
        'cmd': 'dir'
     }
  }).then((res) {
    // print(res);
    for(final entry in res['message']) {
        List<String> ss = entry.split(';');
        if (ss.length < 2) continue;
        if (ss[0] == 'dir') {
            Directory f = Directory(ss[1]);
            files.add(f);
        } else {
            File f = File(ss[1]);
            files.add(f);
        }
        // print(entry);
    }
    _sendTheFiles();
    });


    // lister.listen((file) {
    //   files.add(file);
    // }, onError: (err) {
    //   listeners.forEach((l) {
    //     l.onError(jsonEncode({'path': path, 'operation': 'load'}));
    //   });
    // }, onDone: () {
    //   _sendTheFiles();
    // });
  }

  void loadPath(String path) {
    _loadPath(path);
  }

  // void preload() {
  //   _loadPath(rootPath, recursive: true);
  // }

  void openFile(String path) {}

  void createDirectory(String path) {
    
  }

  void createFile(String path) {}

  void deleteDirectory(String path, {bool recursive = false}) {
    
  }

  void deleteFile(String path) {
    
  }

  void renameDirectory(String path, String newPath) {
    
  }

  void renameFile(String path, String newPath) {
    
  }

  void search(String fileName) {}
}

