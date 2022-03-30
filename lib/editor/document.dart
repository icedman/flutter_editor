import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:highlight/src/mode.dart';

import 'package:editor/editor/cursor.dart';
import 'package:editor/editor/history.dart';
import 'package:editor/ffi/bridge.dart';
import 'package:editor/services/indexer/indexer.dart';
import 'package:editor/services/highlight/highlighter.dart';

int _documentId = 0xffff;
int _blockId = 0xffff;

class BlockCaret {
  BlockCaret({int this.position = 0, Color this.color = Colors.white});
  int position = 0;
  Color color = Colors.white;
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
  Block(String this.text, {int this.line = 0, Document? this.document}) {
    blockId = _blockId++;
  }

  int blockId = 0;
  int line = 0;
  String text = '';
  Document? document;
  Block? previous;
  Block? next;

  int originalLine = 0;
  String originalText = '';
  Iterable<RegExpMatch> words = [];

  bool waiting = false;

  List<LineDecoration>? decors = [];
  List<InlineSpan>? spans;
  List<BlockCaret> carets = [];
  List<BlockBracket> brackets = [];
  Map<int, int> scopes = {};

  Mode? mode;
  String className = '';
  String prevBlockClass = '';

  void makeDirty({bool highlight = false}) {
    mode = null;
    spans = null;
    carets = [];
    if (highlight) {
      prevBlockClass = '';
      decors = null;
      brackets = [];
    }
  }

  bool isFolded() {
    for (final f in document?.folds ?? []) {
      if (f.anchorBlock == this) {
        return true;
      }
    }
    return false;
  }

  bool isHidden() {
    for (final f in document?.folds ?? []) {
      int s = f.anchorBlock?.line ?? 0;
      int e = f.block?.line ?? 0;
      if (line > s && line < e) return true;
    }
    return false;
  }
}

class Document {
  String docPath = '';
  int documentId = 0;
  int langId = 0;

  List<Block> blocks = [];
  List<Cursor> cursors = [];

  List<Cursor> folds = [];
  List<Cursor> extraCursors = [];
  List<Cursor> sectionCursors = [];
  Map<String, List<Function?>> listeners = {};

  String tabString = '    ';
  int detectedTabSpaces = 0;

  History history = History();
  IndexerIsolate indexer = IndexerIsolate();

  List<Block> indexingQueue = [];

  Document() {
    documentId = _documentId++;

    listeners['onCreate']?.forEach((l) {
      l?.call(documentId);
    });

    clear();
  }

  void dispose() {
    listeners['onDestroy']?.forEach((l) {
      l?.call(documentId);
    });

    indexer.dispose();
  }

  void addListener(String event, Function? func) {
    listeners[event] = listeners[event] ?? [];
    listeners[event]?.add(func);
  }

  Cursor cursor() {
    if (cursors.isEmpty) {
      cursors.add(Cursor(document: this, block: firstBlock()));
    }
    return cursors[0];
  }

  List<Cursor> cursorsSorted({bool inverse: false}) {
    List<Cursor> curs = [...cursors];
    curs.sort((a, b) {
      int aLine = a.block?.line ?? 0;
      int bLine = b.block?.line ?? 0;
      return ((aLine > bLine || (aLine == bLine && a.column > b.column))
              ? 1
              : -1) *
          (inverse ? -1 : 1);
    });
    return curs;
  }

  List<Cursor> cursorsUniqued() {
    List<Cursor> _cursors = [];
    cursors.forEach((c) {
      bool skip = false;
      for (final _c in _cursors) {
        if (c != _c && _c.block == c.block && _c.column == c.column) {
          skip = true;
          break;
        }
      }
      if (!skip) {
        _cursors.add(c);
      }
    });
    return _cursors;
  }

  static int countIndentSize(String s) {
    for (int i = 0; i < s.length; i++) {
      if (s[i] != ' ') {
        return i;
      }
    }
    return 0;
  }

  Future<bool> openFile(String path) async {
    clear();
    docPath = path;
    detectedTabSpaces = 0;

    blocks = [];
    File f = File(docPath);
    try {
      await f
          .openRead()
          .map(utf8.decode)
          .transform(const LineSplitter())
          .forEach((l) {
        Block block = Block(l, document: this);

        if (blocks.length < 100) {
          int c = countIndentSize(l);
          if (c > 0 && (c < detectedTabSpaces || detectedTabSpaces == 0)) {
            detectedTabSpaces = c;
          }
        }

        blocks.add(block);
        // FFIBridge.run(() => FFIBridge.add_block(documentId, block.blockId));
      });
    } catch (err, msg) {
      //
    }

    if (detectedTabSpaces > 0) {
      tabString = List.generate(detectedTabSpaces, (_) => ' ').join();
    }
    updateLineNumbers(0);

    for (int i = 0; i < blocks.length; i++) {
      blocks[i].makeDirty(highlight: true);
    }

    cursor();
    moveCursorToStartOfDocument();
    indexer.indexFile(path);
    return true;
  }

  Future<bool> saveFile({String? path}) async {
    File f = await File(path ?? docPath);
    String content = '';
    blocks.forEach((l) {
      content += l.text + '\n';
    });
    f.writeAsString(content);
    return true;
  }

  void show() {
    blocks.forEach((b) {
      print(b.text);
    });
  }

  void clear() {
    cursors.clear();
    blocks.clear();
    addBlockAtLine(0);
    clearCursors();
  }

  void clearCursors() {
    cursors = <Cursor>[cursor()];
    cursor().clearSelection();
  }

  void clearSelection() {
    cursors.forEach((c) {
      c.clearSelection();
    });
  }

  void duplicateSelection() {
    cursors.forEach((c) {
      c.duplicateSelection();
    });
  }

  void duplicateLine() {
    cursors.forEach((c) {
      c.duplicateLine();
    });
  }

  void begin() {
    history.begin(this);
  }

  void commit() {
    for (final a in history.actions) {
      if (!indexingQueue.contains(a.block)) {
        indexingQueue.add(a.block!);
      }
    }
    history.commit();

    while (indexingQueue.length > 0) {
      Block l = indexingQueue.last;
      if (cursor().block == l) break;
      indexingQueue.removeLast();
      indexer.indexWords(l.text);
    }
  }

  void undo() {
    history.undo(this);
  }

  void addCursor() {
    cursors.add(cursor().copy());
  }

  Block? blockAtLine(int index) {
    if (index < 0 || index >= blocks.length) return null;
    return blocks[index]..line = index;
  }

  void updateLineNumbers(int index) {
    Block? prev;
    for (int i = index; i < blocks.length; i++) {
      blocks[i].line = i;
      if (prev != null) {
        prev.next = blocks[i];
        blocks[i].previous = prev;
      }
      prev = blocks[i];
    }
  }

  Block? addBlockAtLine(int index) {
    Block block = Block('', document: this);
    block.line = index;
    blocks.insert(index, block);
    block.previous = blockAtLine(index - 1);
    block.next = blockAtLine(index + 1);
    block.previous?.next = block;
    block.next?.previous = block;
    updateLineNumbers(index);

    // FFIBridge.run(() => FFIBridge.add_block(documentId, block.blockId));
    listeners['onAddBlock']?.forEach((l) {
      l?.call(documentId, block.blockId);
    });

    history.add(block);
    return block;
  }

  Block? removeBlockAtLine(int index) {
    Block? block = blockAtLine(index);
    Block? previous = blockAtLine(index - 1);
    Block? next = blockAtLine(index + 1);
    blocks.removeAt(index);
    previous?.next = next;
    next?.previous = previous;
    updateLineNumbers(index);

    if (block != null) {
      // FFIBridge.run(() => FFIBridge.remove_block(documentId, block.blockId));
      listeners['onRemoveBlock']?.forEach((l) {
        l?.call(documentId, block.blockId);
      });
    }

    history.remove(block);
    return block;
  }

  Block? firstBlock() {
    return blocks[0];
  }

  Block? lastBlock() {
    return blocks[blocks.length - 1];
  }

  void moveCursor(int line, int column, {bool keepAnchor = false}) {
    if (!keepAnchor) {
      clearCursors();
    }
    cursors.forEach((c) {
      c.moveCursor(line, column, keepAnchor: keepAnchor);
    });
  }

  void moveCursorLeft({int count = 1, bool keepAnchor = false}) {
    cursors.forEach((c) {
      c.moveCursorLeft(count: count, keepAnchor: keepAnchor);
    });
  }

  void moveCursorRight({int count = 1, bool keepAnchor = false}) {
    cursors.forEach((c) {
      c.moveCursorRight(count: count, keepAnchor: keepAnchor);
    });
  }

  void moveCursorUp({int count = 1, bool keepAnchor = false}) {
    cursors.forEach((c) {
      c.moveCursorUp(count: count, keepAnchor: keepAnchor);
    });
  }

  void moveCursorDown({int count = 1, bool keepAnchor = false}) {
    cursors.forEach((c) {
      c.moveCursorDown(count: count, keepAnchor: keepAnchor);
    });
  }

  void moveCursorToStartOfLine({bool keepAnchor = false}) {
    cursors.forEach((c) {
      c.moveCursorToStartOfLine(keepAnchor: keepAnchor);
    });
  }

  void moveCursorToEndOfLine({bool keepAnchor = false}) {
    cursors.forEach((c) {
      c.moveCursorToEndOfLine(keepAnchor: keepAnchor);
    });
  }

  void moveCursorToStartOfDocument({bool keepAnchor = false}) {
    cursors.forEach((c) {
      c.moveCursorToStartOfDocument(keepAnchor: keepAnchor);
    });
  }

  void moveCursorToEndOfDocument({bool keepAnchor = false}) {
    cursors.forEach((c) {
      c.moveCursorToEndOfDocument(keepAnchor: keepAnchor);
    });
  }

  void moveCursorNextWord({bool keepAnchor = false}) {
    cursors.forEach((c) {
      c.moveCursorNextWord(keepAnchor: keepAnchor);
    });
  }

  void moveCursorPreviousWord({bool keepAnchor = false}) {
    cursors.forEach((c) {
      c.moveCursorPreviousWord(keepAnchor: keepAnchor);
    });
  }

  void indent() {
    cursors.forEach((c) {
      c.indent();
    });
  }

  void unindent() {
    cursors.forEach((c) {
      c.unindent();
    });
  }

  void backspace() {
    cursors.forEach((c) {
      // print('${c.block?.line} ${c.column}');
      if ((c.block?.previous != null) || c.column > 0) {
        c.moveCursorLeft();
        c.deleteText();
      }
    });
  }

  void insertNewLine() {
    cursorsSorted(inverse: true).forEach((c) {
      c.insertNewLine();
    });

    listeners['onInsertNewLine']?.forEach((l) {
      l?.call();
    });
  }

  void insertText(String text) {
    cursorsSorted(inverse: true).forEach((c) {
      c.insertText(text);
    });

    listeners['onInsertText']?.forEach((l) {
      l?.call(text);
    });
  }

  void deleteText({int numberOfCharacters = 1}) {
    cursorsSorted(inverse: true).forEach((c) {
      c.deleteText(numberOfCharacters: numberOfCharacters);
    });
  }

  List<Block> selectedBlocks() {
    return cursor().selectedBlocks();
  }

  void selectLine() {
    cursors.forEach((c) {
      c.selectLine();
    });
  }

  void selectWord() {
    cursors.forEach((c) {
      c.selectWord();
    });
  }

  String selectedText() {
    String res = '';
    cursors.forEach((c) {
      res += c.selectedText();
    });
    return res;
  }

  void deleteSelectedText() {
    cursors.forEach((c) {
      c.deleteSelectedText();
    });
  }

  bool hasSelection() {
    for (final c in cursors) {
      if (c.hasSelection()) {
        return true;
      }
    }
    return false;
  }

  BlockBracket brackedUnderCursor(Cursor cursor, {bool openOnly: false}) {
    BlockBracket lastBracket = BlockBracket();
    List<BlockBracket> brackets = cursor.block?.brackets ?? [];
    for (final b in brackets) {
      if (openOnly && !b.open) continue;
      if (b.position > cursor.column) {
        return lastBracket;
      }
      lastBracket = b;
    }
    return lastBracket;
  }

  BlockBracket findUnclosedBracket(Cursor cursor) {
    List<BlockBracket> brackets = cursor.block?.brackets ?? [];
    List<BlockBracket> stack = [];
    for (final b in brackets) {
      if (b.position < cursor.column) continue;
      if (b.open) {
        stack.add(b);
      } else {
        if (stack.length > 0) {
          stack.removeLast();
        }
      }
    }

    if (stack.length == 1) {
      return stack[0];
    }
    return BlockBracket();
  }

  List<BlockBracket> findBracketPair(BlockBracket b) {
    Cursor cur = cursor().copy();
    cur.block = b.block;
    cur.column = b.position;
    List<BlockBracket> res = [b];
    List<BlockBracket> stack = [];

    List<Cursor> _folds = folds;
    folds = [];

    bool found = false;
    for (int l = 0; l < 1000 && !found; l++) {
      for (final bc in cur.block?.brackets ?? []) {
        if (bc.position <= cur.column && l == 0) continue;
        if (!bc.open) {
          if (stack.length > 0) {
            stack.removeLast();
            continue;
          }
          res.add(bc);
          found = true;
          break;
        } else {
          if (bc.block == b.block && bc.position == b.position) {
          } else {
            stack.add(bc);
          }
        }
      }
      cur.moveCursorDown();
      cur.moveCursorToStartOfLine();
      if (cur.block == b.block) break;
    }

    folds = _folds;
    return res;
  }

  void toggleFold() {
    Cursor cur = cursor().copy();
    sectionCursors = [];
    BlockBracket b = findUnclosedBracket(cur);
    var res = findBracketPair(b);
    if (res.length != 2) {
      cur.column = 0;
      b = findUnclosedBracket(cur);
      res = findBracketPair(b);
    }
    if (res.length == 2) {
      for (int i = 0; i < 2; i++) {
        Cursor c = cursor().copy();
        c.block = res[i].block;
        c.column = res[i].position;
        c.color = Colors.yellow.withOpacity(0.7);
        sectionCursors.add(c);
      }
    }

    if (sectionCursors.length == 2) {
      Cursor start = sectionCursors[0].copy();
      Cursor end = sectionCursors[1].copy();
      start.anchorBlock = end.block;
      start.anchorColumn = end.column;
      start = start.normalized();
      if (start.anchorBlock?.next == start.block) {
        return;
      }
      int size = folds.length;
      folds.removeWhere((f) {
        return f.block == start.block;
      });
      if (size == folds.length) {
        folds.add(start);
      }
    }
  }

  void autoIndent() {
    cursors.forEach((c) {
      c.autoIndent();
    });
  }

  void unfold(Block? block) {
    folds.removeWhere((f) {
      return f.anchorBlock == block;
    });
  }

  void unfoldAll() {
    folds.clear();
  }

  Future<void> findMatches(String text) async {
    if (text.length > 1) {
      indexer.find(text);
    }
  }

  int computedLine(int line) {
    for (final f in folds) {
      if (line > (f.anchorBlock?.line ?? 0)) {
        line += (f.block?.line ?? 0) - (f.anchorBlock?.line ?? 0) - 1;
      }
    }
    return line;
  }

  int computedSize() {
    int l = blocks.length;
    int sz = 0;
    for (final f in folds) {
      sz += (f.block?.line ?? 0) - (f.anchorBlock?.line ?? 0) - 1;
    }
    l -= sz;
    if (l < 1) {
      l = 1;
    }
    return l;
  }
}

class DocumentProvider extends ChangeNotifier {
  Document doc = Document();

  int scrollTo = -1;
  bool softWrap = true;
  bool showGutters = true;
  bool showMinimap = true;
  bool ready = false;

  Future<bool> openFile(String path) async {
    doc.openFile(path).then((r) {
      ready = true;
      notifyListeners();
    });
    return true;
  }

  void touch() {
    notifyListeners();
  }
}
