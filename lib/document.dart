import 'dart:io';
import 'dart:convert';

import 'cursor.dart';

class Block {
  Block(String this.text, {int this.line = 0, Document? this.document});
  int line = 0;
  String text = '';
  Document? document;
  Block? previous;
  Block? next;
}

class Document {
  String docPath = '';
  List<Block> blocks = [];
  List<Cursor> cursors = [];
  String clipboardText = '';

  Document() {
    clear();
  }

  Cursor cursor() {
    return cursors.length > 0
        ? cursors[0]
        : Cursor(document: this, block: firstBlock())
      ..block = blocks[0];
  }

  List<Cursor> cursorsSorted({bool inverse: false}) {
    List<Cursor> curs = [...cursors];
    curs.sort((a, b) {
      return ((a.line > b.line || (a.line == b.line && a.column > b.column))
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
        if (c != _c && _c.line == c.line && _c.column == c.column) {
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
    File f = await File(docPath);
    await f.openRead().map(utf8.decode).transform(LineSplitter()).forEach((l) {
      insertText(l);
      insertNewLine();
    });
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
    blocks = <Block>[];
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

  void beginEdit() {
    cursors.forEach((c) {
      c.block = blockAtLine(c.line);
      c.anchorBlock = blockAtLine(c.anchorLine);
    });
  }

  void endEdit() {
    cursors.forEach((c) {
      c.validateCursor();
    });
  }

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
    return block;
  }

  Block? removeBlockAtLine(int index) {
    Block? block = blockAtLine(index);
    Block? previous = blockAtLine(index - 1);
    Block? next = blockAtLine(index + 1);
    blocks.removeAt(index);
    previous?.next = next;
    next?.previous = previous;
    return block;
  }

  Block? firstBlock() {
    return blocks[0];
  }

  Block? lastBlock() {
    return blocks[blocks.length - 1];
  }

  void moveCursor(int line, int column, {bool keepAnchor = false}) {
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

  void insertNewLine() {
    cursorsSorted(inverse: true).forEach((c) {
      c.insertNewLine();
      c.validateCursor();
    });
  }

  void insertText(String text) {
    cursorsSorted(inverse: true).forEach((c) {
      c.insertText(text);
    });
    cursors.forEach((c) => c.validateCursor());
  }

  void deleteText({int numberOfCharacters = 1}) {
    cursorsSorted().forEach((c) {
      c.deleteText(numberOfCharacters: 1);
    });
    cursors.forEach((c) => c.validateCursor());
    cursors = cursorsUniqued();
  }

  // void deleteLine({int numberOfBlocks = 1}) {
  //   cursorsSorted().forEach((c) {
  //     c.deleteLine(numberOfBlocks: 1);
  //   });
  //   cursors.forEach((c) => c.validateCursor());
  // }

  List<String> selectedBlocks() {
    return cursor().selectedBlocks();
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

  void command(String cmd) {
    switch (cmd) {
      case 'ctrl+c':
        clipboardText = selectedText();
        break;
      case 'ctrl+x':
        clipboardText = selectedText();
        deleteSelectedText();
        break;
      case 'ctrl+v':
        {
          List<String> lines = clipboardText.split('\n');
          int idx = 0;
          lines.forEach((l) {
            if (idx++ > 0) {
              insertNewLine();
            }
            insertText(l);
          });

          break;
        }
      case 'ctrl+s':
        saveFile();
        break;
      case 'ctrl+d':
        {
          if (cursor().hasSelection()) {
            Cursor cur = cursor().findText(cursor().selectedText());
            if (!cur.isNull) {
              addCursor();
              cursor().copyFrom(cur, keepAnchor: true);
            }
          }
          break;
        }
    }
  }
}
