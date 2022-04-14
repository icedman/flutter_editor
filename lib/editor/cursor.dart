import 'dart:convert';
import 'package:editor/editor/document.dart';
import 'package:editor/editor/history.dart';
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

  @override
  String toString() {
    return jsonEncode({
      'line': (block?.line ?? 0),
      'column': column,
      'anchorLine': (anchorBlock?.line ?? 0),
      'anchorColumn': anchorColumn
    });
  }

  @override
  bool operator ==(_other) {
    if (!(_other is Cursor)) return false;
    Cursor other = _other as Cursor;
    return other.block == block &&
        other.column == column &&
        other.anchorBlock == anchorBlock &&
        other.anchorColumn == anchorColumn;
  }

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

  void duplicateLine() {
    selectLine();
    String text = selectedText();
    clearSelection();
    insertNewLine();
    insertText(text);
  }

  void duplicateSelection() {
    Cursor cur = copy();
    String text = selectedText();
    bool isn = isNormalized;
    clearSelection();

    insertText(text);

    if (isn) {
      moveCursorLeft(count: text.length, keepAnchor: true);
      copyFrom(normalized());
    } else {
      moveCursorRight(count: text.length, keepAnchor: true);
      copyFrom(cur);
    }

    if (text.contains('\n')) {
      clearSelection();
    }
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
        moveCursorNextLine(keepAnchor: keepAnchor);
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
    String left = l;
    if (l.length > cur.column) {
      left = l.substring(0, cur.column);
    }
    String al = cur.anchorBlock?.text ?? '';
    String right = '';
    if (al.length > cur.anchorColumn) {
      right = al.substring(cur.anchorColumn);
    }

    // print('${res.length}');

    for (int i = 0; i < (res.length - 1); i++) {
      document?.removeBlockAtLine(blockLine + 1);
    }

    document?.history.update(cur.block);
    cur.block?.text = left + right;
    cur.column = left.length;
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
    
    // todo add safe substring
    String curText = (cur.block?.text ?? '');
    int col = cur.column;
    if (col > curText.length) {
      col = curText.length;
    }
    res.add(curText.substring(col));
    
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
    String l = block?.text ?? '';
    var matches = block?.words ?? [];
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
    int lastColumn = column;
    bool found = false;
    String l = block?.text ?? '';
    var matches = block?.words ?? [];
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

  bool moveCursorPreviousLine({bool keepAnchor = false}) {
    if (block?.previous == null) {
      return false;
    }
    moveCursorUp(keepAnchor: keepAnchor);
    moveCursorToStartOfLine(keepAnchor: keepAnchor);
    return true;
  }

  bool moveCursorNextLine({bool keepAnchor = false}) {
    if (block?.next == null) {
      return false;
    }
    moveCursorDown(keepAnchor: keepAnchor);
    moveCursorToStartOfLine(keepAnchor: keepAnchor);
    return true;
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
    document?.history.update(block);
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
        document?.unfold(block);
        return;
      }

      mergeNextLine();
      return;
    }

    String left = l.substring(0, column);
    String right = l.substring(column + numberOfCharacters);
    document?.history.update(block);
    block?.text = left + right;
    block?.makeDirty(highlight: true);
    advanceBlockCursors(-numberOfCharacters);
  }

  void insertNewLine() {
    if (block?.isFolded() ?? true) {
      document?.unfold(block);
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
    document?.history.update(block);
    block?.text = left;
    block?.makeDirty(highlight: true);
    Block? newBlock = document?.addBlockAtLine(line + 1);
    document?.history.update(newBlock);
    newBlock?.text = right;
    newBlock?.makeDirty(highlight: true);
    moveCursorNextLine();
  }

  void _insertText(String text) {
    List<String> lines = text.split('\n');
    int i = 0;
    for (final l in lines) {
      if (i++ > 0) {
        insertNewLine();
      }
      insertText(l);
    }
  }

  void insertText(String text) {
    if (text.contains('\n')) {
      _insertText(text);
      return;
    }
    deleteSelectedText();
    String l = block?.text ?? '';

    if (column >= l.length) {
      moveCursorToEndOfLine();
    }

    String left = l.substring(0, column);
    String right = l.substring(column);

    document?.history.update(block, type: 'insert', inserted: text);
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
        cur.moveCursorNextLine();
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

  void autoIndent() {
    Cursor cur = copy();
    cur.moveCursorUp();
    if (cur.block == block) return;
    int stops = 0;
    for (int i = 0; i < 8 && stops == 0; i++) {
      String t = cur.block?.text ?? '';
      stops = Document.countIndentSize(t);
      cur.moveCursorPreviousLine();
      if (t.length > 0) break;
    }
    if (stops == 0) return;
    String tab = List.generate(stops, (_) => ' ').join();
    insertText(tab);
  }

  void _toggleComment() {
    Cursor cur = copy();
    cur.moveCursorToStartOfLine();
    String comment = cur.document?.lineComment ?? '';
    if (comment == '') return;

    comment += ' ';

    String t = cur.block?.text ?? '';
    String tt = t.trim();
    if (tt == '') return;
    if (tt.startsWith(comment)) {
      cur.moveCursorRight(count: t.indexOf(comment));
      cur.deleteText(numberOfCharacters: comment.length);
      return;
    }
    int c = Document.countIndentSize(t);
    cur.moveCursorRight(count: c);
    cur.insertText(comment);
  }

  void toggleComment() {
    if (hasSelection()) {
      List<Block> blocks = selectedBlocks();
      blocks = blocks.toSet().toList();
      for (final b in blocks) {
        Cursor c = copy();
        c.block = b;
        c.moveCursorToStartOfLine();
        c._toggleComment();
      }
      return;
    }
    _toggleComment();
  }

  void _indent() {
    Cursor cur = copy();
    cur.moveCursorToStartOfLine();
    String tab = cur.document?.tabString ?? ' ';
    cur.insertText(tab);
  }

  void indent() {
    if (hasSelection()) {
      List<Block> blocks = selectedBlocks();
      blocks = blocks.toSet().toList();
      for (final b in blocks) {
        Cursor c = copy();
        c.block = b;
        c.moveCursorToStartOfLine();
        c._indent();
      }
      return;
    }
    _indent();
  }

  void _unindent() {
    Cursor cur = copy();
    cur.moveCursorToStartOfLine();
    String tab = cur.document?.tabString ?? ' ';
    String t = cur.block?.text ?? '';
    if (t.startsWith(tab)) {
      cur.deleteText(numberOfCharacters: tab.length);
    } else {
      int indentSize = Document.countIndentSize(t);
      cur.deleteText(numberOfCharacters: indentSize);
    }
  }

  void unindent() {
    if (hasSelection()) {
      List<Block> blocks = selectedBlocks();
      blocks = blocks.toSet().toList();
      for (final b in blocks) {
        Cursor c = copy();
        c.block = b;
        c.moveCursorToStartOfLine();
        c._unindent();
      }
      return;
    }
    _unindent();
  }
}
