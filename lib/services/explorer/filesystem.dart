import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:path/path.dart' as _path;

List<String> folderExclude = [];
List<String> fileExclude = [];

class ExplorerItem {
  ExplorerItem(String this.fullPath) {
    fileName = _path.basename(fullPath);
  }

  String fileName = '';
  String fullPath = '';
  String tempPath = '';
  String iconPath = '';

  int depth = 0;
  bool isDirectory = false;
  bool isBinary = false;
  bool isExpanded = false;

  double height = 0;
  int duration = 0;

  ExplorerItem? parent;
  List<ExplorerItem?> children = [];
  dynamic data;

  void buildTree(List<ExplorerItem?> items) {
    if (isDirectory) {
      for (final ex in folderExclude) {
        if (fullPath.indexOf(ex) != -1) return;
      }
    } else {
      String ext = _path.extension(fullPath).toLowerCase();
      for (final ex in fileExclude) {
        if (ext == ex) return;
      }
    }

    items.add(this);
    if (!isExpanded) return;
    for (final c in children) {
      c?.buildTree(items);
    }
  }

  void files(List<ExplorerItem?> items) {
    if (!isDirectory) {
      items.add(this);
    }
    for (final c in children) {
      c?.files(items);
    }
  }

  void dump() {
    String pad = List.generate(depth, (_) => '--').join();
    print(' $pad $fullPath');
    for (final c in children) {
      c?.dump();
    }
  }

  ExplorerItem? itemFromPath(String path, {bool deep = true}) {
    if (path == fullPath) return this;
    for (final c in children) {
      if (path == c?.fullPath) return c;
      if (!deep) continue;
      ExplorerItem? ci = c?.itemFromPath(path);
      if (ci != null) {
        return ci;
      }
    }
    return null;
  }

  void setData(dynamic items) {
    if (items['items'] == null) return;
    for (final item in items['items']) {
      String path = item['path'] ?? '';
      if (path == '') continue;
      if (path.startsWith('.')) {
        path = _path.join(fullPath, path);
      }
      String base = _path.basename(path);
      if (base.startsWith('.')) continue; // skip
      String dir = _path.dirname(path);
      if (dir == fullPath && path != fullPath) {
        ExplorerItem? ci = itemFromPath(path, deep: false);
        if (ci == null) {
          ci = ExplorerItem(path);
          ci.depth = depth + 1;
          ci.isDirectory = item['isDirectory'];
          ci.parent = this;
          children.add(ci);
        }
      }
    }

    children.sort((a, b) {
      if (a == null || b == null) return 0;
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.fileName.compareTo(b.fileName);
    });
  }

  @override
  String toString() {
    String pad = List.generate(depth, (_) => '   ').join();
    return '$pad${isDirectory ? (isExpanded ? '-' : '+') : ' '} $fileName';
  }
}

class Explorer implements ExplorerListener {
  ExplorerBackend? backend;
  ExplorerItem? root;

  Map<String, Completer> requests = {};

  void _busy() {
    //...setRootPath
  }

  void setBackend(ExplorerBackend? back) {
    backend = back;
    backend?.addListener(this);
  }

  Future<bool> setRootPath(String path) {
    String p = _path.normalize(Directory(path).absolute.path);
    root = ExplorerItem(p);
    return loadPath(p, recursive: true);
  }

  Future<bool> loadPath(String path, {bool recursive: false}) {
    String p = _path.normalize(Directory(path).absolute.path);
    if (isLoading(p)) {
      _busy();
      return Future.value(false);
    }
    backend?.loadPath(path, recursive: recursive);

    Completer<bool> completer = Completer<bool>();
    requests[p] = completer;
    return completer.future;
  }

  ExplorerItem? itemFromPath(String path) {
    String p = _path.normalize(Directory(path).absolute.path);
    return root?.itemFromPath(p);
  }

  Future<bool> deleteDirectory(String path, {bool recursive: false}) {
    String p = _path.normalize(Directory(path).absolute.path);
    if (isLoading(p)) {
      _busy();
      return Future.value(false);
    }
    backend?.deleteDirectory(p, recursive: recursive);
    Completer<bool> completer = Completer<bool>();
    requests[p] = completer;
    return completer.future;
  }

  Future<bool> deleteFile(String path) {
    String p = _path.normalize(Directory(path).absolute.path);
    if (isLoading(p)) {
      _busy();
      return Future.value(false);
    }
    backend?.deleteFile(p);
    Completer<bool> completer = Completer<bool>();
    requests[p] = completer;
    return completer.future;
  }

  Future<bool> renameDirectory(String path, String newPath) {
    String p = _path.normalize(Directory(path).absolute.path);
    String np = _path.normalize(Directory(newPath).absolute.path);
    if (isLoading(p)) {
      _busy();
      return Future.value(false);
    }
    backend?.renameDirectory(p, np);
    Completer<bool> completer = Completer<bool>();
    requests[p] = completer;
    return completer.future;
  }

  Future<bool> renameFile(String path, String newPath) {
    String p = _path.normalize(Directory(path).absolute.path);
    String np = _path.normalize(Directory(newPath).absolute.path);
    if (isLoading(p)) {
      _busy();
      return Future.value(false);
    }
    backend?.renameFile(p, np);
    Completer<bool> completer = Completer<bool>();
    requests[p] = completer;
    return completer.future;
  }

  bool isLoading(String path) {
    String p = _path.normalize(Directory(path).absolute.path);
    return requests.containsKey(p);
  }

  void dump() {
    root?.dump();
  }

  List<ExplorerItem?> tree() {
    List<ExplorerItem?> _tree = [];
    root?.buildTree(_tree);
    return _tree;
  }

  List<ExplorerItem?> files() {
    List<ExplorerItem?> _files = [];
    root?.files(_files);
    return _files;
  }

  // event
  void onLoad(dynamic items) {
    dynamic json = jsonDecode(items);
    String p = _path.normalize(Directory(json['path']).absolute.path);
    ExplorerItem? item = itemFromPath(p);
    item?.setData(json);
    item?.isDirectory = true;
    if (requests.containsKey(p)) {
      requests[p]?.complete(true);
      requests.remove(p);
    }
  }

  void onDelete(dynamic item) {
    dynamic json = jsonDecode(item);
    String p = _path.normalize(Directory(json['path']).absolute.path);

    ExplorerItem? _item = itemFromPath(p);
    _item?.parent?.children.removeWhere((i) => i == item);

    if (requests.containsKey(p)) {
      requests[p]?.complete(true);
      requests.remove(p);
    }
  }

  void onError(dynamic error) {}

  void search(String fileName) {}

  void setExcludePatterns(
      dynamic _folderExclude, dynamic _fileExclude, dynamic binaryExclude) {
    for (String s in _folderExclude) {
      folderExclude.add(s);
    }
    for (String s in [...binaryExclude, ..._fileExclude]) {
      if (s.indexOf('*.') != -1) {
        s = s.substring(1);
      }
      fileExclude.add(s);
    }
  }
}

abstract class ExplorerListener {
  void onLoad(dynamic items);
  void onDelete(dynamic item);
  void onError(dynamic error);
}

// isolate?
abstract class ExplorerBackend {
  void addListener(ExplorerListener listener);
  void setRootPath(String path);
  void loadPath(String path, {bool recursive = false});
  void openFile(String path);
  void createDirectory(String path);
  void createFile(String path);
  void deleteDirectory(String path, {bool recursive = false});
  void deleteFile(String path);
  void renameDirectory(String path, String newPath);
  void renameFile(String path, String newPath);
  void search(String fileName);
}
