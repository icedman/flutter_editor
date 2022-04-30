import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:highlight/src/mode.dart';
import 'package:path/path.dart' as _path;

import 'package:editor/editor/cursor.dart';
import 'package:editor/editor/history.dart';
import 'package:editor/services/highlight/highlighter.dart';
import 'package:editor/services/ffi/bridge.dart';

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

  dynamic mode; // flutter_highlight << remove soon
  String className = '';
  String prevBlockClass = '';

  ValueNotifier notifier = ValueNotifier(0);
  bool _notifier = true;
  Timer? disposeTimer;

  void listen() {
    // if (document?.largeDoc ?? false) return;
    if (disposeTimer != null) {
      disposeTimer?.cancel();
      disposeTimer = null;
    }
    if (!_notifier) {
      notifier = ValueNotifier(0);
      _notifier = true;
    }
  }

  void dispose() {
    // when to call this
    if (_notifier) {
      notifier.dispose();
      _notifier = false;
    }
  }

  void tryDispose() {
    if (disposeTimer != null) {
      disposeTimer?.cancel();
    }
    disposeTimer = Timer(const Duration(milliseconds: 1500), dispose);
  }

  void makeDirty({bool highlight = false, bool notify = true}) {
    mode = null;
    spans = null;
    carets = [];

    if (notify) {
      listen();
    }

    if (highlight) {
      prevBlockClass = '';
      decors = null;
      brackets = [];
      if (notify) {
        Future.delayed(const Duration(milliseconds: 0), () {
          notifier.value++;
        });
      }
      return;
    }

    // notify immediately
    if (notify) {
      notifier.value++;
      if (notifier.value > 0xff) {
        notifier.value = 0;
      }
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
  String tempPath = '';
  String fileName = '';
  String title = '';
  int documentId = 0;
  int langId = 0;

  bool get largeDoc => (blocks.length > 10000);

  // todo.. both these are all over the place
  bool hideGutter = false;
  bool hideMinimap = false;

  int scrollToOnLoad = -1;

  List<Block> blocks = [];
  List<Cursor> cursors = [];

  List<Cursor> folds = [];
  List<Cursor> extraCursors = [];
  List<Cursor> sectionCursors = [];
  Map<String, List<Function?>> listeners = {};
  Map<String, LineDecorator> decorators = {};

  String tabString = '    ';
  int detectedTabSpaces = 0;
  bool enableAutoIndent = true;
  bool enableAutoClose = true;

  String lineComment = '';
  List<String> blockComment = [];

  History history = History();

  Document({String path = ''}) {
    documentId = _documentId++;

    if (path != '') {
      docPath = _path.normalize(Directory(path).absolute.path);
      fileName = _path.basename(path);
    }

    listeners['onCreate']?.forEach((l) {
      l?.call(documentId);
    });

    clear();
  }

  void dispose() {
    listeners['onDestroy']?.forEach((l) {
      l?.call(documentId);
    });

    for (final b in blocks) {
      b.tryDispose();
    }
  }

  void addListener(String event, Function? func) {
    listeners[event] = listeners[event] ?? [];
    listeners[event]?.add(func);
  }

  void removeListener(String event, Function? func) {
    // !todo
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
    docPath = _path.normalize(Directory(path).absolute.path);
    fileName = _path.basename(path);
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
        block.originalLine = blocks.length;
        // block.originalText = l;
        if (blocks.length < 100) {
          int c = countIndentSize(l);
          if (c > 0 && (c < detectedTabSpaces || detectedTabSpaces == 0)) {
            detectedTabSpaces = c;
          }
        }

        blocks.add(block);
      });
    } catch (err, msg) {
      //
    }

    if (detectedTabSpaces > 0) {
      tabString = List.generate(detectedTabSpaces, (_) => ' ').join();
    }
    if (tabString == '') {
      tabString = '  ';
      detectedTabSpaces = 2;
    }

    updateLineNumbers(0);

    for (int i = 0; i < blocks.length; i++) {
      blocks[i].makeDirty(highlight: true, notify: false);
      FFIBridge.setBlock(documentId, blocks[i].blockId, i, blocks[i].text);      
    }

    FFIBridge.runTreeSitter(documentId, docPath);
    
    if (blocks.isEmpty) {
      clear();
    }

    cursor();
    moveCursorToStartOfDocument();

    listeners['onReady']?.forEach((l) {
      l?.call();
    });

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
    for (final cur in cursors) {
      cur.block?.makeDirty();
    }
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
    history.commit();
  }

  void undo() {
    history.undo(this);
  }

  void redo() {
    history.redo(this);
  }

  void addCursor() {
    cursors.add(cursor().copy());
  }

  Block? blockAtLine(int index) {
    if (index < 0 || index >= blocks.length) {
      return null;
    }
    if (index > 0) {
      blocks[index].previous = blocks[index - 1];
    }
    if (index < blocks.length - 1) {
      blocks[index].next = blocks[index + 1];
    }
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

    listeners['onAddBlock']?.forEach((l) {
      l?.call(documentId, block.blockId, block.line);
    });

    history.add(block);
    return block;
  }

  Block? removeBlockAtLine(int index) {
    Block? block = blockAtLine(index);
    Block? previous = blockAtLine(index - 1);
    Block? next = blockAtLine(index + 1);
    blocks.removeAt(index);
    block?.tryDispose();
    previous?.next = next;
    next?.previous = previous;
    updateLineNumbers(index);

    if (block != null) {
      listeners['onRemoveBlock']?.forEach((l) {
        l?.call(documentId, block.blockId, block.line);
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

  void moveCursorPreviousLine({bool keepAnchor = false}) {
    cursors.forEach((c) {
      c.moveCursorPreviousLine(keepAnchor: keepAnchor);
    });
  }

  void moveCursorNextLine({bool keepAnchor = false}) {
    cursors.forEach((c) {
      c.moveCursorNextLine(keepAnchor: keepAnchor);
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

  void toggleComment() {
    cursors.forEach((c) {
      c.toggleComment();
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

  void selectionToLowerCase() {
    cursors.forEach((c) {
      c.selectionToLowerCase();
    });
  }

  void selectionToUpperCase() {
    cursors.forEach((c) {
      c.selectionToUpperCase();
    });
  }

  void backspace() {
    cursors.forEach((c) {
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

  void autoClose(Map<String, String> map) {
    if (!enableAutoClose) return;
    cursors.forEach((c) {
      c.autoClose(map);
    });
  }

  void eraseDuplicateClose(String close) {
    if (!enableAutoClose) return;
    cursors.forEach((c) {
      c.eraseDuplicateClose(close);
    });
  }

  void autoIndent() {
    if (!enableAutoIndent) return;
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

  Cursor? find(Cursor cur, String s,
      {int direction = 1,
      bool regex = false,
      bool caseSensitive = false,
      bool repeat = false}) {
    RegExp _wordRegExp = RegExp(
      s,
      caseSensitive: caseSensitive,
      multiLine: false,
    );

    if (!caseSensitive && !regex) {
      s = s.toLowerCase();
    }

    Block? block = cur.block;
    while (block != null) {
      String t = block.text;
      if (!caseSensitive && !regex) {
        t = t.toLowerCase();
      }

      Cursor _cur = cur.normalized();
      int col = (direction == 1) ? _cur.column : _cur.anchorColumn;
      int l = s.length;
      String left = safeSubstring(t, 0, col);
      String right = safeSubstring(t, col);
      String source = (direction == 1 ? right : left);
      int start = (direction == 1 ? left : right).length;

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
        idx = source.indexOf(s);
      }

      // found
      if (idx != -1) {
        idx += start;
        Cursor res = cur.copy();
        res.anchorColumn = idx;
        res.anchorBlock = block;
        res.column = idx + l;
        res.block = block;
        return res;
      }

      if (direction == 1) {
        if (block.next == null) {
          break;
        }
        cur.moveCursorNextLine();
      } else {
        if (block.previous == null) {
          break;
        }
        cur.moveCursorPreviousLine();
        cur.moveCursorToEndOfLine();
      }

      block = cur.block;
    }

    if (repeat) {
      if (direction == 1) {
        cur.moveCursorToStartOfDocument();
      } else {
        cur.moveCursorToEndOfDocument();
      }
      return find(cur, s,
          direction: direction,
          regex: regex,
          caseSensitive: caseSensitive,
          repeat: false);
    }

    return null;
  }

  void makeDirty({bool highlight = false, bool notify = false}) {
    for (final b in blocks) {
      b.makeDirty(highlight: highlight, notify: notify);
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
  int visibleStart = -1;
  int visibleEnd = -1;

  bool softWrap = true;
  bool showGutter = true;
  bool showMinimap = true;
  bool ready = false;
  bool pinned = false;
  bool overwriteMode = false;

  Offset scrollOffset = Offset.zero;
  Offset offsetForCaret = Offset.zero;
  Size scrollAreaSize = Size.zero;

  Future<bool> openFile(String path) async {
    doc.openFile(path).then((r) {
      ready = true;
      notifyListeners();
    });
    return true;
  }

  void touch() {
    print('warning.. minimize use of this');
    notifyListeners();
  }

  void _makeDirty() {
    DocumentProvider doc = this;
    Document d = doc.doc;

    List<Block> sel = d.selectedBlocks();
    for (final s in sel) {
      s.makeDirty();
    }
    for (final c in d.cursors) {
      c.block?.makeDirty();
      c.anchorBlock?.makeDirty();
    }

    for (final f in d.folds) {
      f.anchorBlock?.makeDirty();
    }
  }

  void begin() {
    _makeDirty();
    doc.begin();
  }

  void commit() {
    doc.commit();
  }

  void command(String cmd,
      {dynamic params, List<Block>? modifiedBlocks}) async {
    DocumentProvider doc = this;
    Document d = doc.doc;
    Cursor cursor = d.cursor().copy();

    bool doScroll = false;
    bool didInputText = false;

    switch (cmd) {
      case 'cancel':
        d.clearCursors();
        doScroll = true;
        break;

      case 'undo':
        d.undo();
        doScroll = true;
        d.begin();
        touch();
        break;

      case 'redo':
        d.redo();
        doScroll = true;
        d.begin();
        touch();
        break;

      case 'insert':
        d.insertText(params);
        doScroll = true;
        didInputText = true;
        break;

      case 'enter':
        d.deleteSelectedText();
        d.insertNewLine();
        doScroll = true;
        break;

      case 'backspace':
        if (d.cursor().hasSelection()) {
          d.deleteSelectedText();
        } else {
          d.backspace();
        }
        doScroll = true;
        break;
      case 'delete':
        if (d.cursor().hasSelection()) {
          d.deleteSelectedText();
        } else {
          d.deleteText();
        }
        doScroll = true;
        break;

      case 'cursor':
        {
          int x = params[1];
          int y = params[0];
          d.moveCursor(y, x);
          doScroll = true;
          break;
        }
      case 'shift+cursor':
        {
          int x = params[1];
          int y = params[0];
          d.moveCursor(y, x, keepAnchor: true);
          doScroll = true;
          _makeDirty();
          break;
        }

      case 'toggle_fold':
        d.toggleFold();
        doScroll = true;
        break;
      case 'unfold_all':
        d.unfoldAll();
        doScroll = true;
        break;

      // todo ... cmd!
      case 'left':
        d.moveCursorLeft();
        doScroll = true;
        break;
      case 'ctrl+left':
        d.moveCursorPreviousWord();
        doScroll = true;
        break;
      case 'ctrl+shift+left':
        d.moveCursorPreviousWord(keepAnchor: true);
        doScroll = true;
        break;
      case 'shift+left':
        d.moveCursorLeft(keepAnchor: true);
        doScroll = true;
        break;

      case 'right':
        d.moveCursorRight();
        doScroll = true;
        break;
      case 'ctrl+right':
        d.moveCursorNextWord();
        doScroll = true;
        break;
      case 'ctrl+shift+right':
        d.moveCursorNextWord(keepAnchor: true);
        doScroll = true;
        break;
      case 'shift+right':
        d.moveCursorRight(keepAnchor: true);
        doScroll = true;
        break;

      case 'up':
        d.cursor().moveCursorUp();
        doScroll = true;
        break;
      case 'ctrl+up':
        d.addCursor();
        d.cursor().moveCursorUp();
        doScroll = true;
        break;
      case 'shift+up':
        d.moveCursorUp(keepAnchor: true);
        doScroll = true;
        break;

      case 'down':
        d.moveCursorDown();
        doScroll = true;
        break;
      case 'ctrl+down':
        d.addCursor();
        d.cursor().moveCursorDown();
        doScroll = true;
        break;
      case 'shift+down':
        d.moveCursorDown(keepAnchor: true);
        doScroll = true;
        break;

      case 'home':
        d.moveCursorToStartOfLine();
        doScroll = true;
        break;
      case 'shift+home':
        d.moveCursorToStartOfLine(keepAnchor: true);
        doScroll = true;
        break;
      case 'ctrl+shift+home':
        d.moveCursorToStartOfDocument(keepAnchor: true);
        doScroll = true;
        break;
      case 'ctrl+home':
        d.moveCursorToStartOfDocument();
        doScroll = true;
        break;
      case 'end':
        d.moveCursorToEndOfLine();
        doScroll = true;
        break;
      case 'shift+end':
        d.moveCursorToEndOfLine(keepAnchor: true);
        doScroll = true;
        break;
      case 'ctrl+end':
        d.moveCursorToEndOfDocument();
        doScroll = true;
        break;
      case 'ctrl+shift+end':
        d.moveCursorToEndOfDocument(keepAnchor: true);
        doScroll = true;
        break;
      case 'tab':
        d.insertText(d.tabString);
        doScroll = true;
        break;

      case 'toggle_comment':
        d.toggleComment();
        break;

      case 'indent':
        d.indent();
        break;

      case 'unindent':
        d.unindent();
        break;

      case 'selection_to_lower_case':
        d.selectionToLowerCase();
        break;

      case 'selection_to_upper_case':
        d.selectionToUpperCase();
        break;

      case 'copy':
        Clipboard.setData(ClipboardData(text: d.selectedText()));
        break;
      case 'cut':
        {
          if (!d.hasSelection()) {
            d.selectLine();
            Clipboard.setData(ClipboardData(text: d.selectedText()));
            d.deleteSelectedText();
            d.deleteText();
            break;
          }
          Clipboard.setData(ClipboardData(text: d.selectedText()));
          d.deleteSelectedText();
          doScroll = true;
          break;
        }
      case 'paste':
        {
          bool _enableAutoIndent = d.enableAutoIndent;
          d.enableAutoIndent = false;
          Future.delayed(const Duration(milliseconds: 100), () {
            d.enableAutoIndent = _enableAutoIndent;
          });
          Clipboard.getData('text/plain').then((data) {
            if (data == null) return;
            List<String> lines = (data.text ?? '').split('\n');
            int idx = 0;
            d.begin();
            for (String l in lines) {
              if (idx++ > 0) {
                d.insertNewLine();
              }
              d.insertText(l);
            }
            d.commit();
          });
          didInputText = true;
          doScroll = true;
          break;
        }
      case 'save':
        d.saveFile();
        break;

      case 'select_all':
        d.moveCursorToStartOfDocument();
        d.moveCursorToEndOfDocument(keepAnchor: true);
        for (final b in d.blocks) {
          b.makeDirty();
        }
        break;

      case 'select_word':
        {
          if (d.cursor().hasSelection()) {
            Cursor cur = d.cursor().findText(d.cursor().selectedText());
            if (!cur.isNull) {
              d.addCursor();
              d.cursor().copyFrom(cur, keepAnchor: true);
            }
          } else {
            d.selectWord();
            d.cursor().block?.makeDirty();
          }

          // Cursor cur = d.cursor().normalized();
          // bool? _hasScope = cur.block?.scopes.containsKey(cur.anchorColumn);
          // bool hasScope = _hasScope ?? false;
          // if (hasScope) {
          //   print(cur.block?.scopes[cur.anchorColumn]);
          // }

          doScroll = true;
          break;
        }

      case 'select_line':
        d.selectLine();
        doScroll = true;
        break;

      case 'duplicate_selection':
        if (!d.hasSelection()) {
          d.duplicateLine();
        } else {
          Cursor cur = d.cursor().copy();
          d.duplicateSelection();
          d.cursor()
            ..anchorBlock = cur.block
            ..anchorColumn = cur.column;
        }
        doScroll = true;
        break;

      default:
        // print('unhandled command: $cmd');
        break;
    }

    // todo touch only changed blocks

    // cursor moved
    // rebuild bracket match
    d.extraCursors = [];
    d.sectionCursors = [];
    Cursor newCursor = d.cursor();
    if (cursor.block != newCursor.block || cursor.column != newCursor.column) {
      // bracket pair
      Future.delayed(const Duration(milliseconds: 5), () {
        BlockBracket b = d.brackedUnderCursor(newCursor, openOnly: true);
        final res = d.findBracketPair(b);
        if (res.length == 2) {
          for (int i = 0; i < 2; i++) {
            Cursor c = d.cursor().copy();
            c.block = res[i].block;
            c.column = res[i].position;
            c.color = Colors.white.withOpacity(0.7);
            d.extraCursors.add(c);
          }
        }
      });
      // closing bracket pair
      Future.delayed(const Duration(milliseconds: 10), () {
        BlockBracket b = d.findUnclosedBracket(newCursor);
        final res = d.findBracketPair(b);
        if (res.length == 2) {
          for (int i = 0; i < 2; i++) {
            Cursor c = d.cursor().copy();
            c.block = res[i].block;
            c.column = res[i].position;
            c.color = Colors.yellow.withOpacity(0.7);
            d.sectionCursors.add(c);
          }
        }
      });
    }

    if (didInputText && modifiedBlocks != null) {
      for (final a in d.history.actions) {
        if (!modifiedBlocks.contains(a.block)) {
          modifiedBlocks.add(a.block!);
        }
      }
    }

    if (doScroll) {
      scrollToLine(d.cursor().block?.line ?? -1);
      // if (d.largeDoc) {
      //   touch();
      // }
    }
  }

  void scrollToLine(int line) {
    if (line != scrollTo) {
      scrollTo = line;
      if (line - 4 < visibleStart || line + 4 > visibleEnd) {
        notifyListeners();
      }
    }
  }
}
