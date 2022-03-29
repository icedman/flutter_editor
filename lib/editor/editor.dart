import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:editor/editor/decorations.dart';
import 'package:editor/editor/cursor.dart';
import 'package:editor/editor/document.dart';
import 'package:editor/editor/view.dart';
import 'package:editor/services/input.dart';
import 'package:editor/minimap/minimap.dart';
import 'package:editor/services/highlight/theme.dart';
import 'package:editor/services/highlight/highlighter.dart';

class Editor extends StatefulWidget {
  Editor({Key? key, String this.path = ''}) : super(key: key);
  String path = '';
  @override
  _Editor createState() => _Editor();
}

class _Editor extends State<Editor> with WidgetsBindingObserver {
  late DocumentProvider doc;
  late Highlighter highlighter;

  bool _isKeyboardVisible =
      WidgetsBinding.instance!.window.viewInsets.bottom > 0.0;

  bool shifting = false;
  bool controlling = false;
  bool alting = false;
  bool showKeyboard = false;

  @override
  void initState() {
    highlighter = Highlighter();
    doc = DocumentProvider();
    doc.openFile(widget.path);

    doc.doc.langId = highlighter.engine.loadLanguage(widget.path).langId;
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance!.window.viewInsets.bottom;
    final newValue = bottomInset > 0.0;
    if (newValue != _isKeyboardVisible) {
      setState(() {
        _isKeyboardVisible = newValue;
      });
    }
  }

  String _buildKeys(String keys,
      {bool control: false, bool shift: false, bool alt: false}) {
    String res = '';

    keys = keys.toLowerCase();

    // morph
    if (keys == 'escape') {
      keys = 'cancel';
    }
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
    if (alt) {
      if (res != '') res += '+';
      res += 'alt';
    }
    if (res != '') res += '+';
    res += keys;

    return res;
  }

  void onShortcut(String keys) {
    String cmd = keys;
    switch (keys) {
      case 'ctrl+z':
        cmd = 'undo';
        break;

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

      case 'ctrl+alt+[':
        cmd = 'fold';
        break;
      case 'ctrl+alt+]':
        cmd = 'unfold';
        break;

      case 'ctrl+w':
        cmd = 'settings-toggle-wrap';
        break;
      case 'ctrl+g':
        cmd = 'settings-toggle-gutter';
        break;
      case 'ctrl+m':
        cmd = 'settings-toggle-minimap';
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

    for (final f in d.folds) {
      f.anchorBlock?.makeDirty();
    }
  }

  void command(String cmd, {List<String> params = const <String>[]}) async {
    bool doScroll = false;
    bool didInputText = false;
    Document d = doc.doc;

    Cursor cursor = d.cursor().copy();

    _makeDirty();

    d.begin();

    switch (cmd) {
      case 'cancel':
        d.clearCursors();
        doScroll = true;
        break;

      case 'undo':
        d.undo();
        doScroll = true;
        d.begin(); // erase pending history writes
        break;

      case 'insert':
        d.insertText(params[0]);
        doScroll = true;
        didInputText = true;
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

      case 'cursor':
        {
          String x = params[1];
          String y = params[0];
          d.moveCursor(int.parse(y), int.parse(x));
          doScroll = true;
          break;
        }
      case 'shift+cursor':
        {
          String x = params[1];
          String y = params[0];
          d.moveCursor(int.parse(y), int.parse(x), keepAnchor: true);
          doScroll = true;
          _makeDirty();
          break;
        }

      case 'fold':
        d.toggleFold();
        doScroll = true;
        break;
      case 'unfold':
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
        d.insertText('    ');
        doScroll = true;
        break;

      case 'settings-toggle-wrap':
        doc.softWrap = !doc.softWrap;
        // doScroll = true;
        doc.touch();
        break;

      case 'settings-toggle-gutter':
        doc.showGutters = !doc.showGutters;
        // doScroll = true;
        doc.touch();
        break;
      case 'settings-toggle-minimap':
        doc.showMinimap = !doc.showMinimap;
        // doScroll = true;
        doc.touch();
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
        doc.touch();
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

          Cursor cur = d.cursor().normalized();
          bool? _hasScope = cur.block?.scopes.containsKey(cur.anchorColumn);
          bool hasScope = _hasScope ?? false;
          if (hasScope) {
            print(cur.block?.scopes[cur.anchorColumn]);
          }
          doScroll = true;
          break;
        }
      case 'select_line':
        d.selectLine();
        doScroll = true;
        break;
    }

    // cursor moved
    // rebuild bracket match
    d.extraCursors = [];
    d.sectionCursors = [];
    Cursor newCursor = d.cursor();
    if (cursor.block != newCursor.block || cursor.column != newCursor.column) {
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
          doc.touch();
        }
      });
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
          doc.touch();
        }
      });
    }

    if (doScroll) {
      doc.scrollTo = d.cursor().block?.line ?? -1;
      doc.touch();
    }

    d.commit();

    if (didInputText) {
      Future.delayed(const Duration(milliseconds: 50), () {
        Cursor cur = d.cursor().copy();
        cur.moveCursorLeft();
        cur.selectWord();
        if (cur.column == d.cursor().column) {
          String t = cur.selectedText();
          d.findMatches(t).then((r) {
            // print(r);
          });
        }
      });
    }
  }

  void onKeyDown(String key,
      {int keyId = 0,
      bool shift = false,
      bool control = false,
      bool alt = false,
      bool softKeyboard = false}) {
    if (!softKeyboard) {
      shifting = shift;
      controlling = control;
      alting = alt;
    }

    // print('$softKeyboard $key ${key.length} ${controlling}');

    Document d = doc.doc;

    switch (key) {
      case 'Escape':
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
        command(_buildKeys(key,
            control: controlling, shift: shifting, alt: alting));
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
            if (control || alt) {
              onShortcut(_buildKeys(ch,
                  control: controlling, shift: shifting, alt: alting));
              break;
            }
            command('insert', params: [ch]);
            break;
          }
        }
        if (key.length == 1 || softKeyboard) {
          if (controlling || alting) {
            onShortcut(_buildKeys(key,
                control: controlling, shift: shifting, alt: alting));
          } else {
            command('insert', params: [key]);
          }
        }
        break;
    }
  }

  void onKeyUp() {
    if (shifting || controlling || alting) {
      setState(() {
        shifting = false;
        controlling = false;
        alting = false;
      });
    }
  }

  void onTapDown(RenderObject? obj, Offset globalPosition) {
    Document d = doc.doc;
    Offset o = screenToCursor(obj, globalPosition);
    if (shifting) {
      command('shift+cursor',
          params: [o.dy.toInt().toString(), o.dx.toInt().toString()]);
    } else {
      command('cursor',
          params: [o.dy.toInt().toString(), o.dx.toInt().toString()]);
    }
  }

  void onDoubleTapDown(RenderObject? obj, Offset globalPosition) {
    Document d = doc.doc;
    Offset o = screenToCursor(obj, globalPosition);
    d.moveCursor(o.dy.toInt(), o.dx.toInt(), keepAnchor: shifting);
    command('cursor',
        params: [o.dy.toInt().toString(), o.dx.toInt().toString()]);
    command('select_word');
  }

  void onPanUpdate(RenderObject? obj, Offset globalPosition) {
    Document d = doc.doc;
    Offset o = screenToCursor(obj, globalPosition);
    if (o.dx == -1 || o.dy == -1) return;
    command('shift+cursor',
        params: [o.dy.toInt().toString(), o.dx.toInt().toString()]);
  }

  @override
  Widget build(BuildContext context) {
    HLTheme theme = Provider.of<HLTheme>(context);
    double buttonSize = 16.0;
    Color clr = theme.foreground;
    Color hiColor = theme.selection;

    List<Widget> buttons = <Widget>[
      IconButton(
          icon: Icon(showKeyboard ? Icons.keyboard_hide : Icons.keyboard,
              size: buttonSize, color: clr),
          onPressed: () {
            setState(() {
              showKeyboard = !showKeyboard;
            });
          }),
      IconButton(
          icon: Icon(Icons.undo, size: buttonSize, color: clr),
          onPressed: () {
            command('undo');
          }),
      Container(
          decoration: controlling ? BoxDecoration(color: hiColor) : null,
          child: IconButton(
              icon: Icon(Icons.south_west, size: buttonSize, color: clr),
              onPressed: () {
                setState(() {
                  controlling = !controlling;
                });
              })),
      Container(
          decoration: shifting ? BoxDecoration(color: hiColor) : null,
          child: IconButton(
              icon: Icon(Icons.keyboard_capslock, size: buttonSize, color: clr),
              onPressed: () {
                setState(() {
                  shifting = !shifting;
                });
              })),
      IconButton(
          icon: Icon(Icons.west, size: buttonSize, color: clr),
          onPressed: () {
            command(_buildKeys('left', control: controlling, shift: shifting));
          }),
      IconButton(
          icon: Icon(Icons.north, size: buttonSize, color: clr),
          onPressed: () {
            command(_buildKeys('up', control: controlling, shift: shifting));
          }),
      IconButton(
          icon: Icon(Icons.south, size: buttonSize, color: clr),
          onPressed: () {
            command(_buildKeys('down', control: controlling, shift: shifting));
          }),
      IconButton(
          icon: Icon(Icons.east, size: buttonSize, color: clr),
          onPressed: () {
            command(_buildKeys('right', control: controlling, shift: shifting));
          }),
      IconButton(
          icon: Icon(Icons.keyboard_tab, size: buttonSize, color: clr),
          onPressed: () {
            command('tab');
          }),
      IconButton(
          icon: Icon(Icons.highlight_alt, size: buttonSize, color: clr),
          onPressed: () {
            command('select_word');
          }),
      IconButton(
          icon: Icon(Icons.copy, size: buttonSize, color: clr),
          onPressed: () {
            command('copy');
          }),
      IconButton(
          icon: Icon(Icons.cut, size: buttonSize, color: clr),
          onPressed: () {
            command('cut');
          }),
      IconButton(
          icon: Icon(Icons.paste, size: buttonSize, color: clr),
          onPressed: () {
            command('paste');
          }),
    ];

    return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => doc),
          ChangeNotifierProvider(create: (context) => CaretPulse()),
          Provider(create: (context) => highlighter),
        ],
        child: Column(children: [
          Expanded(
              child: Row(children: [
            Expanded(
              child: InputListener(
                  child: Stack(children: [
                  View(onScroll: (offset) {
                    print(offset);
                    }),

                  // SelectionThumb(), SelectionThumb(anchor: true)
                  
                  ]),
                  onKeyDown: onKeyDown,
                  onKeyUp: onKeyUp,
                  onTapDown: onTapDown,
                  onDoubleTapDown: onDoubleTapDown,
                  onPanUpdate: onPanUpdate,
                  showKeyboard: showKeyboard),
            ),
            Minimap()
          ])),

          if (Platform.isAndroid) ...[
            Container(
                child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: buttons)))
          ], // toolbar
        ]));
  }
}