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
import 'package:editor/services/highlighter.dart';

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

  void command(String cmd, {List<String> params = const <String>[]}) async {
    bool doScroll = false;
    Document d = doc.doc;
    switch (cmd) {
      case 'ctrl+w':
        doc.softWrap = !doc.softWrap;
        doc.touch();
        break;
      case 'ctrl+e':
        doc.showGutters = !doc.showGutters;
        doc.touch();
        break;
      case 'ctrl+c':
        Clipboard.setData(ClipboardData(text: d.selectedText()));
        break;
      case 'ctrl+x':
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
          break;
        }
      case 'ctrl+v':
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
          break;
        }
      case 'ctrl+s':
        d.saveFile();
        break;
      case 'ctrl+a':
        d.moveCursorToStartOfDocument();
        d.moveCursorToEndOfDocument(keepAnchor: true);
        doScroll = true;
        break;
      case 'ctrl+d':
        {
          if (d.cursor().hasSelection()) {
            Cursor cur = d.cursor().findText(d.cursor().selectedText());
            if (!cur.isNull) {
              d.addCursor();
              d.cursor().copyFrom(cur, keepAnchor: true);
              doScroll = true;
            }
          } else {
            d.selectWord();
          }
          break;
        }
    }

    if (doScroll) {
      doc.scrollTo = d.cursor().block?.line ?? -1;
    }
    doc.touch();
  }

  void onKeyDown(String key,
      {int keyId = 0,
      bool shift = false,
      bool control = false,
      bool softKeyboard = false}) {
    shifting = shift;
    controlling = control;
    Document d = doc.doc;
    bool doScroll = true;

    switch (key) {
      case 'Escape':
        d.clearCursors();
        break;
      case 'Home':
        if (control) {
          d.moveCursorToStartOfDocument(keepAnchor: shifting);
        } else {
          d.moveCursorToStartOfLine(keepAnchor: shifting);
        }
        break;
      case 'End':
        if (control) {
          d.moveCursorToEndOfDocument(keepAnchor: shifting);
        } else {
          d.moveCursorToEndOfLine(keepAnchor: shifting);
        }
        break;
      case 'Tab':
        d.insertText('    ');
        break;
      case '\n':
      case 'Enter':
        d.deleteSelectedText();
        d.insertNewLine();
        break;
      case 'Backspace':
        if (d.cursor().hasSelection()) {
          d.deleteSelectedText();
        } else {
          d.backspace();
        }
        break;
      case 'Delete':
        if (d.cursor().hasSelection()) {
          d.deleteSelectedText();
        } else {
          d.deleteText();
        }
        break;
      case 'Arrow Left':
        d.moveCursorLeft(keepAnchor: shift);
        break;
      case 'Arrow Right':
        d.moveCursorRight(keepAnchor: shift);
        break;
      case 'Arrow Up':
        if (control) {
          d.addCursor();
          d.cursor().moveCursorUp();
        } else {
          d.moveCursorUp(keepAnchor: shift);
        }
        break;
      case 'Arrow Down':
        if (control) {
          d.addCursor();
          d.cursor().moveCursorDown();
        } else {
          d.moveCursorDown(keepAnchor: shift);
        }
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
              command('ctrl+$ch');
              doScroll = false;
              break;
            }
            d.insertText(ch);
            break;
          }
        }
        if (key.length == 1 || softKeyboard) {
          d.insertText(key);
        }
        break;
    }
    if (doScroll) {
      doc.scrollTo = d.cursor().block?.line ?? -1;
    }
    doc.touch();
  }

  void onKeyUp() {
    shifting = false;
    controlling = false;
  }

  void onTapDown(RenderObject? obj, Offset globalPosition) {
    Document d = doc.doc;
    Offset o = screenToCursor(obj, globalPosition);
    d.moveCursor(o.dy.toInt(), o.dx.toInt(), keepAnchor: shifting);
    doc.scrollTo = d.cursor().block?.line ?? -1;
    doc.touch();

    List<Block> blocks = d.selectedBlocks();
    for (final b in blocks) {
      b.spans = null;
    }
  }

  void onDoubleTapDown(RenderObject? obj, Offset globalPosition) {
    Document d = doc.doc;
    Offset o = screenToCursor(obj, globalPosition);
    d.moveCursor(o.dy.toInt(), o.dx.toInt(), keepAnchor: shifting);
    d.selectWord();
    doc.touch();
  }

  void onPanUpdate(RenderObject? obj, Offset globalPosition) {
    Document d = doc.doc;
    Offset o = screenToCursor(obj, globalPosition);
    if (o.dx == -1 || o.dy == -1) return;
    d.moveCursor(o.dy.toInt(), o.dx.toInt(), keepAnchor: true);
    doc.scrollTo = d.cursor().block?.line ?? -1;
    doc.touch();

    List<Block> blocks = d.selectedBlocks();
    for (final b in blocks) {
      b.spans = null;
    }
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
