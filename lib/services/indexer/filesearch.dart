import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:editor/services/indexer/levenshtein.dart';
import 'package:path/path.dart' as _path;

class FileSearch {
  Future<dynamic> findInFile(String path, String text) async {
    File f = File(path);
    List<dynamic> result = [];
    List<String> lines = [];
    int lineNumber = 0;
    try {
      await f
          .openRead()
          .map(utf8.decode)
          .transform(const LineSplitter())
          .forEach((l) {
        lines.add(l);
        int idx = l.indexOf(text, 0);
        if (idx != -1) {
          result.add({'text': l, 'lineNumber': (lineNumber + 1)});
        }

        lineNumber++;
      });
    } catch (err, msg) {
      //
    }

    if (result.length == 0) return '';

    // for(final r in result) {
    // r['previousLine'] = '';
    // r['nextLine'] = '';
    // int idx = r['lineNumber'] ?? 0;
    // if (idx > 0) {
    // r['previousLine'] = lines[idx-1];
    // }
    // if (idx < lines.length-1) {
    // r['nextLine'] = lines[idx+1];
    // }
    // }

    dynamic res = {};
    res['file'] = path;
    res['search'] = text;
    res['matches'] = result;

    return res;
  }

  Future<List<dynamic>> find(String text) async {
    Directory dir = Directory(_path.normalize('./'));
    Completer<List<dynamic>> completer = Completer<List<dynamic>>();

    List<dynamic> result = [];
    var lister = dir.list(recursive: true);
    lister.listen((file) async {
      String ext = _path.extension(file.path);
      if (ext == '.dart') {
        dynamic res = await findInFile(file.path, text);
        if (res != '') {
          result.add(res);
        }
      }
    }, onError: (err) {
      completer.complete(result);
    }, onDone: () {
      completer.complete(result);
    });

    return completer.future;
  }
}

class FileSearchIsolate {
  FileSearchIsolate() {
    spawnIsolate();
  }

  void dispose() {
    _receivePort?.close();
    _isolate?.kill();
  }

  Function? onResult;
  ReceivePort? _receivePort;
  Isolate? _isolate;
  SendPort? _isolateSendPort;

  Future<List<String>> find(String text) async {
    _isolateSendPort?.send('find::$text');
    return [];
  }

  static void remoteIsolate(SendPort sendPort) {
    FileSearch isolateFileSearch = FileSearch();
    ReceivePort _isolateReceivePort = ReceivePort();
    sendPort.send(_isolateReceivePort.sendPort);
    _isolateReceivePort.listen((message) async {
      if (message.startsWith('find::')) {
        String text = message.substring(6);
        isolateFileSearch.find(text).then((res) {
          sendPort.send(jsonEncode(res));
        });
      }
    });
  }

  Future spawnIsolate() async {
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(remoteIsolate, _receivePort!.sendPort,
        debugName: "remoteIsolate");
    _receivePort?.listen((msg) {
      if (msg is SendPort) {
        _isolateSendPort = msg;
      } else {
        onResult?.call(jsonDecode(msg));
      }
    });
  }
}

class FileSearchProvider extends FileSearchIsolate {}
