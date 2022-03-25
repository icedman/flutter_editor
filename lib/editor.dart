import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:editor/caret.dart';
import 'package:editor/cursor.dart';
import 'package:editor/document.dart';
import 'package:editor/view.dart';
import 'package:editor/input.dart';
import 'package:editor/minimap.dart';
import 'package:editor/services/highlight/highlighter.dart';

class Editor extends StatefulWidget {
  Editor({Key? key, String this.path = ''}) : super(key: key);
  String path = '';
  @override
  _Editor createState() => _Editor();
}

class _Editor extends State<Editor> {
  late DocumentProvider doc;
  late Highlighter highlighter;

  bool shifting = false;
  bool controlling = false;

  @override
  void initState() {
    highlighter = Highlighter();
    doc = DocumentProvider();
    doc.openFile(widget.path);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _buildKeys(String keys, {bool control: false, bool shift: false}) {
    String res = '';

    keys = keys.toLowerCase();

    // morph
    if (keys == '\n' || keys == 'enter') {
      keys = 'newline';
    }
    if (keys.startsWith('arrow')) {
      keys = keys.substring(6);
    }
    if (keys == 'space') {
      keys = ' ';
    }

    if (control) {
      res = 'ctrl';
    }
    if (shift) {
      if (res != '') res += '+';
      res += 'shift';
    }
    if (res != '') res += '+';
    res += keys;
    return res;
  }

  void onShortcut(String keys) {
    String cmd = keys;
    switch (keys) {
      case 'ctrl+c':
        cmd = 'copy';
        break;
      case 'ctrl+x':
        cmd = 'cut';
        break;
      case 'ctrl+v':
        cmd = 'paste';
        break;
      case 'ctrl+a':
        cmd = 'select_all';
        break;
      case 'ctrl+d':
        cmd = 'select_word';
        break;
      case 'ctrl+l':
        cmd = 'select_line';
        break;
      case 'ctrl+s':
        cmd = 'save';
        break;
      case 'ctrl+w':
        cmd = 'settings_toggle_wrap';
        break;
      case 'ctrl+g':
        cmd = 'settings_toggle_gutter';
        break;
      case 'ctrl+m':
        cmd = 'settings_toggle_minimap';
        break;
    }
    command(cmd);
  }

  void _makeDirty() {
    Document d = doc.doc;

    List<Block> sel = d.selectedBlocks();
    for (final s in sel) {
      s.makeDirty();
    }
    for (final c in d.cursors) {
      c.block?.makeDirty();
      c.anchorBlock?.makeDirty();
    }
  }

  void command(String cmd, {List<String> params = const <String>[]}) async {
    bool doScroll = false;
    Document d = doc.doc;

    _makeDirty();

    switch (cmd) {
      case 'cancel':
        d.clearCursors();
        break;

      case 'insert':
        d.insertText(params[0]);
        doScroll = true;
        break;

      case 'newline':
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
      case 'settings_toggle_wrap':
        doc.softWrap = !doc.softWrap;
        doScroll = true;
        break;
      case 'tab':
        d.insertText('    ');
        doScroll = true;
        break;

      case 'settings_toggle_gutter':
        doc.showGutters = !doc.showGutters;
        doScroll = true;
        break;
      case 'settings_toggle_minimap':
        doc.showMinimap = !doc.showMinimap;
        doScroll = true;
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
          ClipboardData? data = await Clipboard.getData('text/plain');
          if (data == null) return;
          List<String> lines = (data.text ?? '').split('\n');
          int idx = 0;
          lines.forEach((l) {
            if (idx++ > 0) {
              d.insertNewLine();
            }
            d.insertText(l);
          });
          doScroll = true;
          break;
        }
      case 'save':
        d.saveFile();
        break;
      case 'select_all':
        d.moveCursorToStartOfDocument();
        d.moveCursorToEndOfDocument(keepAnchor: true);
        doScroll = true;
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
          doScroll = true;
          break;
        }
      case 'select_line':
        d.selectLine();
        doScroll = true;
        break;
    }

    if (doScroll) {
      doc.scrollTo = d.cursor().block?.line ?? -1;
      doc.touch();
    }
  }

  void onKeyDown(String key,
      {int keyId = 0,
      bool shift = false,
      bool control = false,
      bool softKeyboard = false}) {
    shifting = shift;
    controlling = control;
    Document d = doc.doc;

    switch (key) {
      case 'Escape':
        command('cancel');
        return;

      case 'Arrow Left':
      case 'Arrow Right':
      case 'Arrow Up':
      case 'Arrow Down':
      case 'Backspace':
      case 'Delete':
      case 'Tab':
      case 'Home':
      case 'End':
      case 'Enter':
      case '\n':
        command(_buildKeys(key, control: control, shift: shift));
        break;
      default:
        {
          int k = keyId;
          if ((k >= LogicalKeyboardKey.keyA.keyId &&
                  k <= LogicalKeyboardKey.keyZ.keyId) ||
              (k + 32 >= LogicalKeyboardKey.keyA.keyId &&
                  k + 32 <= LogicalKeyboardKey.keyZ.keyId)) {
            String ch =
                String.fromCharCode(97 + k - LogicalKeyboardKey.keyA.keyId);
            if (control) {
              onShortcut(_buildKeys(ch, control: true, shift: shift));
              break;
            }
            command('insert', params: [ ch ]);
            break;
          }
        }
        if (key.length == 1 || softKeyboard) {
          command('insert', params: [ key ]);
        }
        break;
    }
  }

  void onKeyUp() {
    shifting = false;
    controlling = false;
  }

  void onTapDown(RenderObject? obj, Offset globalPosition) {
    _makeDirty();
    Document d = doc.doc;
    Offset o = screenToCursor(obj, globalPosition);
    // todo
    d.moveCursor(o.dy.toInt(), o.dx.toInt(), keepAnchor: shifting);
    doc.scrollTo = d.cursor().block?.line ?? -1;
    doc.touch();
  }

  void onDoubleTapDown(RenderObject? obj, Offset globalPosition) {
    Document d = doc.doc;
    Offset o = screenToCursor(obj, globalPosition);
    // todo
    d.moveCursor(o.dy.toInt(), o.dx.toInt(), keepAnchor: shifting);
    command('select_word');
    doc.scrollTo = d.cursor().block?.line ?? -1;
    doc.touch();
  }

  void onPanUpdate(RenderObject? obj, Offset globalPosition) {
    _makeDirty();
    Document d = doc.doc;
    Offset o = screenToCursor(obj, globalPosition);
    if (o.dx == -1 || o.dy == -1) return;
    // todo
    d.moveCursor(o.dy.toInt(), o.dx.toInt(), keepAnchor: true);
    doc.scrollTo = d.cursor().block?.line ?? -1;
    doc.touch();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => doc),
        ChangeNotifierProvider(create: (context) => CaretPulse()),
        Provider(create: (context) => highlighter),
      ],
      child: Row(children: [
        Expanded(
            child: InputListener(
          child: View(),
          onKeyDown: onKeyDown,
          onKeyUp: onKeyUp,
          onTapDown: onTapDown,
          onDoubleTapDown: onDoubleTapDown,
          onPanUpdate: onPanUpdate,
        )),
        Container(width: 100, child: Minimap())
      ]),
    );
  }
}
