import 'dart:async';
import 'dart:io';
import 'package:editor/services/ui/status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:editor/editor/decorations.dart';
import 'package:editor/editor/cursor.dart';
import 'package:editor/editor/document.dart';
import 'package:editor/editor/view.dart';
import 'package:editor/editor/search.dart';
import 'package:editor/services/app.dart';
import 'package:editor/services/ffi/bridge.dart';
import 'package:editor/services/input.dart';
import 'package:editor/minimap/minimap.dart';
import 'package:editor/services/ui/ui.dart';
import 'package:editor/services/ui/menu.dart';
import 'package:editor/services/ui/status.dart';
import 'package:editor/services/highlight/theme.dart';
import 'package:editor/services/highlight/highlighter.dart';
import 'package:editor/services/indexer/indexer.dart';

class Editor extends StatefulWidget {
  Editor({Key? key, String this.path = '', Document? this.document})
      : super(key: key);
  String path = '';
  Document? document;

  @override
  _Editor createState() => _Editor();
}

class _Editor extends State<Editor> with WidgetsBindingObserver {
  late DocumentProvider doc;
  late CaretPulse pulse;
  late DecorInfo decor;
  late Highlighter highlighter;
  late IndexerIsolate indexer;

  bool _isKeyboardVisible =
      WidgetsBinding.instance!.window.viewInsets.bottom > 0.0;

  bool shifting = false;
  bool controlling = false;
  bool alting = false;

  List<Block> indexingQueue = [];

  @override
  void initState() {
    highlighter = Highlighter();
    indexer = IndexerIsolate();
    doc = DocumentProvider();

    if (widget.document != null) {
      doc.doc = widget.document ?? doc.doc;
    }
    // if (widget.path.isNotEmpty) {
    doc.openFile(widget.path);
    // }

    doc.doc.langId = highlighter.engine.loadLanguage(widget.path).langId;

    Document d = doc.doc;
    HLLanguage? lang = highlighter.engine.language(d.langId);
    if (lang != null) {
      d.lineComment = lang.lineComment;
      d.blockComment = lang.blockComment;
    }

    d.addListener('onCreate', (documentId) {
      FFIBridge.run(() => FFIBridge.create_document(documentId));
    });
    d.addListener('onDestroy', (documentId) {
      FFIBridge.run(() => FFIBridge.destroy_document(documentId));
    });
    d.addListener('onAddBlock', (documentId, blockId) {
      FFIBridge.run(() => FFIBridge.add_block(documentId, blockId));
    });
    d.addListener('onRemoveBlock', (documentId, blockId) {
      FFIBridge.run(() => FFIBridge.remove_block(documentId, blockId));
    });
    d.addListener('onInsertText', (text) {
      // print('auto close');
    });
    d.addListener('onInsertNewLine', () {
      d.autoIndent();
    });
    d.addListener('onReady', () {
      Future.delayed(const Duration(seconds: 3), () {
        indexer.indexFile(widget.path);
      });
    });

    decor = DecorInfo();
    pulse = CaretPulse();

    indexer.onResult = (res) {
      UIProvider ui = Provider.of<UIProvider>(context, listen: false);
      UIMenuData? menu = ui.menu('search::${d.documentId}', onSelect: (item) {
        Document d = doc.doc;
        d.begin();
        d.clearCursors();
        d.moveCursorLeft();
        d.selectWord();
        d.insertText(item.title); // todo.. command!
        d.commit();
        doc.notifyListeners();
      });
      menu?.menuIndex = 0;

      dynamic search = res;
      if (search == null) {
        return;
      }

      String _search = search['search'] ?? '';
      dynamic _result = search['result'] ?? [];

      menu?.items.clear();
      for (final s in _result) {
        menu?.items.add(UIMenuData()..title = s);
      }
    };

    super.initState();
    WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void dispose() {
    pulse.cancel();
    indexer.dispose();
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
    if (keys == '\n') {
      keys = 'enter';
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
    UIProvider ui = Provider.of<UIProvider>(context, listen: false);

    String cmd = keys;

    switch (keys) {
      case 'ctrl+f':
        cmd = 'search';
        break;

      case 'ctrl+g':
        cmd = 'jump_to_line';
        break;

      case 'ctrl+z':
        cmd = 'undo';
        break;

      case 'ctrl+]':
        cmd = 'indent';
        break;

      case 'ctrl+[':
        cmd = 'unindent';
        break;

      case 'ctrl+/':
        cmd = 'toggle_comment';
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
      case 'ctrl+shift+d':
        cmd = 'duplicate_selection';
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

      case 'ctrl+shift+w':
        cmd = 'settings-toggle-wrap';
        break;
      case 'ctrl+shift+g':
        cmd = 'settings-toggle-gutter';
        break;
      case 'ctrl+shift+m':
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
    Document d = doc.doc;
    Cursor cursor = d.cursor().copy();

    UIProvider ui = Provider.of<UIProvider>(context, listen: false);
    if (ui.popups.isNotEmpty) {
      UIMenuData? menu = ui.menu('search::${d.documentId}');
      int idx = menu?.menuIndex ?? 0;
      int size = menu?.items.length ?? 0;
      switch (cmd) {
        case 'cancel':
          ui.clearPopups();
          return;
        case 'up':
          if (idx > 0) {
            menu?.menuIndex--;
            ui.notifyListeners();
          }
          return;
        case 'down':
          if (idx + 1 < size) {
            menu?.menuIndex++;
            ui.notifyListeners();
          }
          return;
        case 'enter':
          {
            menu?.select(menu.menuIndex);
            ui.clearPopups();
            return;
          }
      }
    }

    switch (cmd) {
      case 'search':
        {
          ui.setPopup(
            SearchPopup(onSubmit: (text,
                {int direction = 1,
                bool caseSensitive = false,
                bool regex = false,
                String? replace}) {
              Document d = doc.doc;
              Cursor? cur = d.find(d.cursor().copy(), text,
                  direction: direction,
                  regex: regex,
                  caseSensitive: caseSensitive);
              if (cur != null) {
                if (replace != null && d.hasSelection()) {
                  d.insertText(replace);
                }
                d.clearCursors();
                d.cursor().copyFrom(cur, keepAnchor: true);
                doc.touch();
              }
            }),
            blur: false,
            shield: false,
          );

          return;
        }
      case 'jump_to_line':
        {
          ui.setPopup(GotoPopup(onSubmit: (line) {
            command('cursor',
                params: [line.toString(), '0']);
            return;
          }), blur: false, shield: false);
        }
        return;
    }

    List<Block> modifiedBlocks = [];

    doc.begin();
    doc.command(cmd, params: params, modifiedBlocks: modifiedBlocks);
    doc.commit();

    for (final b in modifiedBlocks) {
      if (!indexingQueue.contains(b)) {
        indexingQueue.add(b);
      }
    }

    if (d.cursors.length == 1) {
      while (indexingQueue.isNotEmpty) {
        Block l = indexingQueue.last;
        if (d.cursor().block == l) break;
        indexingQueue.removeLast();
        indexer.indexWords(l.text);
        break;
      }
    }

    if (modifiedBlocks.isNotEmpty) {
      // onInputText..
      UIMenuData? menu = ui.menu('search::${d.documentId}');
      ui.setPopup(
          UIMenuPopup(position: decor.caretPosition, alignY: 1, menu: menu),
          blur: false,
          shield: false);

      Cursor cur = d.cursor().copy();
      cur.moveCursorLeft();
      cur.selectWord();
      if (cur.column == d.cursor().column) {
        String t = cur.selectedText();
        if (t.length > 1) {
          indexer.find(t);
        }
      } else {
        ui.clearPopups();
      }
    } else {
      ui.clearPopups();
    }

    StatusProvider status = Provider.of<StatusProvider>(context, listen: false);
    status.setIndexedStatus(
        0, 'Ln ${d.cursor().block?.line}, Col ${d.cursor().column}');
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
    bool hide = false;

    // todo remove
    AppProvider app = Provider.of<AppProvider>(context);
    if (widget.document != null) {
      if (app.document != doc.doc) {
        hide = true;
      }
    }

    HLTheme theme = Provider.of<HLTheme>(context);
    double buttonSize = 16.0;
    Color clr = theme.foreground;
    Color hiColor = theme.selection;

    List<Widget> buttons = !app.isKeyboardVisible
        ? []
        : <Widget>[
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
                    icon: Icon(Icons.keyboard_capslock,
                        size: buttonSize, color: clr),
                    onPressed: () {
                      setState(() {
                        shifting = !shifting;
                      });
                    })),
            IconButton(
                icon: Icon(Icons.west, size: buttonSize, color: clr),
                onPressed: () {
                  command(_buildKeys('left',
                      control: controlling, shift: shifting));
                }),
            IconButton(
                icon: Icon(Icons.north, size: buttonSize, color: clr),
                onPressed: () {
                  command(
                      _buildKeys('up', control: controlling, shift: shifting));
                }),
            IconButton(
                icon: Icon(Icons.south, size: buttonSize, color: clr),
                onPressed: () {
                  command(_buildKeys('down',
                      control: controlling, shift: shifting));
                }),
            IconButton(
                icon: Icon(Icons.east, size: buttonSize, color: clr),
                onPressed: () {
                  command(_buildKeys('right',
                      control: controlling, shift: shifting));
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
          ChangeNotifierProvider(create: (context) => pulse),
          ChangeNotifierProvider(create: (context) => decor),
          Provider(create: (context) => highlighter),
        ],
        child: hide
            ? Container()
            : Expanded(
                child: Column(children: [
                Expanded(
                    child: Stack(children: [
                  Row(children: [
                    Expanded(
                        child: InputListener(
                            child: View(),
                            onKeyDown: onKeyDown,
                            onKeyUp: onKeyUp,
                            onTapDown: onTapDown,
                            onDoubleTapDown: onDoubleTapDown,
                            onPanUpdate: onPanUpdate,
                            showKeyboard: app.showKeyboard)),
                    Minimap()
                  ]),
                ])),

                if (Platform.isAndroid && app.isKeyboardVisible) ...[
                  Container(
                      child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: buttons)))
                ], // toolbar
              ])));
  }
}
