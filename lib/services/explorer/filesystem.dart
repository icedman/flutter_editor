import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:path/path.dart' as _path;

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

  ExplorerItem? parent;
  List<ExplorerItem?> children = [];
  dynamic data;

  void buildTree(List<ExplorerItem?> items) {
    items.add(this);
    if (!isExpanded) return;

    for (final c in children) {
      c?.buildTree(items);
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

  void setBackend(ExplorerBackend? back) {
    backend = back;
    backend?.addListener(this);
  }

  Future<bool> setRootPath(String path) {
    String p = _path.normalize(Directory(path).absolute.path);
    root = ExplorerItem(p);
    return loadPath(p);
  }

  Future<bool> loadPath(String path) {
    String p = _path.normalize(Directory(path).absolute.path);
    if (isLoading(p)) {
      print('is loading');
      return Future.value(false);
    }
    backend?.loadPath(path);

    Completer<bool> completer = Completer<bool>();
    requests[p] = completer;
    return completer.future;
  }

  ExplorerItem? itemFromPath(String path) {
    String p = _path.normalize(Directory(path).absolute.path);
    return root?.itemFromPath(p);
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
}

abstract class ExplorerListener {
  void onLoad(dynamic items);
}

// isolate?
abstract class ExplorerBackend {
  void addListener(ExplorerListener listener);
  void setRootPath(String path);
  void loadPath(String path);
  void openFile(String path);
  void createDirectory(String path);
  void createFile(String path);
  void deleteDirectory(String path, {bool recursive: false});
  void deleteFile(String path);
  void rename(String path);
}
