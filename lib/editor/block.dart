import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'dart:convert';

import 'package:editor/editor/cursor.dart';
import 'package:editor/editor/history.dart';
import 'package:editor/editor/document.dart';

int _blockId = 0xffff;

class BlockInfoCache {
  String blameAuthor = '';
  String blameSha = '';
  bool added = false;
  bool modified = false;
}

class FileInfoCache {
  String path = '';
  Map<int, BlockInfoCache> blocks = <int, BlockInfoCache>{};

  List<int> gitDiffLineTracker = <int>[];
  List<int> gitDiffEditLinesTracker = <int>[];
  int idx = 0;
  int idxOffset = 0;

  List<int> editedLines = <int>[];
}

class Notifier {
  void init() {}
  void dispose() {}
  void notify({bool now = true}) {}
  dynamic listenable() {
    return null;
  }
}

class LineDecoration {
  int start = 0;
  int end = 0;
  Color color = const Color(0xffffffff);
  Color background = const Color(0xffffffff);
  bool underline = false;
  bool italic = false;
  bool bracket = false;
  bool open = false;
  bool tab = false;
  String link = '';

  Object toObject() {
    return {
      'start': start,
      'end': end,
      'color': [color.red, color.green, color.blue]
    };
  }

  void fromObject(json) {
    start = json['start'] ?? 0;
    end = json['end'] ?? 0;
    final clr = json['color'] ?? [0, 0, 0];
    color = Color.fromRGBO(clr[0], clr[1], clr[2], 1);
  }
}

class LineDecorator {
  List<LineDecoration> run(Block? block) {
    return [];
  }
}

class BlockCaret {
  BlockCaret({int this.position = 0, Color this.color = const Color(0xffffff)});
  int position = 0;
  Color color = const Color(0xffffff);
}

class BlockBracket {
  BlockBracket(
      {Block? this.block,
      int this.position = 0,
      String this.bracket = '',
      bool this.open = true});
  int position = 0;
  Block? block;
  String bracket = '';
  bool open = true;
  String toString() {
    return '$position: $bracket';
  }
}

class Block {
  Block(String this._text, {int this.line = 0, Document? this.document}) {
    blockId = _blockId++;
    notifier = createNotifier?.call();
  }

  static Block get empty => Block('');
  static Function? createNotifier = () {
    return Notifier();
  };

  String get text => _text;
  void set text(String t) => _text = t;

  String _text = '';

  int blockId = 0;
  int line = 0;
  Document? document;
  Block? previous;
  Block? next;

  String diff = '';
  int originalLine = -1;
  int originalLineLength = -1;
  // String? originalText;
  Iterable<RegExpMatch> words = [];

  List<LineDecoration>? decors = [];
  dynamic spans;
  List<BlockCaret> carets = [];
  List<BlockBracket> brackets = [];
  Map<int, int> scopes = {};

  String className = '';
  String prevBlockClass = '';

  late Notifier notifier;

  void dispose() {
    notifier.dispose();
  }

  void notify({bool now = false}) {
    notifier.init();
    notifier.notify(now: now);
  }

  void makeDirty({bool highlight = false, bool notify = true}) {
    spans = null;
    carets = [];

    if (notify) {
      notifier.init();
    }

    if (highlight) {
      prevBlockClass = '';
      decors = null;
      brackets = [];
      notifier.notify(now: false);
      return;
    }

    // notify immediately
    if (notify) {
      notifier.notify(now: true);
    }
  }

  bool get isFolded {
    for (final f in document?.folds ?? []) {
      if (f.anchorBlock == this) {
        return true;
      }
    }
    return false;
  }

  bool get isHidden {
    for (final f in document?.folds ?? []) {
      int s = f.anchorBlock?.line ?? 0;
      int e = f.block?.line ?? 0;
      if (line > s && line < e) return true;
    }
    return false;
  }
}
