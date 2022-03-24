import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:highlight/src/mode.dart';

import 'package:editor/cursor.dart';
import 'package:editor/native.dart';
import 'package:editor/services/highlighter.dart';

int _documentId = 0xffff;
int _blockId = 0xffff;

class BlockCaret {
  BlockCaret({int this.position = 0, Color this.color = Colors.white});
  int position = 0;
  Color color = Colors.white;
}

class BlockData extends ChangeNotifier {}

class Block {
  Block(String this.text, {int this.line = 0, Document? this.document}) {
    blockId = _blockId++;
  }

  int blockId = 0;
  int line = 0;
  String text = '';
  String prevText = '';
  Document? document;
  Block? previous;
  Block? next;

  BlockData data = BlockData();

  bool waiting = false;

  List<LineDecoration> decors = [];
  List<InlineSpan>? spans;
  List<BlockCaret> carets = [];
  int lineCount = 0;

  Mode? mode;
  String className = '';
  String prevBlockClass = '';

  void makeDirty() {
    prevBlockClass = '';
    mode = null;
    spans = null;
    carets = [];
  }
}

class Document {
  String docPath = '';
  List<Block> blocks = [];
  List<Cursor> cursors = [];
  List<Cursor> folds = [];

  int documentId = 0;

  Document() {
    documentId = _documentId++;
    FFIBridge.create_document(documentId);
    clear();
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

  Future<bool> openFile(String path) async {
    clear();
    docPath = path;
    File f = File(docPath);
    try {
      await f
          .openRead()
          .map(utf8.decode)
          .transform(const LineSplitter())
          .forEach((l) {
        insertText(l);
        insertNewLine();
      });
    } catch (err, msg) {
      //
    }
    moveCursorToStartOfDocument();
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

  void beginEdit() {}

  void endEdit() {}

  void addCursor() {
    cursors.add(cursor().copy());
  }

  Block? blockAtLine(int index) {
    if (index < 0 || index >= blocks.length) return null;
    return blocks[index];
  }

  Block? addBlockAtLine(int index) {
    Block block = Block('', document: this);
    block.line = index;
    blocks.insert(index, block);
    block.previous = blockAtLine(index - 1);
    block.next = blockAtLine(index + 1);
    block.previous?.next = block;
    block.next?.previous = block;
    for (int i = index; i < blocks.length; i++) {
      blocks[i].line = i;
    }

    FFIBridge.add_block(documentId, block.blockId);
    return block;
  }

  Block? removeBlockAtLine(int index) {
    Block? block = blockAtLine(index);
    Block? previous = blockAtLine(index - 1);
    Block? next = blockAtLine(index + 1);
    blocks.removeAt(index);
    previous?.next = next;
    next?.previous = previous;
    for (int i = index; i < blocks.length; i++) {
      blocks[i].line = i;
    }

    if (block != null) {
      FFIBridge.remove_block(documentId, block.blockId);
    }

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
  }

  void insertText(String text) {
    cursorsSorted(inverse: true).forEach((c) {
      c.insertText(text);
    });
  }

  void deleteText({int numberOfCharacters = 1}) {
    cursorsSorted(inverse: true).forEach((c) {
      c.deleteText(numberOfCharacters: numberOfCharacters);
    });
  }

  // void deleteLine({int numberOfBlocks = 1}) {
  //   cursorsSorted().forEach((c) {
  //     c.deleteLine(numberOfBlocks: 1);
  //   });
  // }

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
}

class DocumentProvider extends ChangeNotifier {
  Document doc = Document();

  int scrollTo = -1;
  bool softWrap = true;
  bool showGutters = true;
  bool showMinimap = true;

  Future<bool> openFile(String path) async {
    bool res = await doc.openFile(path);
    notifyListeners();
    return res;
  }

  void touch() {
    notifyListeners();
  }
}
