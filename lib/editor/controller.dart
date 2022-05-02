import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as _path;

import 'package:editor/editor/cursor.dart';
import 'package:editor/editor/block.dart';
import 'package:editor/editor/document.dart';
import 'package:editor/editor/history.dart';
import 'package:editor/services/highlight/highlighter.dart';

class _Notifier extends Notifier {
  ValueNotifier notifier = ValueNotifier(0);
  bool _notifier = true;
  Timer? disposeTimer;
  
  dynamic listenable() {
    init();
    return notifier;
  }

  void _dispose() {
    if (_notifier) {
      notifier.dispose();
      _notifier = false;
    }
  }
  
  void init() {
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
    if (disposeTimer != null) {
      disposeTimer?.cancel();
    }
    disposeTimer = Timer(const Duration(milliseconds: 1500), dispose);
  }
  
  void notify({bool now = true}) {
    if (now) {
      notifier.value++;
      if (notifier.value > 0xff) {
        notifier.value = 0;
      }
      return;
    }
    Future.delayed(const Duration(milliseconds: 0), () {
      notifier.value++;
    });
  }
}

class CodeEditingController extends ChangeNotifier {

  static void configure() {
    Block.createNotifier = () {
      return _Notifier();
    };
    Document.createNotifier = () {
      return _Notifier();
    };
  }
  
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
    Document d = doc;

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
    Document d = doc;
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

class DocumentProvider extends CodeEditingController
{
}
