import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:editor/services/indexer/levenshtein.dart';

class FileSearch {

  void find(String text, {List<String>? result}) {
    Directory dir = Directory('./');
    var lister = dir.list(recursive: true);
        lister.listen((file) {
        }, onError: (err) {
    }, onDone: () {
        //
    });
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
        isolateFileSearch.find(text);
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

class FileSearchProvider extends FileSearchIsolate 
{}

