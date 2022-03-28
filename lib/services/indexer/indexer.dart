import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

RegExp _wordRegExp = new RegExp(
  r'[a-z_0-9]*',
  caseSensitive: false,
  multiLine: false,
);

int _nodeId = 0;

class IndexNode {
  IndexNode({String this.text = '', int this.level = 0}) {
    id = _nodeId++;
  }

  int id = 0;
  int level = 0;
  String text = '';
  bool word = false;

  Map<String, IndexNode> nodes = {};

  IndexNode? push(String text) {
    if (text.length < level) {
      return null;
    }
    String prefix = text.substring(0, level);
    String _prefix = prefix.toLowerCase();
    if (!nodes.containsKey(_prefix)) {
      nodes[_prefix] = IndexNode(text: prefix, level: level + 1);
    }
    if (prefix != text) {
      nodes[_prefix]?.push(text);
    } else {
      nodes[_prefix]?.word = true;
    }

    return nodes[_prefix];
  }

  void dump({String pad = ''}) {
    print('-$pad ${word ? text : '.'}');
    pad += '  ';
    for (final t in nodes.keys) {
      print('>$level $pad $t');
      nodes[t]?.dump(pad: pad);
    }
  }

  void collect({List<String>? result}) {
    if (word && result != null) {
      result.add(text);
    }
    for (final t in nodes.keys) {
      nodes[t]?.collect(result: result);
    }
  }

  void find(String text, {List<String>? result}) {
    if (text.length < level) {
      return;
    }
    String prefix = text.substring(0, level);
    String _prefix = prefix.toLowerCase();
    if (nodes.containsKey(_prefix)) {
      if (prefix == text) {
        nodes[_prefix]?.collect(result: result);
        return;
      }
      nodes[_prefix]?.find(text, result: result);
    }
  }
}

class Indexer {
  IndexNode root = IndexNode(text: '', level: 0);

  Future<void> indexWords(String text) async {
    final words = _wordRegExp.allMatches(text);
    for (final m in words) {
      var g = m.groups([0]);
      var t = g[0] ?? '';
      root.push(t);
    }
  }

  Future<List<String>> find(String text) async {
    List<String> result = [];
    root.find(text, result: result);
    print(result);
    return result;
  }

  Future<void> file(String path) async {
    File f = File(path);
    try {
      await f
          .openRead()
          .map(utf8.decode)
          .transform(const LineSplitter())
          .forEach((l) {
        indexWords(l);
      });
    } catch (err, msg) {
      //
    }
  }

  void dump() {
    print('dump');
    root.dump();
  }
}

class IndexerIsolate {
  IndexerIsolate() {
    spawnIsolate();
  }

  ReceivePort? _receivePort;
  Isolate? _isolate;
  SendPort? _isolateSendPort;

  Future<void> indexWords(String text) async {
    _isolateSendPort?.send('index::$text');
  }

  Future<List<String>> find(String text) async {
    _isolateSendPort?.send('find::$text');
    return [];
  }

  Future<void> indexFile(String path) async {
    _isolateSendPort?.send('file::$path');
  }

  void dump() {}

  static void remoteIsolate(SendPort sendPort) {
    Indexer isolateIndexer = Indexer();
    ReceivePort _isolateReceivePort = ReceivePort();
    sendPort.send(_isolateReceivePort.sendPort);
    _isolateReceivePort.listen((message) {
      if (message.startsWith('index::')) {
        String text = message.substring(7);
        isolateIndexer.indexWords(text);
      } else if (message.startsWith('find::')) {
        String text = message.substring(6);
        isolateIndexer.find(text);
      } else if (message.startsWith('file::')) {
        String path = message.substring(6);
        isolateIndexer.file(path);
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
      } else {}
    });
  }
}
