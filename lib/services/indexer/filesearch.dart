import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:editor/services/indexer/levenshtein.dart';
import 'package:path/path.dart' as _path;

class FileSearch {
  Future<dynamic> findInFile(String text,
      {String path = '',
      bool caseSensitive = false,
      bool regex = false}) async {
    File f = File(path);
    List<dynamic> result = [];
    List<String> lines = [];
    int lineNumber = 0;

    if (!caseSensitive && !regex) {
      text = text.toLowerCase();
    }

    RegExp _wordRegExp = RegExp(
      text,
      caseSensitive: caseSensitive,
      multiLine: false,
    );

    try {
      await f
          .openRead()
          .map(utf8.decode)
          .transform(const LineSplitter())
          .forEach((line) {
        lines.add(line);
        String source = line;
        if (!caseSensitive && !regex) {
          source = source.toLowerCase();
        }
        int l = text.length;

        int idx = -1;
        if (regex) {
          final matches = _wordRegExp.allMatches(source);
          for (final m in matches) {
            var g = m.groups([0]);
            l = m.end - m.start;
            idx = m.start;
            break;
          }
        } else {
          idx = source.indexOf(text);
        }

        if (idx != -1) {
          result.add({'text': line, 'lineNumber': (lineNumber + 1)});
        }

        lineNumber++;
      });
    } catch (err, msg) {
      //
    }

    if (result.length == 0) return '';

    dynamic res = {};
    res['file'] = path;
    res['search'] = text;
    res['regex'] = regex;
    res['caseSensitive'] = caseSensitive;
    res['matches'] = result;
    return res;
  }

  Future<List<dynamic>> find(String text,
      {String path = '',
      bool caseSensitive = false,
      bool regex = false}) async {
    Directory dir = Directory(_path.normalize('./'));
    Completer<List<dynamic>> completer = Completer<List<dynamic>>();

    RegExp _wordRegExp = RegExp(
      text,
      caseSensitive: caseSensitive,
      multiLine: false,
    );

    List<dynamic> result = [];
    var lister = dir.list(recursive: true);
    lister.listen((file) async {
      String ext = _path.extension(file.path);
      if (ext == '.dart') {
        dynamic res = await findInFile(text,
            path: file.path, caseSensitive: caseSensitive, regex: regex);
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

  Future<List<String>> find(String text,
      {String path = '',
      bool caseSensitive = false,
      bool regex = false}) async {
    dynamic args = {
      'text': text,
      'path': path,
      'caseSensitive': caseSensitive,
      'regex': regex
    };
    _isolateSendPort?.send('find::${jsonEncode(args)}');
    return [];
  }

  static void remoteIsolate(SendPort sendPort) {
    FileSearch isolateFileSearch = FileSearch();
    ReceivePort _isolateReceivePort = ReceivePort();
    sendPort.send(_isolateReceivePort.sendPort);
    _isolateReceivePort.listen((message) async {
      if (message.startsWith('find::')) {
        dynamic json = jsonDecode(message.substring(6));
        String text = json['text'] ?? '';
        String path = json['path'] ?? '';
        bool caseSensitive = json['caseSensitive'] == true;
        bool regex = json['regex'] == true;
        isolateFileSearch
            .find(text, path: path, caseSensitive: caseSensitive, regex: regex)
            .then((res) {
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
