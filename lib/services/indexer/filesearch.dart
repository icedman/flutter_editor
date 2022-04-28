import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:editor/services/indexer/levenshtein.dart';
import 'package:path/path.dart' as _path;

const int MAX_FILES_SEARCHED_COUNT = 2000;
const int MAX_SEARCH_RESULT_LENGTH = 1000;
const int MAX_TEXT_SEARCH_LENGTH = 300;

class FileSearch {
  List<String> folderExclude = [];
  List<String> fileExclude = [];

  Future<dynamic> findInFile(String text,
      {String path = '',
      bool caseSensitive = false,
      bool regex = false}) async {
    // print(path);

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
        // lines.add(line);
        String source = line;
        if (!caseSensitive && !regex) {
          source = source.toLowerCase();
        }
        int l = text.length;
        if (line.length > MAX_TEXT_SEARCH_LENGTH) return;

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
          String pre = '';
          String post = '';
          int s = idx - 20;
          int e = idx + 40;
          if (s < 0) {
            s = 0;
          } else {
            pre = '... ';
          }
          if (e > line.length - 1) {
            e = line.length - 1;
          } else {
            post = ' ...';
          }

          String substr = line.substring(s, e);
          result.add({
            'text': '${pre}${substr}${post}',
            'lineNumber': (lineNumber + 1)
          });
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

  Future<dynamic> find(String text,
      {String path = './',
      bool caseSensitive = false,
      bool regex = false,
      Function? onResult}) async {
    Directory dir = Directory(_path.normalize(path));

    // print('>>${dir.absolute.path}');

    Completer<dynamic> completer = Completer<dynamic>();

    var lister = dir.list(recursive: true);

    int fileSearched = 0;
    lister.listen((file) async {
      String folder = _path.dirname(_path.normalize(file.path));
      for (final ex in folderExclude) {
        if (folder.indexOf(ex) != -1) {
          // print('exclude folder $folder');
          return;
        }
      }

      String ext = _path.extension(file.path).toLowerCase();
      for (final ex in fileExclude) {
        if (ext == ex) {
          // print('exclude file $baseName');
          return;
        }
      }

      if (fileSearched++ > MAX_FILES_SEARCHED_COUNT) {
        return;
      }

      if (!(file is Directory)) {
        dynamic res = await findInFile(text,
            path: file.path, caseSensitive: caseSensitive, regex: regex);
        if (res != '') {
          onResult?.call([res]);
        }
      }
    }, onError: (err) {
      Future.delayed(const Duration(milliseconds: 500), () {
        completer.complete({});
      });
    }, onDone: () {
      Future.delayed(const Duration(milliseconds: 500), () {
        completer.complete({});
      });
    });

    return completer.future;
  }

  Future<dynamic> findFiles(String text,
      {String path = './',
      bool caseSensitive = false,
      bool regex = false,
      Function? onResult}) async {
    Directory dir = Directory(_path.normalize(path));

    // print('>>${dir.absolute.path}');

    Completer<dynamic> completer = Completer<dynamic>();

    List<dynamic> result = [];
    var lister = dir.list(recursive: true);
    int fileSearched = 0;
    lister.listen((file) async {
      String folder = _path.dirname(_path.normalize(file.path));
      for (final ex in folderExclude) {
        if (folder.indexOf(ex) != -1) {
          // print('exclude folder $folder');
          return;
        }
      }

      String ext = _path.extension(file.path).toLowerCase();
      for (final ex in fileExclude) {
        if (ext == ex) {
          // print('exclude file $baseName');
          return;
        }
      }

      if (fileSearched++ > MAX_FILES_SEARCHED_COUNT) {
        return;
      }

      if (!(file is Directory)) {
        dynamic res = await findInFile(text,
            path: file.path, caseSensitive: caseSensitive, regex: regex);
        if (res != '' && result.length < MAX_SEARCH_RESULT_LENGTH) {
          // result.add(res);
          onResult?.call([res]);
        }
      }
    }, onError: (err) {
      Future.delayed(const Duration(milliseconds: 500), () {
        completer.complete({});
      });
    }, onDone: () {
      Future.delayed(const Duration(milliseconds: 500), () {
        completer.complete({});
      });
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
  Function? onDone;
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

  void setExcludePatterns(
      dynamic folderExclude, dynamic fileExclude, dynamic binaryExclude) {
    _isolateSendPort?.send('exclude::folder::${jsonEncode(folderExclude)}');
    _isolateSendPort?.send('exclude::file::${jsonEncode(fileExclude)}');
    _isolateSendPort?.send('exclude::binary::${jsonEncode(binaryExclude)}');
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
        isolateFileSearch.find(text,
            path: path,
            caseSensitive: caseSensitive,
            regex: regex, onResult: (res) {
          sendPort.send(jsonEncode(res));
        }).then((res) {
          // done or fail
        });
        return;
      }

      // if (message.startsWith('file::')) {
      // dynamic json = jsonDecode(message.substring(6));
      // String text = json['text'] ?? '';
      // String path = json['path'] ?? '';
      // bool caseSensitive = json['caseSensitive'] == true;
      // bool regex = json['regex'] == true;
      // isolateFileSearch
      // .find(text, path: path, caseSensitive: caseSensitive, regex: regex)
      // .then((res) {
      // sendPort.send(jsonEncode(res));
      // });
      // }

      if (message.startsWith('exclude::')) {
        String exclude = message.substring(9);
        int idx = exclude.indexOf('::');
        dynamic json = jsonDecode(exclude.substring(idx + 2)) ?? [];
        for (String s in json) {
          if (exclude.startsWith('folder::')) {
            isolateFileSearch.folderExclude.add(s);
          } else {
            if (s.indexOf('*.') != -1) {
              s = s.substring(1);
            }
            isolateFileSearch.fileExclude.add(s);
          }
        }
        return;
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
