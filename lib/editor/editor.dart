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
import 'package:editor/services/ui/modal.dart';
import 'package:editor/services/highlight/theme.dart';
import 'package:editor/services/highlight/highlighter.dart';
import 'package:editor/services/indexer/indexer.dart';
import 'package:editor/services/keybindings.dart';

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

  late FocusNode focusNode;
  late FocusNode textFocusNode;

  bool _isKeyboardVisible =
      WidgetsBinding.instance!.window.viewInsets.bottom > 0.0;

  bool shifting = false;
  bool controlling = false;
  bool alting = false;

  List<Block> indexingQueue = [];

  @override
  void initState() {
    super.initState();

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
      StatusProvider status =
          Provider.of<StatusProvider>(context, listen: false);
      status.setIndexedStatus(0, '');
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

    focusNode = FocusNode();
    textFocusNode = FocusNode();
    WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void dispose() {
    pulse.cancel();
    indexer.dispose();

    focusNode.dispose();
    textFocusNode.dispose();
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

  void onShortcut(String keys) {
    AppProvider app = Provider.of<AppProvider>(context, listen: false);
    Command? cmd = app.keybindings.resolve(keys);
    command(cmd?.command ?? '', params: cmd?.params);
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

  void _regainFocus() {
    Future.delayed(const Duration(milliseconds: 50), () {
      focusNode.requestFocus();
      textFocusNode.requestFocus();
    });
  }

  void command(String cmd, {dynamic params}) async {
    Document d = doc.doc;
    Cursor cursor = d.cursor().copy();

    AppProvider app = Provider.of<AppProvider>(context, listen: false);
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
      case 'switch_tab':
        {
          int idx = params;
          if (idx >= 0 && idx < app.documents.length) {
            app.open(app.documents[idx].docPath, focus: true);
          }
          return;
        }

      case 'toggle_pinned':
        {
          doc.pinned = !doc.pinned;
          doc.touch();
          return;
        }

      case 'search':
        {
          ui.setPopup(SearchPopup(onSubmit: (text,
              {int direction = 1,
              bool caseSensitive = false,
              bool regex = false,
              bool repeat = false,
              String? replace}) {
            Document d = doc.doc;
            Cursor? cur = d.find(d.cursor().copy(), text,
                direction: direction,
                regex: regex,
                caseSensitive: caseSensitive,
                repeat: repeat);
            if (cur != null) {
              if (replace != null && d.hasSelection()) {
                d.begin();
                d.insertText(replace);
                d.commit();
              }
              d.clearCursors();
              d.cursor().copyFrom(cur, keepAnchor: true);
              doc.scrollTo = cur.block?.line ?? 0;
              doc.touch();
            }
          }), blur: false, shield: false, onClearPopups: _regainFocus);

          return;
        }
      case 'jump_to_line':
        {
          ui.setPopup(GotoPopup(onSubmit: (line) {
            command('cursor', params: [line, 0]);
            return;
          }), blur: false, shield: false, onClearPopups: _regainFocus);
        }
        return;

      case 'close':
        app.close(doc.doc.docPath);
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
    status.setIndexedStatus(0,
        'Ln ${((d.cursor().block?.line ?? 0) + 1)}, Col ${(d.cursor().column + 1)}');
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

    UIProvider ui = Provider.of<UIProvider>(context, listen: false);
    if (doc.softWrap && ui.popups.isEmpty) {
      switch (key) {
        case 'Arrow Up':
        case 'Arrow Down':
          {
            RenderObject? obj = context.findRenderObject();
            double move = decor.fontHeight / 2 +
                ((key == 'Arrow Up' ? -decor.fontHeight : decor.fontHeight));
            onTapDown(obj,
                Offset(decor.caretPosition.dx, decor.caretPosition.dy + move));
            return;
          }
      }
    }

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
        command(
            buildKeys(key, control: controlling, shift: shifting, alt: alting));
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
              onShortcut(buildKeys(ch,
                  control: controlling, shift: shifting, alt: alting));
              break;
            }
            command('insert', params: ch);
            break;
          }
        }
        if (key.length == 1 || softKeyboard) {
          if (controlling || alting) {
            onShortcut(buildKeys(key,
                control: controlling, shift: shifting, alt: alting));
          } else {
            command('insert', params: key);
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
      command('shift+cursor', params: [o.dy.toInt(), o.dx.toInt()]);
    } else {
      command('cursor', params: [o.dy.toInt(), o.dx.toInt()]);
    }
  }

  void onDoubleTapDown(RenderObject? obj, Offset globalPosition) {
    Document d = doc.doc;
    Offset o = screenToCursor(obj, globalPosition);
    command('cursor', params: [o.dy.toInt(), o.dx.toInt()]);
    command('select_word');
  }

  void onPanUpdate(RenderObject? obj, Offset globalPosition) {
    Document d = doc.doc;
    Offset o = screenToCursor(obj, globalPosition);
    if (o.dx == -1 || o.dy == -1) return;
    command('shift+cursor', params: [o.dy.toInt(), o.dx.toInt()]);
  }

  @override
  Widget build(BuildContext context) {
    bool hide = false;

    // todo refactor.. so editor can live outside of app
    AppProvider app = Provider.of<AppProvider>(context);
    if (!doc.pinned && widget.document != null) {
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
                  command(
                      buildKeys('left', control: controlling, shift: shifting));
                }),
            IconButton(
                icon: Icon(Icons.north, size: buttonSize, color: clr),
                onPressed: () {
                  command(
                      buildKeys('up', control: controlling, shift: shifting));
                }),
            IconButton(
                icon: Icon(Icons.south, size: buttonSize, color: clr),
                onPressed: () {
                  command(
                      buildKeys('down', control: controlling, shift: shifting));
                }),
            IconButton(
                icon: Icon(Icons.east, size: buttonSize, color: clr),
                onPressed: () {
                  command(buildKeys('right',
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

    doc.showMinimap = app.showMinimap;
    doc.showGutter = app.showGutter;
    doc.softWrap = app.softWrap;

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
                            focusNode: focusNode,
                            textFocusNode: textFocusNode,
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
