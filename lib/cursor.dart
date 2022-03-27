import 'package:editor/document.dart';
import 'package:flutter/material.dart';

class Cursor {
  Cursor(
      {Block? this.block,
      Block? this.anchorBlock,
      this.column = 0,
      this.anchorColumn = 0,
      this.document}) {
    if (anchorBlock == null) {
      anchorBlock = block;
      anchorColumn = column;
    }
  }

  Document? document;
  Block? block;
  int column = 0;
  Block? anchorBlock;
  int anchorColumn = 0;
  Color color = Colors.white;

  bool get isNull {
    return document == null;
  }

  Cursor copy() {
    return Cursor(
        document: document,
        block: block,
        column: column,
        anchorBlock: anchorBlock,
        anchorColumn: anchorColumn);
  }

  // is anchor position before cursor position
  bool get isNormalized {
    if (anchorBlock == null) {
      anchorBlock = block;
      anchorColumn = column;
    }
    int line = block?.line ?? 0;
    int anchorLine = anchorBlock?.line ?? 0;
    bool res =
        ((block == anchorBlock && column > anchorColumn) || line > anchorLine);
    return res;
  }

  Cursor normalized({bool inverse = false}) {
    Cursor res = copy();
    bool shouldFlip = !isNormalized;
    if (inverse) {
      shouldFlip = !shouldFlip;
    }
    if (shouldFlip) {
      res.block = anchorBlock;
      res.column = anchorColumn;
      res.anchorBlock = block;
      res.anchorColumn = column;
    }
    return res;
  }

  void copyFrom(Cursor cursor, {bool keepAnchor = false}) {
    document = cursor.document;
    block = cursor.block;
    column = cursor.column;
    anchorBlock = cursor.anchorBlock;
    anchorColumn = cursor.anchorColumn;
  }

  bool hasSelection() {
    return block != anchorBlock || column != anchorColumn;
  }

  void clearSelection() {
    anchorBlock = block;
    anchorColumn = column;
  }

  void moveCursor(int l, int c, {bool keepAnchor = false}) {
    block?.makeDirty();
    block = document?.blockAtLine(l) ?? Block('');
    block?.line = l;
    block?.makeDirty();
    column = c;

    int len = (block?.text ?? '').length;
    if (column > len || column == -1) {
      column = len;
    }

    if (!keepAnchor) {
      anchorBlock = block;
      anchorColumn = column;
    }
  }

  void moveCursorLeft({int count = 1, bool keepAnchor = false}) {
    block?.makeDirty();
    if (hasSelection() && !keepAnchor) {
      clearSelection();
      return;
    }

    if (column >= (block?.text ?? '').length) {
      moveCursorToEndOfLine(keepAnchor: keepAnchor);
    }

    int line = block?.line ?? 0;
    column = column - count;
    if (column < 0) {
      if (line > 0) {
        moveCursorUp(keepAnchor: keepAnchor);
        moveCursorToEndOfLine(keepAnchor: keepAnchor);
      } else {
        column = 0;
      }
    }
    if (!keepAnchor) {
      anchorBlock = block;
      anchorColumn = column;
    }
    block?.makeDirty();
  }

  void moveCursorRight({int count = 1, bool keepAnchor = false}) {
    block?.makeDirty();
    if (hasSelection() && !keepAnchor) {
      clearSelection();
      return;
    }
    List<Block> blocks = document?.blocks ?? [];
    int line = block?.line ?? 0;
    String l = block?.text ?? '';
    column = column + count;
    if (column > l.length) {
      if (line < blocks.length - 1) {
        moveCursorDown(keepAnchor: keepAnchor);
        moveCursorToStartOfLine(keepAnchor: keepAnchor);
      }
    }
    if (!keepAnchor) {
      anchorBlock = block;
      anchorColumn = column;
    }
    block?.makeDirty();
  }

  void _moveCursorUp({int count = 1, bool keepAnchor = false}) {
    block?.makeDirty();
    block = block?.previous ?? block;
    if (!keepAnchor) {
      anchorBlock = block;
      anchorColumn = column;
    }
    block?.makeDirty();
  }

  void moveCursorUp({int count = 1, bool keepAnchor = false}) {
    _moveCursorUp(count: count, keepAnchor: keepAnchor);
    int idx = 0;
    while ((block?.isHidden() ?? false) && idx++ < 1000) {
      _moveCursorUp(count: count, keepAnchor: keepAnchor);
    }
  }

  void _moveCursorDown({int count = 1, bool keepAnchor = false}) {
    block?.makeDirty();
    block = block?.next ?? block;
    if (!keepAnchor) {
      anchorBlock = block;
      anchorColumn = column;
    }
    block?.makeDirty();
  }

  void moveCursorDown({int count = 1, bool keepAnchor = false}) {
    _moveCursorDown(count: count, keepAnchor: keepAnchor);
    int idx = 0;
    while ((block?.isHidden() ?? false) && idx++ < 1000) {
      _moveCursorDown(count: count, keepAnchor: keepAnchor);
    }
  }

  void moveCursorToStartOfLine({bool keepAnchor = false}) {
    block?.makeDirty();
    column = 0;
    if (!keepAnchor) {
      anchorBlock = block;
      anchorColumn = column;
    }
  }

  void moveCursorToEndOfLine({bool keepAnchor = false}) {
    block?.makeDirty();
    String l = block?.text ?? '';
    column = l.length;
    if (!keepAnchor) {
      anchorBlock = block;
      anchorColumn = column;
    }
  }

  void moveCursorToStartOfDocument({bool keepAnchor = false}) {
    block?.makeDirty();
    block = document?.firstBlock();
    column = 0;
    if (!keepAnchor) {
      anchorBlock = block;
      anchorColumn = column;
    }
    block?.makeDirty();
  }

  void moveCursorToEndOfDocument({bool keepAnchor = false}) {
    block?.makeDirty();
    block = document?.lastBlock();
    column = block?.text.length ?? 0;
    if (!keepAnchor) {
      anchorBlock = block;
      anchorColumn = column;
    }
    block?.makeDirty();
  }

  void deleteSelectedText() {
    if (!hasSelection()) {
      return;
    }

    Cursor cur = normalized(inverse: true);
    List<Block> res = selectedBlocks();

    for (final b in res) {
      document?.unfold(b);
    }

    if (res.length == 1) {
      cur.deleteText(numberOfCharacters: cur.anchorColumn - cur.column);
      cur.clearSelection();
      cur.block?.makeDirty(highlight: true);
      copyFrom(cur);
      return;
    }

    int blockLine = cur.block?.line ?? 0;
    String l = cur.block?.text ?? '';
    String left = l.substring(0, cur.column);
    String al = cur.anchorBlock?.text ?? '';
    String right = ''; //
    if (al.length > cur.anchorColumn) {
      right = al.substring(cur.anchorColumn);
    }

    // print('${res.length}');

    for (int i = 0; i < (res.length - 1); i++) {
      document?.removeBlockAtLine(blockLine + 1);
    }
    cur.block?.text = left + right;
    cur.clearSelection();
    cur.block?.makeDirty(highlight: true);
    copyFrom(cur);
  }

  List<Block> selectedBlocks() {
    List<Block> res = <Block>[];
    if (!hasSelection()) return res;
    Cursor cur = normalized(inverse: true);
    int blockLine = cur.block?.line ?? 0;
    int anchorLine = cur.anchorBlock?.line ?? 0;
    if (blockLine == anchorLine) {
      res.add(block ?? Block(''));
      return res;
    }
    res.add(block ?? Block(''));
    Block? b = cur.block?.next;
    for (int i = blockLine + 1; b != null && i < anchorLine; i++) {
      res.add(b);
      b.makeDirty();
      b = b.next;
    }
    res.add(anchorBlock ?? Block(''));
    return res;
  }

  String selectedText() {
    List<String> res = [];
    Cursor cur = normalized(inverse: true);
    int blockLine = cur.block?.line ?? 0;
    int anchorLine = cur.anchorBlock?.line ?? 0;
    if (blockLine == anchorLine) {
      return (block?.text ?? '').substring(cur.column, cur.anchorColumn);
    }
    res.add((cur.block?.text ?? '').substring(cur.column));
    Block? b = cur.block?.next;
    for (int i = blockLine + 1; b != null && i < anchorLine; i++) {
      res.add(b.text);
      b = b.next;
    }
    res.add((cur.anchorBlock?.text ?? '').substring(0, cur.anchorColumn));
    return res.join('\n');
  }

  void selectLine() {
    moveCursorToStartOfLine();
    moveCursorToEndOfLine(keepAnchor: true);
  }

  void selectWord() {
    RegExp regExp = new RegExp(
      r'[a-z_\-0-9]*',
      caseSensitive: false,
      multiLine: false,
    );
    String l = block?.text ?? '';
    var matches = regExp.allMatches(l);
    for (final m in matches) {
      var g = m.groups([0]);
      String t = g[0] ?? '';
      if (t.length > 0) {
        if (column >= m.start && column < m.start + t.length) {
          anchorColumn = m.start;
          column = anchorColumn + t.length;
          break;
        }
      }
    }
  }

  void moveCursorNextWord({bool keepAnchor = false}) {
    RegExp regExp = new RegExp(
      r'[a-z_\-0-9]*',
      caseSensitive: false,
      multiLine: false,
    );
    String l = block?.text ?? '';
    var matches = regExp.allMatches(l);
    bool breakNext = false;
    bool found = false;
    for (final m in matches) {
      var g = m.groups([0]);
      String t = g[0] ?? '';
      if (column >= m.start) {
        breakNext = true;
        continue;
      }
      if (t.length > 0 && breakNext) {
        column = m.start;
        found = true;
        if (!keepAnchor) {
          anchorBlock = block;
          anchorColumn = column;
        }
        break;
      }
    }
    if (!found) moveCursorToEndOfLine(keepAnchor: keepAnchor);
    block?.makeDirty();
  }

  void moveCursorPreviousWord({bool keepAnchor = false}) {
    RegExp regExp = new RegExp(
      r'[a-z_\-0-9]*',
      caseSensitive: false,
      multiLine: false,
    );
    int lastColumn = column;
    bool found = false;
    String l = block?.text ?? '';
    var matches = regExp.allMatches(l);
    for (final m in matches) {
      var g = m.groups([0]);
      String t = g[0] ?? '';
      if (m.start >= column && column > lastColumn) {
        column = lastColumn;
        found = true;
        if (!keepAnchor) {
          anchorBlock = block;
          anchorColumn = column;
        }
        break;
      }
      if (t.length > 0) {
        lastColumn = m.start;
      }
    }
    if (!found) moveCursorToStartOfLine(keepAnchor: keepAnchor);
    block?.makeDirty();
  }

  void mergeNextLine() {
    String l = block?.text ?? '';
    Block? next = block?.next;
    if (next == null) {
      return;
    }

    List<Cursor> cursorsToMerge = [];
    List<Cursor> cursors = document?.cursors ?? [];
    cursors.forEach((c) {
      if (c.block == next) {
        cursorsToMerge.add(c);
      }
    });

    String ln = next.text;
    document?.removeBlockAtLine(next.line);
    block?.text = l + ln;
    block?.makeDirty(highlight: true);

    cursorsToMerge.forEach((c) {
      c.column += l.length;
      c.block = block;
      c.anchorBlock = c.block;
      c.anchorColumn = c.column;
    });
  }

  void deleteText({int numberOfCharacters = 1}) {
    String l = block?.text ?? '';

    // handle join blocks
    if (column >= l.length) {
      moveCursorToEndOfLine();

      if (block?.isFolded() ?? true) {
        block?.document?.unfold(block);
        return;
      }

      mergeNextLine();
      return;
    }

    String left = l.substring(0, column);
    String right = l.substring(column + numberOfCharacters);
    block?.text = left + right;
    block?.makeDirty(highlight: true);
    advanceBlockCursors(-numberOfCharacters);
  }

  void insertNewLine() {
    if (block?.isFolded() ?? true) {
      block?.document?.unfold(block);
      return;
    }
    deleteSelectedText();
    int line = block?.line ?? 0;
    String l = block?.text ?? '';
    if (column >= l.length) {
      column = l.length;
    }

    String left = l.substring(0, column);
    String right = l.substring(column);

    // handle new line
    block?.text = left;
    block?.makeDirty(highlight: true);
    Block? newBlock = document?.addBlockAtLine(line + 1);
    newBlock?.text = right;
    newBlock?.makeDirty(highlight: true);
    moveCursorDown();
    moveCursorToStartOfLine();
  }

  void insertText(String text) {
    deleteSelectedText();
    String l = block?.text ?? '';

    if (column >= l.length) {
      moveCursorToEndOfLine();
    }

    String left = l.substring(0, column);
    String right = l.substring(column);

    block?.text = left + text + right;
    block?.makeDirty(highlight: true);
    moveCursorRight(count: text.length);
    advanceBlockCursors(text.length);
  }

  Cursor findText(String text) {
    Cursor cur = normalized();
    cur.clearSelection();
    cur.moveCursorRight();
    Block? b = cur.block;
    while (b != null) {
      String l = b.text;
      int idx = l.indexOf(text, cur.column);
      if (idx != -1) {
        cur.column = idx;
        cur.anchorColumn = idx + text.length;
        return cur.normalized(inverse: !isNormalized);
      } else {
        cur.moveCursorDown();
        cur.moveCursorToStartOfLine();
      }
      b = b.next;
    }
    return Cursor();
  }

  void advanceBlockCursors(int count) {
    List<Cursor> cursors = document?.cursors ?? [];
    cursors.forEach((c) {
      if (c.block != block) return;
      if (c.column <= column) return;
      c.column += count;
      c.anchorColumn += count;
    });
  }

  void validateCursor() {}
}
