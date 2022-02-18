import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'document.dart';
import 'view.dart';
import 'input.dart';
import 'highlighter.dart';

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

  void command() {}

  void onKeyDown(String key,
      {int keyId = 0, bool shift = false, bool control = false}) {
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
      case 'Enter':
        d.deleteSelectedText();
        d.insertNewLine();
        break;
      case 'Backspace':
        if (d.cursor().hasSelection()) {
          d.deleteSelectedText();
        } else {
          d.moveCursorLeft();
          d.deleteText();
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
              d.command('ctrl+$ch');
              doScroll = false;
              break;
            }
            d.insertText(ch);
            break;
          }
        }
        if (key.length == 1) {
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
  }

  void onPanUpdate(RenderObject? obj, Offset globalPosition) {
    Document d = doc.doc;
    Offset o = screenToCursor(obj, globalPosition);
    if (o.dx == -1 || o.dy == -1) return;
    d.moveCursor(o.dy.toInt(), o.dx.toInt(), keepAnchor: true);
    doc.scrollTo = d.cursor().block?.line ?? -1;
    doc.touch();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => doc),
          Provider(create: (context) => highlighter)
        ],
        child: InputListener(
          child: View(),
          onKeyDown: onKeyDown,
          onKeyUp: onKeyUp,
          onTapDown: onTapDown,
          onPanUpdate: onPanUpdate,
        ));
  }
}
