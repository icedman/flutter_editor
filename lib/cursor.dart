import 'document.dart';

class Cursor {
  Cursor(
      {Block? this.block,
      Block? this.anchorBlock,
      this.column = 0,
      this.anchorColumn = 0,
      this.line = 0,
      this.anchorLine = 0,
      this.document});

  Document? document;
  Block? block;
  int line = 0;
  int column = 0;
  Block? anchorBlock;
  int anchorLine = 0;
  int anchorColumn = 0;

  bool get isNull {
    return document == null;
  }

  Cursor copy() {
    return Cursor(
        document: document,
        block: block,
        line: line,
        column: column,
        anchorBlock: anchorBlock,
        anchorLine: anchorLine,
        anchorColumn: anchorColumn);
  }

  bool get isNormalized {
    return !(line > anchorLine ||
        (line == anchorLine && column > anchorColumn));
  }

  Cursor normalized({bool inverse = false}) {
    Cursor res = copy();
    bool shouldFlip = !isNormalized;
    if (inverse) {
      shouldFlip = !shouldFlip;
    }
    if (shouldFlip) {
      res.line = anchorLine;
      res.column = anchorColumn;
      res.anchorLine = line;
      res.anchorColumn = column;
      return res;
    }
    return res;
  }

  void copyFrom(Cursor cursor, {bool keepAnchor = false}) {
    document = cursor.document;
    line = cursor.line;
    column = cursor.column;
    anchorLine = cursor.anchorLine;
    anchorColumn = cursor.anchorColumn;
    _validateCursor(keepAnchor);
  }

  bool hasSelection() {
    return line != anchorLine || column != anchorColumn;
  }

  bool _validateCursor(bool keepAnchor) {
    List<Block> blocks = document?.blocks ?? [];
    List<Cursor> cursors = document?.cursors ?? [];
    if (line >= blocks.length) {
      line = blocks.length - 1;
    }
    if (line < 0) line = 0;
    if (column > blocks[line].text.length) {
      column = blocks[line].text.length;
    }
    if (column == -1) column = blocks[line].text.length;
    if (column < 0) column = 0;
    if (!keepAnchor) {
      anchorLine = line;
      anchorColumn = column;
    }
    block = blocks[line];
    anchorBlock = blocks[anchorLine];
    return true;
  }

  void clearSelection() {
    anchorLine = line;
    anchorColumn = column;
    _validateCursor(false);
  }

  void moveCursor(int l, int c, {bool keepAnchor = false}) {
    block = document?.blockAtLine(l) ?? Block('');
    block?.line = l;
    line = l;
    column = c;
    _validateCursor(keepAnchor);
  }

  void moveCursorLeft({int count = 1, bool keepAnchor = false}) {
    if (hasSelection() && !keepAnchor) {
      clearSelection();
      return;
    }
    column = column - count;
    if (column < 0) {
      if (line > 0) {
        moveCursorUp(keepAnchor: keepAnchor);
        moveCursorToEndOfLine(keepAnchor: keepAnchor);
      } else {
        column = 0;
      }
    }
    _validateCursor(keepAnchor);
  }

  void moveCursorRight({int count = 1, bool keepAnchor = false}) {
    if (hasSelection() && !keepAnchor) {
      clearSelection();
      return;
    }
    List<Block> blocks = document?.blocks ?? [];
    String l = block?.text ?? '';
    column = column + count;
    if (column > l.length) {
      if (line < blocks.length - 1) {
        moveCursorDown(keepAnchor: keepAnchor);
        moveCursorToStartOfLine(keepAnchor: keepAnchor);
      } else {
        column = l.length - 1;
      }
    }
    _validateCursor(keepAnchor);
  }

  void moveCursorUp({int count = 1, bool keepAnchor = false}) {
    block = block?.previous ?? block;
    line = block?.line ?? 0;
    if (!keepAnchor) {
      anchorBlock = block;
      anchorLine = line;
    }
    // line = line - count;
    _validateCursor(keepAnchor);
  }

  void moveCursorDown({int count = 1, bool keepAnchor = false}) {
    block = block?.next ?? block;
    line = block?.line ?? 0;
    if (!keepAnchor) {
      anchorBlock = block;
      anchorLine = line;
    }
    // line = line + count;
    _validateCursor(keepAnchor);
  }

  void moveCursorToStartOfLine({bool keepAnchor = false}) {
    column = 0;
    _validateCursor(keepAnchor);
  }

  void moveCursorToEndOfLine({bool keepAnchor = false}) {
    List<Block> blocks = document?.blocks ?? [];
    column = blocks[line].text.length;
    _validateCursor(keepAnchor);
  }

  void moveCursorToStartOfDocument({bool keepAnchor = false}) {
    line = 0;
    column = 0;
    _validateCursor(keepAnchor);
  }

  void moveCursorToEndOfDocument({bool keepAnchor = false}) {
    List<Block> blocks = document?.blocks ?? [];
    line = blocks.length - 1;
    column = blocks[line].text.length;
    _validateCursor(keepAnchor);
  }

  void deleteSelectedText() {
    List<Block> blocks = document?.blocks ?? [];
    if (!hasSelection()) {
      return;
    }

    Cursor cur = normalized();
    List<String> res = selectedBlocks();
    if (res.length == 1) {
      deleteText(numberOfCharacters: cur.anchorColumn - cur.column);
      clearSelection();
      return;
    }

    String l = block?.text ?? '';
    String left = l.substring(0, cur.column);
    l = blocks[cur.anchorLine].text;
    String right = l.substring(cur.anchorColumn);

    copyFrom(cur);
    blocks[cur.line].text = left + right;
    blocks[cur.anchorLine].text =
        blocks[cur.anchorLine].text.substring(cur.anchorColumn);
    for (int i = 0; i < res.length - 1; i++) {
      document?.removeBlockAtLine(cur.line + 1);
    }
    _validateCursor(false);
  }

  List<String> selectedBlocks() {
    List<Block> blocks = document?.blocks ?? [];
    List<String> res = <String>[];
    Cursor cur = normalized();
    if (cur.line == cur.anchorLine) {
      String sel =
          blocks[cur.line].text.substring(cur.column, cur.anchorColumn);
      res.add(sel);
      return res;
    }

    res.add(blocks[cur.line].text.substring(cur.column));
    for (int i = cur.line + 1; i < cur.anchorLine; i++) {
      res.add(blocks[i].text);
    }
    res.add(blocks[cur.anchorLine].text.substring(0, cur.anchorColumn));
    return res;
  }

  String selectedText() {
    return selectedBlocks().join('\n');
  }

  void deleteText({int numberOfCharacters = 1}) {
    List<Cursor> cursors = document?.cursors ?? [];
    List<Cursor> cursorsToUpdate = [];
    List<Block> blocks = document?.blocks ?? [];
    String l = blocks[line].text;

    cursors.forEach((c) {
      if (c.line == line && c.column > column) {
        cursorsToUpdate.add(c);
      }
    });

    // handle join blocks
    if (column >= l.length) {
      Cursor cur = copy();
      int offset = blocks[line].text.length;
      blocks[line].text += blocks[line + 1].text;
      cursors.forEach((c) {
        if (c.line == line + 1) {
          c.column += offset;
          c.line = line;
        } else if (c.line > line + 1) {
          c.line--;
        }
        c._validateCursor(false);
      });
      document?.removeBlockAtLine(line + 1);
      copyFrom(cur);
      return;
    }

    Cursor cur = normalized();
    String left = l.substring(0, cur.column);
    String right = l.substring(cur.column + numberOfCharacters);
    copyFrom(cur);

    // handle erase entire line
    if (blocks.length > 1 && (left + right).length == 0) {
      blocks.removeAt(cur.line);
      moveCursorUp();
      moveCursorToStartOfLine();
      cursors.forEach((c) {
        if (c.line > line) {
          c.line--;
          c.anchorLine = c.line;
          c.anchorColumn = c.column;
          c._validateCursor(true);
        }
      });
      return;
    }

    blocks[line].text = left + right;
    cursorsToUpdate.forEach((c) {
      c.column -= numberOfCharacters;
      c.anchorColumn -= numberOfCharacters;
      c._validateCursor(true);
    });
  }

  // void deleteLine({int numberOfBlocks = 1}) {
  //   for(int i=0; i<numberOfBlocks; i++) {
  //     document?.removeBlockAtLine(line);
  //   }
  //   _validateCursor(false);
  // }

  void insertNewLine() {
    deleteSelectedText();
    insertText('\n');
  }

  void insertText(String text) {
    List<Cursor> cursors = document?.cursors ?? [];
    List<Cursor> cursorsToUpdate = [];
    deleteSelectedText();
    String l = block?.text ?? '';

    if (column >= l.length) {
      column = l.length;
    }

    String left = l.substring(0, column);
    String right = l.substring(column);

    cursors.forEach((c) {
      if (c.line == line && c.column > column) {
        cursorsToUpdate.add(c);
      }
    });

    // handle new line
    if (text == '\n') {
      block?.text = left;
      Block? newBlock = document?.addBlockAtLine(line + 1);
      newBlock?.text = right;
      moveCursorDown();
      moveCursorToStartOfLine();
      cursors.forEach((c) {
        if (c.line >= line && c != this) {
          c.line++;
          c.anchorLine++;
          c._validateCursor(true);
        }
      });
      return;
    }

    block?.text = left + text + right;
    moveCursorRight(count: text.length);

    cursorsToUpdate.forEach((c) {
      c.column += text.length;
      c.anchorColumn += text.length;
      c._validateCursor(true);
    });
  }

  Cursor findText(String text) {
    List<Block> blocks = document?.blocks ?? [];
    Cursor cur = normalized();
    cur.clearSelection();
    cur.moveCursorRight(count: text.length);
    for (int i = line; i < blocks.length; i++) {
      String l = block?.text ?? '';
      int idx = l.indexOf(text, cur.column);
      if (idx != -1) {
        cur.column = idx;
        cur.anchorColumn = idx + text.length;
        cur._validateCursor(true);
        return cur.normalized(inverse: !isNormalized);
      } else {
        cur.moveCursorDown();
        cur.moveCursorToStartOfLine();
      }
    }

    return Cursor();
  }

  void validateCursor() {
    _validateCursor(hasSelection());
  }
}
